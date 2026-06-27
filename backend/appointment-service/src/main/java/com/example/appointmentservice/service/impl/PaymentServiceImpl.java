package com.example.appointmentservice.service.impl;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.example.appointmentservice.client.NotificationClient;
import com.example.appointmentservice.client.WalletClient;
import com.example.appointmentservice.dto.CreatePaymentRequest;
import com.example.appointmentservice.dto.PaymentResponse;
import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.Payment;
import com.example.appointmentservice.entity.PaymentMethod;
import com.example.appointmentservice.entity.PaymentStatus;
import com.example.appointmentservice.exception.ForbiddenOperationException;
import com.example.appointmentservice.exception.ResourceNotFoundException;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.PaymentRepository;
import com.example.appointmentservice.security.SecurityUtils;
import com.example.appointmentservice.service.OwnershipResolver;
import com.example.appointmentservice.service.PaymentService;

@Service
public class PaymentServiceImpl implements PaymentService {

    private final PaymentRepository paymentRepository;
    private final AppointmentRepository appointmentRepository;
    private final NotificationClient notificationClient;
    private final OwnershipResolver ownershipResolver;
    private final WalletClient walletClient;

    public PaymentServiceImpl(
            PaymentRepository paymentRepository,
            AppointmentRepository appointmentRepository,
            NotificationClient notificationClient,
            OwnershipResolver ownershipResolver,
            WalletClient walletClient
    ) {
        this.paymentRepository = paymentRepository;
        this.appointmentRepository = appointmentRepository;
        this.notificationClient = notificationClient;
        this.ownershipResolver = ownershipResolver;
        this.walletClient = walletClient;
    }

    private void checkParticipant(Appointment appointment) {

        if (SecurityUtils.hasRole("PATIENT")
                && ownershipResolver.resolveOwnPatientId().equals(appointment.getPatientId())) {
            return;
        }

        if (SecurityUtils.hasRole("PSYCHOLOGIST")
                && ownershipResolver.resolveOwnPsychologistId().equals(appointment.getPsychologistId())) {
            return;
        }

        throw new ForbiddenOperationException(
                "Ce paiement ne concerne pas un rendez-vous qui vous appartient"
        );
    }

