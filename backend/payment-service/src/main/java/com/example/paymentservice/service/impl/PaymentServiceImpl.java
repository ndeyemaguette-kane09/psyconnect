package com.example.paymentservice.service.impl;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.example.paymentservice.client.AppointmentClient;
import com.example.paymentservice.client.NotificationClient;
import com.example.paymentservice.client.WalletClient;
import com.example.paymentservice.dto.AppointmentSummary;
import com.example.paymentservice.dto.CreatePaymentRequest;
import com.example.paymentservice.dto.PaymentResponse;
import com.example.paymentservice.dto.PaymentTransactionDto;
import com.example.paymentservice.dto.PsychologistRevenueResponse;
import com.example.paymentservice.dto.PsychologistWalletResponse;
import com.example.paymentservice.dto.WithdrawalResponse;
import com.example.paymentservice.entity.Payment;
import com.example.paymentservice.entity.PaymentMethod;
import com.example.paymentservice.entity.PaymentStatus;
import com.example.paymentservice.entity.PlatformSettings;
import com.example.paymentservice.entity.PsychologistWithdrawal;
import com.example.paymentservice.exception.ForbiddenOperationException;
import com.example.paymentservice.exception.InsufficientBalanceException;
import com.example.paymentservice.exception.ResourceNotFoundException;
import com.example.paymentservice.repository.PaymentRepository;
import com.example.paymentservice.repository.PlatformSettingsRepository;
import com.example.paymentservice.repository.PsychologistWithdrawalRepository;
import com.example.paymentservice.security.SecurityUtils;
import com.example.paymentservice.service.OwnershipResolver;
import com.example.paymentservice.service.PaymentService;

@Service
public class PaymentServiceImpl implements PaymentService {

    private static final Logger LOGGER = LoggerFactory.getLogger(PaymentServiceImpl.class);

    // Même identifiant fixe que dans AdminController — une seule ligne de réglages
    private static final Long SETTINGS_ID = 1L;

    private final PaymentRepository paymentRepository;
    private final PlatformSettingsRepository platformSettingsRepository;
    private final PsychologistWithdrawalRepository withdrawalRepository;
    private final AppointmentClient appointmentClient;
    private final NotificationClient notificationClient;
    private final OwnershipResolver ownershipResolver;
    private final WalletClient walletClient;

    public PaymentServiceImpl(
            PaymentRepository paymentRepository,
            PlatformSettingsRepository platformSettingsRepository,
            PsychologistWithdrawalRepository withdrawalRepository,
            AppointmentClient appointmentClient,
            NotificationClient notificationClient,
            OwnershipResolver ownershipResolver,
            WalletClient walletClient
    ) {
        this.paymentRepository = paymentRepository;
        this.platformSettingsRepository = platformSettingsRepository;
        this.withdrawalRepository = withdrawalRepository;
        this.appointmentClient = appointmentClient;
        this.notificationClient = notificationClient;
        this.ownershipResolver = ownershipResolver;
        this.walletClient = walletClient;
    }

