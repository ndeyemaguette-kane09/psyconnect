package com.example.appointmentservice.service.impl;

import java.util.EnumSet;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.example.appointmentservice.client.NotificationClient;
import com.example.appointmentservice.client.PaymentClient;
import com.example.appointmentservice.dto.AppointmentResponse;
import com.example.appointmentservice.dto.CreateAppointmentRequest;
import com.example.appointmentservice.dto.RescheduleAppointmentRequest;
import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.exception.ForbiddenOperationException;
import com.example.appointmentservice.exception.ResourceNotFoundException;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.security.SecurityUtils;
import com.example.appointmentservice.service.AppointmentService;
import com.example.appointmentservice.service.OwnershipResolver;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class AppointmentServiceImpl
        implements AppointmentService {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(AppointmentServiceImpl.class);

    private final AppointmentRepository
            appointmentRepository;

    private final NotificationClient notificationClient;

    private final OwnershipResolver ownershipResolver;

    private final PaymentClient paymentClient;

    public AppointmentServiceImpl(
            AppointmentRepository appointmentRepository,
            NotificationClient notificationClient,
            OwnershipResolver ownershipResolver,
            PaymentClient paymentClient
    ) {

        this.appointmentRepository =
                appointmentRepository;

        this.notificationClient = notificationClient;

        this.ownershipResolver = ownershipResolver;

        this.paymentClient = paymentClient;
    }

    // Vérifie que l'appelant est bien le patient ou le psychologue du rendez-vous
    private void checkParticipant(Appointment appointment) {

        if (SecurityUtils.hasRole("PATIENT")) {
            Long ownPatientId = ownershipResolver.resolveOwnPatientId();
            if (ownPatientId.equals(appointment.getPatientId())) {
                return;
            }
        }

        if (SecurityUtils.hasRole("PSYCHOLOGIST")) {
            Long ownPsychologistId = ownershipResolver.resolveOwnPsychologistId();
            if (ownPsychologistId.equals(appointment.getPsychologistId())) {
                return;
            }
        }

        throw new ForbiddenOperationException(
                "Ce rendez-vous ne vous appartient pas"
        );
    }

    @Override
    public AppointmentResponse createAppointment(
            CreateAppointmentRequest request
    ) {

        if (!SecurityUtils.hasRole("PATIENT")) {
            throw new ForbiddenOperationException(
                    "Seul un patient peut réserver un rendez-vous"
            );
        }

        Long ownPatientId = ownershipResolver.resolveOwnPatientId();

        if (!ownPatientId.equals(request.getPatientId())) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez réserver un rendez-vous que pour vous-même"
            );
        }

        if (
            !request.getEndTime()
                    .isAfter(request.getStartTime())
        ) {
    
            throw new RuntimeException(
                    "La date de fin doit être après la date de début"
            );
        }

        if (
            request.getStartTime()
                    .isBefore(
                            java.time.LocalDateTime.now()
                    )
        ) {
    
            throw new RuntimeException(
                    "Les rendez-vous ne peuvent pas être programmés dans le passé"
            );
        }

        // seuls les RDV actifs (en attente ou confirmés) bloquent le créneau ;
        // les RDV annulés/refusés/terminés libèrent le créneau immédiatement
        Set<AppointmentStatus> activeStatuses =
                EnumSet.of(AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED);

        boolean conflict =
                appointmentRepository
                        .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                                request.getPsychologistId(),
                                request.getEndTime(),
                                request.getStartTime(),
                                activeStatuses
                        );

        if (conflict) {
            throw new RuntimeException(
                    "Le psychologue possède déjà un rendez-vous sur ce créneau"
            );
        }

        // un patient ne peut pas avoir deux RDV actifs au même horaire
        boolean patientConflict =
                appointmentRepository
                        .existsByPatientIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
                                request.getPatientId(),
                                request.getEndTime(),
                                request.getStartTime(),
                                activeStatuses
                        );

        if (patientConflict) {
            throw new RuntimeException(
                    "Vous avez déjà un rendez-vous sur ce créneau"
            );
        }

        Appointment appointment =
                new Appointment();

        appointment.setPatientId(
                request.getPatientId()
        );

        appointment.setPsychologistId(
                request.getPsychologistId()
        );

        appointment.setStartTime(
                request.getStartTime()
        );

        appointment.setEndTime(
                request.getEndTime()
        );

        appointment.setConsultationType(
                request.getConsultationType()
        );

        appointment.setStatus(
                AppointmentStatus.PENDING
        );

        Appointment savedAppointment =
                appointmentRepository.save(
                        appointment
                );

        // le message doit pas faire croire que le RDV est déjà confirmé
        notifyPatient(
                savedAppointment.getId(),
                request.getPatientId(),
                "Demande de rendez-vous envoyée",
                "Votre demande de rendez-vous est en cours de traitement. "
                        + "Elle doit être confirmée par le psychologue avant "
                        + "d'être effective."
        );

        // notifie aussi le psy, sinon il voit la demande que dans son agenda
        notifyPsychologist(
                savedAppointment.getId(),
                request.getPsychologistId(),
                "Nouvelle demande de rendez-vous",
                "Un patient souhaite réserver un rendez-vous avec vous. "
                        + "Consultez votre agenda pour la confirmer ou la "
                        + "refuser."
        );

        return mapToResponse(savedAppointment);
    }

    // Notification au patient — un échec ici ne bloque pas le rendez-vous
    private void notifyPatient(
            Long appointmentId,
            Long patientId,
            String title,
            String message
    ) {

        notificationClient.send(
                patientId,
                title,
                message,
                "APPOINTMENT",
                "PATIENT"
        );
    }

    // pareil que notifyPatient mais pour le psy
    private void notifyPsychologist(
            Long appointmentId,
            Long psychologistId,
            String title,
            String message
    ) {

        notificationClient.send(
                psychologistId,
                title,
                message,
                "APPOINTMENT",
                "PSYCHOLOGIST"
        );
    }

    @Override
    public AppointmentResponse getAppointmentById(
            Long id
    ) {

        Appointment appointment =
                appointmentRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Rendez-vous non trouvé"
                                )
                        );

        checkParticipant(appointment);

        return mapToResponse(appointment);
    }

    @Override
    public AppointmentResponse updateAppointmentStatus(
            Long id,
            String status
    ) {

        Appointment appointment =
                appointmentRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Rendez-vous non trouvé"
                                )
                        );

        checkParticipant(appointment);

        AppointmentStatus newStatus =
                AppointmentStatus.valueOf(status.toUpperCase());

        // seul le psy confirme ou refuse, seul le patient annule
        boolean callerIsPsychologist = SecurityUtils.hasRole("PSYCHOLOGIST");
        if (
            (newStatus == AppointmentStatus.CONFIRMED
                    || newStatus == AppointmentStatus.REJECTED)
                && !callerIsPsychologist
        ) {
            throw new ForbiddenOperationException(
                    "Seul le psychologue peut confirmer ou refuser ce rendez-vous"
            );
        }
        if (newStatus == AppointmentStatus.CANCELLED && callerIsPsychologist) {
            throw new ForbiddenOperationException(
                    "Seul le patient peut annuler ce rendez-vous"
            );
        }

        // annulation +48h avant = remboursement auto, sinon rien
        boolean refunded = false;

        if (newStatus == AppointmentStatus.CANCELLED) {
            long hoursUntilStart = Duration.between(
                    LocalDateTime.now(),
                    appointment.getStartTime()
            ).toHours();

            if (hoursUntilStart >= 48) {
                paymentClient.refundCompletedPayments(appointment.getId(), appointment.getPatientId());
                refunded = true;
            }
        }

        appointment.setStatus(
                newStatus
        );

        Appointment updatedAppointment =
                appointmentRepository.save(
                        appointment
                );

        String title;
        String message;

        switch (newStatus) {
            case CONFIRMED:
                title = "Rendez-vous confirmé";
                message = "Votre rendez-vous a été confirmé par le psychologue. "
                        + "Vous pouvez maintenant procéder au paiement.";
                break;
            case REJECTED:
                title = "Rendez-vous refusé";
                message = "Votre rendez-vous a été refusé par le psychologue.";
                break;
            case CANCELLED:
                title = "Rendez-vous annulé";
                message = refunded
                        ? "Votre rendez-vous a été annulé. Le paiement associé a été crédité sur votre solde PsyConnect (annulation à plus de 48h du rendez-vous)."
                        : "Votre rendez-vous a été annulé. Aucun remboursement n'est applicable (annulation à moins de 48h du rendez-vous).";
                break;
            default:
                title = null;
                message = null;
        }

        if (title != null) {
            notifyPatient(
                    updatedAppointment.getId(),
                    updatedAppointment.getPatientId(),
                    title,
                    message
            );
        }

        return mapToResponse(updatedAppointment);
    }

    @Override
    public AppointmentResponse rescheduleAppointment(
            Long id,
            RescheduleAppointmentRequest request
    ) {

        Appointment appointment =
                appointmentRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Rendez-vous non trouvé"
                                )
                        );

        if (!SecurityUtils.hasRole("PATIENT")
                || !ownershipResolver.resolveOwnPatientId().equals(appointment.getPatientId())) {
            throw new ForbiddenOperationException(
                    "Seul le patient à l'origine du rendez-vous peut le reporter"
            );
        }

        if (appointment.getStatus() != AppointmentStatus.PENDING
                && appointment.getStatus() != AppointmentStatus.CONFIRMED) {
            throw new RuntimeException(
                    "Seul un rendez-vous en attente ou confirmé peut être reporté"
            );
        }

        if (!request.getNewEndTime().isAfter(request.getNewStartTime())) {
            throw new RuntimeException(
                    "La date de fin doit être après la date de début"
            );
        }

        if (request.getNewStartTime().isBefore(LocalDateTime.now())) {
            throw new RuntimeException(
                    "Le nouveau créneau ne peut pas être dans le passé"
            );
        }

        Set<AppointmentStatus> activeStatuses =
                EnumSet.of(AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED);

        boolean conflict =
                appointmentRepository
                        .existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusInAndIdNot(
                                appointment.getPsychologistId(),
                                request.getNewEndTime(),
                                request.getNewStartTime(),
                                activeStatuses,
                                appointment.getId()
                        );

        if (conflict) {
            throw new RuntimeException(
                    "Le psychologue possède déjà un rendez-vous sur ce nouveau créneau"
            );
        }

        boolean patientConflict =
                appointmentRepository
                        .existsByPatientIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusInAndIdNot(
                                appointment.getPatientId(),
                                request.getNewEndTime(),
                                request.getNewStartTime(),
                                activeStatuses,
                                appointment.getId()
                        );

        if (patientConflict) {
            throw new RuntimeException(
                    "Vous avez déjà un autre rendez-vous sur ce nouveau créneau"
            );
        }

        boolean wasConfirmed =
                appointment.getStatus() == AppointmentStatus.CONFIRMED;

        appointment.setStartTime(request.getNewStartTime());
        appointment.setEndTime(request.getNewEndTime());

        if (wasConfirmed) {
            // le psy doit reconfirmer le nouveau créneau
            appointment.setStatus(AppointmentStatus.PENDING);
        }

        Appointment updatedAppointment =
                appointmentRepository.save(appointment);

        notificationClient.send(
                updatedAppointment.getPsychologistId(),
                "Rendez-vous reporté",
                wasConfirmed
                        ? "Un patient a reporté un rendez-vous confirmé à un nouveau créneau : veuillez le reconfirmer."
                        : "Un patient a reporté un rendez-vous en attente à un nouveau créneau.",
                "APPOINTMENT",
                "PSYCHOLOGIST"
        );

        return mapToResponse(updatedAppointment);
    }

    @Override
    public List<AppointmentResponse>
    getAppointmentsByPsychologistId(
            Long psychologistId
    ) {

        Long ownId = null;
        try {
            ownId = ownershipResolver.resolveOwnPsychologistId();
        } catch (Exception ex) {
            LOGGER.error("[appointment] resolveOwnPsychologistId a échoué pour GET /appointments/psychologist/{}: {}",
                    psychologistId, ex.getMessage());
            throw ex;
        }
        boolean hasRole = SecurityUtils.hasRole("PSYCHOLOGIST");
        LOGGER.info("[appointment] GET /psychologist/{} | hasRole={} | ownId={}", psychologistId, hasRole, ownId);
        if (!hasRole || !ownId.equals(psychologistId)) {
            LOGGER.warn("[appointment] Accès refusé : hasRole={}, ownId={}, psychologistId={}", hasRole, ownId, psychologistId);
            throw new ForbiddenOperationException(
                    "Vous ne pouvez consulter que vos propres rendez-vous"
            );
        }

        List<Appointment> appointments =
                appointmentRepository
                        .findByPsychologistId(
                                psychologistId
                        );

        return appointments
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public List<AppointmentResponse>
    getAppointmentsByPatientId(
            Long patientId
    ) {

        if (!SecurityUtils.hasRole("PATIENT")
                || !ownershipResolver.resolveOwnPatientId().equals(patientId)) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez consulter que vos propres rendez-vous"
            );
        }

        List<Appointment> appointments =
                appointmentRepository
                        .findByPatientId(
                                patientId
                        );

        return appointments
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public List<AppointmentResponse> getAllAppointmentsForAdmin(String status) {

        List<Appointment> appointments;

        if (status == null || status.isBlank()) {
            appointments = appointmentRepository.findAll();
        } else {
            appointments = appointmentRepository.findByStatus(
                    AppointmentStatus.valueOf(status.toUpperCase())
            );
        }

        return appointments
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    private AppointmentResponse mapToResponse(
            Appointment appointment
    ) {

        AppointmentResponse response =
                new AppointmentResponse();

        response.setId(
                appointment.getId()
        );

        response.setPatientId(
                appointment.getPatientId()
        );

        response.setPsychologistId(
                appointment.getPsychologistId()
        );

        response.setStartTime(
                appointment.getStartTime()
        );

        response.setEndTime(
                appointment.getEndTime()
        );

        response.setConsultationType(
                appointment.getConsultationType()
        );

        response.setStatus(
                appointment.getStatus()
        );

        response.setCreatedAt(
                appointment.getCreatedAt()
        );

        return response;
    }

    @Override
    public void deleteAppointment(Long id) {

        Appointment appointment =
                appointmentRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Rendez-vous non trouvé"
                                )
                        );

        // Seul le patient peut supprimer, jamais le psychologue
        if (!SecurityUtils.hasRole("PATIENT")
                || !ownershipResolver.resolveOwnPatientId().equals(appointment.getPatientId())) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez supprimer que vos propres rendez-vous"
            );
        }

        // que annulé ou refusé peut etre supprimé, le reste reste visible
        if (appointment.getStatus() != AppointmentStatus.CANCELLED
                && appointment.getStatus() != AppointmentStatus.REJECTED) {
            throw new ForbiddenOperationException(
                    "Seuls les rendez-vous annulés ou refusés peuvent être supprimés"
            );
        }

        appointmentRepository.delete(appointment);
    }

    // Appel inter-service uniquement : user-service vérifie que le psychologue a déjà
    // eu un RDV avec ce patient avant d'ouvrir l'acces aux notes cliniques /
    // antecedents medicaux. Pas de check de role ici : la protection est faite
    // en amont (endpoint /patients/*/clinical-notes exige PSYCHOLOGIST).
    @Override
    public boolean hasAnyAppointmentBetween(Long psychologistId, Long patientId, boolean requireCompleted) {
        if (requireCompleted) {
            return appointmentRepository.existsByPatientIdAndPsychologistIdAndStatus(
                    patientId, psychologistId, AppointmentStatus.COMPLETED
            );
        }
        return appointmentRepository.existsByPatientIdAndPsychologistId(patientId, psychologistId);
    }
}