    @Override
    public PaymentResponse createPayment(CreatePaymentRequest request) {

        Appointment appointment =
                appointmentRepository.findById(request.getAppointmentId())
                        .orElseThrow(() -> new ResourceNotFoundException(
                                "Rendez-vous non trouvé"
                        ));

        if (!SecurityUtils.hasRole("PATIENT")
                || !ownershipResolver.resolveOwnPatientId().equals(appointment.getPatientId())) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez payer que vos propres rendez-vous"
            );
        }

        if (appointment.getStatus() == AppointmentStatus.CANCELLED
                || appointment.getStatus() == AppointmentStatus.REJECTED) {

            throw new RuntimeException(
                    "Ce rendez-vous n'est plus payable (annulé ou refusé)"
            );
        }

        // Seul un RDV déjà CONFIRMED par le psychologue est payable, sinon
        // le paiement finirait par valider le RDV à sa place.
        if (appointment.getStatus() != AppointmentStatus.CONFIRMED) {
            throw new RuntimeException(
                    "Ce rendez-vous doit d'abord être confirmé par le "
                            + "psychologue avant de pouvoir être payé"
            );
        }

        // Anti double-paiement : on rejette si un paiement COMPLETED existe
        // déjà pour ce RDV, indépendamment de ce que filtre le frontend.
        boolean alreadyPaid = paymentRepository.findByAppointmentId(appointment.getId())
                .stream()
                .anyMatch(p -> p.getStatus() == PaymentStatus.COMPLETED);
        if (alreadyPaid) {
            throw new RuntimeException(
                    "Ce rendez-vous a déjà été payé."
            );
        }

        // Débite réellement le solde du patient. Échoue en 402 (voir
        // InsufficientBalanceException) si le solde est insuffisant.
        walletClient.debit(appointment.getPatientId(), request.getAmount().doubleValue());

        // Le débit est un appel HTTP déjà commité côté user-service, hors de
        // toute transaction locale ici. Si l'enregistrement du Payment
        // échoue ensuite, le débit ne s'annule pas tout seul : on recrédite
        // donc explicitement avant de relayer l'erreur.
        try {
            Payment payment = new Payment();
            payment.setAppointmentId(appointment.getId());
            payment.setAmount(request.getAmount());
            payment.setMethod(PaymentMethod.WALLET);
            payment.setStatus(PaymentStatus.COMPLETED);
            payment.setTransactionReference(
                    "SIM-" + UUID.randomUUID()
            );

            Payment savedPayment = paymentRepository.save(payment);

            sendPaymentNotification(appointment);

            return mapToResponse(savedPayment);
        } catch (RuntimeException ex) {
            try {
                walletClient.credit(
                        appointment.getPatientId(),
                        request.getAmount().doubleValue()
                );
            } catch (RuntimeException compensationFailure) {
                // Le best-effort a échoué : on logue mais on relaie tout de
                // même l'erreur d'origine, qui est la cause réelle du
                // problème pour l'appelant.
                org.slf4j.LoggerFactory.getLogger(PaymentServiceImpl.class).error(
                        "Échec du recrédit compensatoire après un débit non "
                                + "suivi d'un paiement enregistré (RDV {})",
                        appointment.getId(),
                        compensationFailure
                );
            }
            throw ex;
        }
    }

    @Override
    public PaymentResponse getPaymentById(Long id) {

        Payment payment = paymentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Paiement non trouvé"
                ));

        Appointment appointment = appointmentRepository.findById(payment.getAppointmentId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Rendez-vous non trouvé"
                ));

        checkParticipant(appointment);

        return mapToResponse(payment);
    }

    @Override
    public List<PaymentResponse> getPaymentsByAppointmentId(Long appointmentId) {

        Appointment appointment = appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Rendez-vous non trouvé"
                ));

        checkParticipant(appointment);

        return paymentRepository.findByAppointmentId(appointmentId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public List<PaymentResponse> getAllPaymentsForAdmin() {

        return paymentRepository.findAll()
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public Double refundCompletedPayments(Long appointmentId) {

        List<Payment> payments =
                paymentRepository.findByAppointmentId(appointmentId);

        double totalRefunded = 0.0;

        for (Payment payment : payments) {
            if (payment.getStatus() == PaymentStatus.COMPLETED) {
                payment.setStatus(PaymentStatus.REFUNDED);
                paymentRepository.save(payment);
                totalRefunded += payment.getAmount().doubleValue();
            }
        }

        if (totalRefunded > 0) {
            Appointment appointment =
                    appointmentRepository.findById(appointmentId)
                            .orElseThrow(() -> new ResourceNotFoundException(
                                    "Rendez-vous non trouvé"
                            ));

            // Crédite réellement le solde du patient (pas juste un
            // changement de statut sans effet visible).
            walletClient.credit(appointment.getPatientId(), totalRefunded);
        }

        return totalRefunded;
    }

    private void sendPaymentNotification(Appointment appointment) {

        notificationClient.send(
                appointment.getPatientId(),
                "Paiement confirmé",
                "Votre paiement a été débité de votre solde PsyConnect et "
                        + "votre rendez-vous est confirmé.",
                "PAYMENT"
        );
    }

    private PaymentResponse mapToResponse(Payment payment) {

        PaymentResponse response = new PaymentResponse();

        response.setId(payment.getId());
        response.setAppointmentId(payment.getAppointmentId());
        response.setAmount(payment.getAmount());
        response.setMethod(payment.getMethod());
        response.setStatus(payment.getStatus());
        response.setTransactionReference(payment.getTransactionReference());
        response.setCreatedAt(payment.getCreatedAt());

        return response;
    }
}