    private void checkParticipant(AppointmentSummary appointment) {

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

        // appointment-service refait ses propres controles, mais on veut le
        // statut/patientId/psychologistId pour valider le paiement ici
        AppointmentSummary appointment = appointmentClient.getAppointmentById(request.getAppointmentId());

        if (!SecurityUtils.hasRole("PATIENT")
                || !ownershipResolver.resolveOwnPatientId().equals(appointment.getPatientId())) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez payer que vos propres rendez-vous"
            );
        }

        if ("CANCELLED".equals(appointment.getStatus()) || "REJECTED".equals(appointment.getStatus())) {
            throw new RuntimeException(
                    "Ce rendez-vous n'est plus payable (annulé ou refusé)"
            );
        }

        // Seuls les RDV déjà confirmés sont payables
        if (!"CONFIRMED".equals(appointment.getStatus())) {
            throw new RuntimeException(
                    "Ce rendez-vous doit d'abord être confirmé par le "
                            + "psychologue avant de pouvoir être payé"
            );
        }

        // Bloque si un paiement existe déjà pour ce rendez-vous
        boolean alreadyPaid = paymentRepository.findByAppointmentId(appointment.getId())
                .stream()
                .anyMatch(p -> p.getStatus() == PaymentStatus.COMPLETED);
        if (alreadyPaid) {
            throw new RuntimeException(
                    "Ce rendez-vous a déjà été payé."
            );
        }

        // Débite le solde, échoue si insuffisant
        BigDecimal amount = ownershipResolver.getConsultationPrice(appointment.getPsychologistId());
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException(
                    "Le tarif de ce psychologue n'est pas renseigné : paiement impossible pour le moment"
            );
        }

        walletClient.debit(appointment.getPatientId(), amount.doubleValue());

        // Si la sauvegarde échoue après le débit, on recrédit manuellement
        try {
            Payment payment = new Payment();
            payment.setAppointmentId(appointment.getId());
            payment.setAmount(amount);
            payment.setMethod(PaymentMethod.WALLET);
            payment.setStatus(PaymentStatus.COMPLETED);
            payment.setTransactionReference(
                    "SIM-" + UUID.randomUUID()
            );
            // dupliqués depuis AppointmentSummary pour éviter les appels
            // cross-service lors du calcul du revenu/wallet/transactions psy
            payment.setPsychologistId(appointment.getPsychologistId());
            payment.setPatientId(appointment.getPatientId());
            payment.setAppointmentStartTime(appointment.getStartTime());

            Payment savedPayment = paymentRepository.save(payment);

            // Notification non bloquante : un échec ici ne doit PAS annuler le
            // paiement ni déclencher la compensation walletClient.credit().
            // On logge l'erreur et on continue.
            try {
                sendPaymentNotification(appointment);
            } catch (Exception notifEx) {
                LOGGER.warn(
                        "Notification de paiement non envoyée pour RDV {} : {}",
                        appointment.getId(), notifEx.getMessage()
                );
            }

            return mapToResponse(savedPayment);
        } catch (RuntimeException ex) {
            try {
                walletClient.credit(
                        appointment.getPatientId(),
                        amount.doubleValue()
                );
            } catch (RuntimeException compensationFailure) {
                // Le recrédit compensatoire a échoué : on logge et on relance l'erreur initiale
                LOGGER.error(
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

        AppointmentSummary appointment = appointmentClient.getAppointmentById(payment.getAppointmentId());

        checkParticipant(appointment);

        return mapToResponse(payment);
    }

    @Override
    public List<PaymentResponse> getPaymentsByAppointmentId(Long appointmentId) {

        AppointmentSummary appointment = appointmentClient.getAppointmentById(appointmentId);

        checkParticipant(appointment);

        return paymentRepository.findByAppointmentId(appointmentId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    // revenu brut + net d'un psy, total et du mois en cours.
    // Requête directe sur la table payments (psychologistId dupliqué depuis l'appointment)
    // → aucun appel cross-service, donc pas de boucle d'ownership inter-service.
    @Override
    public PsychologistRevenueResponse getPsychologistRevenue(Long psychologistId) {

        // ownership : le psy ne peut voir que ses propres revenus
        if (SecurityUtils.hasRole("PSYCHOLOGIST")) {
            Long ownId = ownershipResolver.resolveOwnPsychologistId();
            if (!ownId.equals(psychologistId)) {
                throw new ForbiddenOperationException(
                        "Vous ne pouvez consulter que vos propres revenus"
                );
            }
        } else if (!SecurityUtils.hasRole("ADMIN")) {
            throw new ForbiddenOperationException("Accès réservé aux psychologues");
        }

        // les anciens paiements (avant l'ajout de psychologistId) ont null → exclus,
        // ce qui est acceptable pour un environnement de développement
        List<Payment> completedPayments = paymentRepository
                .findByPsychologistIdAndStatus(psychologistId, PaymentStatus.COMPLETED);

        BigDecimal totalGross = completedPayments.stream()
                .map(Payment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        YearMonth currentMonth = YearMonth.now();
        BigDecimal monthGross = completedPayments.stream()
                .filter(p -> p.getCreatedAt() != null
                        && YearMonth.from(p.getCreatedAt()).equals(currentMonth))
                .map(Payment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal commissionRatePercent = getOrCreateSettings().getCommissionRatePercent();

        PsychologistRevenueResponse response = new PsychologistRevenueResponse();
        response.setCommissionRatePercent(commissionRatePercent);
        response.setTotalGrossRevenue(totalGross);
        response.setTotalNetRevenue(applyCommission(totalGross, commissionRatePercent));
        response.setCurrentMonthGrossRevenue(monthGross);
        response.setCurrentMonthNetRevenue(applyCommission(monthGross, commissionRatePercent));

        return response;
    }

    // portefeuille du psy : solde dispo = revenu net total - total retiré
    @Override
    public PsychologistWalletResponse getPsychologistWallet(Long psychologistId) {

        PsychologistRevenueResponse revenue = getPsychologistRevenue(psychologistId);
        BigDecimal totalNetRevenue = revenue.getTotalNetRevenue();

        BigDecimal totalWithdrawn;
        List<WithdrawalResponse> history;
        try {
            totalWithdrawn = withdrawalRepository.sumWithdrawn(psychologistId);
            history = withdrawalRepository
                    .findByPsychologistIdOrderByCreatedAtDesc(psychologistId)
                    .stream()
                    .map(this::mapWithdrawal)
                    .collect(Collectors.toList());
        } catch (Exception ex) {
            LOGGER.error("[wallet] échec requête psychologist_withdrawals pour psy {} : {}",
                    psychologistId, ex.getMessage(), ex);
            throw ex;
        }
        BigDecimal availableBalance = totalNetRevenue.subtract(totalWithdrawn);

        PsychologistWalletResponse wallet = new PsychologistWalletResponse();
        wallet.setAvailableBalance(availableBalance);
        wallet.setTotalNetRevenue(totalNetRevenue);
        wallet.setTotalWithdrawn(totalWithdrawn);
        wallet.setCommissionRatePercent(revenue.getCommissionRatePercent());
        wallet.setWithdrawals(history);

        return wallet;
    }

    // retrait simulé : vérifie le solde et enregistre le mouvement (statut COMPLETED d'emblée)
    @Override
    public WithdrawalResponse withdraw(Long psychologistId, BigDecimal amount, String method) {

        PsychologistWalletResponse wallet = getPsychologistWallet(psychologistId);

        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Le montant du retrait doit être supérieur à zéro");
        }

        if (wallet.getAvailableBalance().compareTo(amount) < 0) {
            throw new InsufficientBalanceException(
                    "Solde insuffisant : disponible "
                            + wallet.getAvailableBalance()
                            + " FCFA, demandé " + amount + " FCFA"
            );
        }

        PsychologistWithdrawal withdrawal = new PsychologistWithdrawal();
        withdrawal.setPsychologistId(psychologistId);
        withdrawal.setAmount(amount);
        withdrawal.setMethod(method);
        // statut positionné par @PrePersist si null → COMPLETED

        return mapWithdrawal(withdrawalRepository.save(withdrawal));
    }

    @Override
    public List<PaymentResponse> getAllPaymentsForAdmin() {

        return paymentRepository.findAll()
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public BigDecimal refundCompletedPayments(Long appointmentId, Long patientId) {
        AppointmentSummary appointment = appointmentClient.getAppointmentById(appointmentId);
        if (!SecurityUtils.hasRole("PATIENT")
                || !appointment.getPatientId().equals(patientId)
                || !ownershipResolver.resolveOwnPatientId().equals(appointment.getPatientId())) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez demander le remboursement que de vos propres rendez-vous"
            );
        }
        if (!"CANCELLED".equals(appointment.getStatus())) {
            throw new RuntimeException(
                    "Seul un rendez-vous annulé peut être remboursé"
            );
        }
        if (appointment.getStartTime() == null
                || Duration.between(LocalDateTime.now(), appointment.getStartTime()).toHours() < 48) {
            throw new RuntimeException(
                    "Remboursement impossible : l'annulation doit intervenir au moins 48 heures avant le rendez-vous"
            );
        }

        List<Payment> payments = paymentRepository.findByAppointmentId(appointmentId);

        BigDecimal totalRefunded = BigDecimal.ZERO;

        for (Payment payment : payments) {
            if (payment.getStatus() == PaymentStatus.COMPLETED) {
                payment.setStatus(PaymentStatus.REFUNDED);
                paymentRepository.save(payment);
                totalRefunded = totalRefunded.add(payment.getAmount());
            }
        }

        if (totalRefunded.compareTo(BigDecimal.ZERO) > 0) {
            // credite le solde, pas juste un changement de statut
            walletClient.credit(patientId, totalRefunded.doubleValue());
        }

        return totalRefunded;
    }

    // Net = brut - commission, même calcul que dans AdminController
    private BigDecimal applyCommission(BigDecimal gross, BigDecimal commissionRatePercent) {
        BigDecimal commission = gross
                .multiply(commissionRatePercent)
                .divide(new BigDecimal("100"), 2, java.math.RoundingMode.HALF_UP);
        return gross.subtract(commission);
    }

    private PlatformSettings getOrCreateSettings() {
        return platformSettingsRepository.findById(SETTINGS_ID)
                .orElseGet(() -> {
                    PlatformSettings settings = new PlatformSettings();
                    settings.setId(SETTINGS_ID);
                    return platformSettingsRepository.save(settings);
                });
    }

    // notifie le patient ET le psy : avant, seul le patient recevait la
    // notif (le psy n'était jamais informé qu'un paiement venait de tomber
    // pour l'un de ses rendez-vous)
    private void sendPaymentNotification(AppointmentSummary appointment) {

        notificationClient.send(
                appointment.getPatientId(),
                "Paiement confirmé",
                "Votre paiement a été débité de votre solde PsyConnect et "
                        + "votre rendez-vous est confirmé.",
                "PAYMENT",
                "PATIENT"
        );

        notificationClient.send(
                appointment.getPsychologistId(),
                "Paiement reçu",
                "Le paiement d'un rendez-vous a été confirmé par le patient. "
                        + "Le rendez-vous est désormais payé.",
                "PAYMENT",
                "PSYCHOLOGIST"
        );
    }

    // historique détaillé des paiements reçus par un psy, du plus récent au plus ancien.
    // completed = paiement encaissé ; refunded = RDV annulé, argent rendu au patient.
    // Requête directe sur payments (psychologistId/patientId/startTime dupliqués
    // depuis l'appointment à la création) → aucun appel cross-service.
    @Override
    public List<PaymentTransactionDto> getTransactionsByPsychologistId(Long psychologistId) {

        // ownership : le psy ne peut voir que ses propres transactions
        if (SecurityUtils.hasRole("PSYCHOLOGIST")) {
            Long ownId = ownershipResolver.resolveOwnPsychologistId();
            if (!ownId.equals(psychologistId)) {
                throw new ForbiddenOperationException(
                        "Vous ne pouvez consulter que vos propres transactions"
                );
            }
        } else if (!SecurityUtils.hasRole("ADMIN")) {
            throw new ForbiddenOperationException("Accès réservé aux psychologues");
        }

        // completed + refunded pour traçabilité complète
        List<Payment> payments = paymentRepository.findByPsychologistId(psychologistId)
                .stream()
                .filter(p -> p.getStatus() == PaymentStatus.COMPLETED
                        || p.getStatus() == PaymentStatus.REFUNDED)
                .collect(Collectors.toList());

        BigDecimal commissionRatePercent = getOrCreateSettings().getCommissionRatePercent();

        return payments.stream()
                .sorted(Comparator.comparing(
                        Payment::getCreatedAt,
                        Comparator.nullsLast(Comparator.reverseOrder())
                ))
                .map(p -> {
                    BigDecimal gross = p.getAmount();
                    BigDecimal commission = gross
                            .multiply(commissionRatePercent)
                            .divide(new BigDecimal("100"), 2, java.math.RoundingMode.HALF_UP);

                    PaymentTransactionDto dto = new PaymentTransactionDto();
                    dto.setPaymentId(p.getId());
                    dto.setAppointmentId(p.getAppointmentId());
                    dto.setPatientId(p.getPatientId());
                    dto.setAppointmentStartTime(p.getAppointmentStartTime());
                    dto.setGrossAmount(gross);
                    dto.setNetAmount(gross.subtract(commission));
                    dto.setCommissionAmount(commission);
                    dto.setStatus(p.getStatus().name());
                    dto.setTransactionReference(p.getTransactionReference());
                    dto.setPaidAt(p.getCreatedAt());
                    return dto;
                })
                .collect(Collectors.toList());
    }

    private WithdrawalResponse mapWithdrawal(PsychologistWithdrawal w) {
        WithdrawalResponse r = new WithdrawalResponse();
        r.setId(w.getId());
        r.setPsychologistId(w.getPsychologistId());
        r.setAmount(w.getAmount());
        r.setMethod(w.getMethod());
        r.setStatus(w.getStatus());
        r.setCreatedAt(w.getCreatedAt());
        return r;
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
