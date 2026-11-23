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
import com.example.appointmentservice.entity.CancellationReason;
import com.example.appointmentservice.entity.ConsultationType;
import com.example.appointmentservice.exception.ForbiddenOperationException;
import com.example.appointmentservice.exception.ResourceNotFoundException;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.security.SecurityUtils;
import com.example.appointmentservice.service.AppointmentService;
import com.example.appointmentservice.service.OwnershipResolver;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
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

    private void checkParticipant(Appointment appointment) {

        if (SecurityUtils.hasRole("SERVICE")) {
            return;
        }

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

        if (!ownershipResolver.isPsychologistVerified(request.getPsychologistId())) {
            throw new ForbiddenOperationException(
                    "Ce psychologue n'a pas encore été approuvé par un "
                            + "administrateur et ne peut pas recevoir de rendez-vous"
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

        if (request.getStartTime().isBefore(LocalDateTime.now().plusHours(2))) {
            throw new RuntimeException(
                    "Un rendez-vous doit être réservé au moins 2 heures à l'avance"
            );
        }

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

        if (request.getConsultationType() == ConsultationType.PHYSICAL) {
            checkReceivesAtOffice(request.getPsychologistId());
        }

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

        notifyPatient(
                savedAppointment.getId(),
                request.getPatientId(),
                "Demande de rendez-vous envoyée",
                "Votre demande de rendez-vous est en cours de traitement. "
                        + "Elle doit être confirmée par le psychologue avant "
                        + "d'être effective."
        );

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

    private void notifyPatient(
            Long appointmentId,
            Long patientId,
            String title,
            String message
    ) {

        notificationClient.sendAboutAppointment(
                patientId,
                title,
                message,
                "APPOINTMENT",
                "PATIENT",
                appointmentId
        );
    }

    private void notifyPsychologist(
            Long appointmentId,
            Long psychologistId,
            String title,
            String message
    ) {

        notificationClient.sendAboutAppointment(
                psychologistId,
                title,
                message,
                "APPOINTMENT",
                "PSYCHOLOGIST",
                appointmentId
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

        if (SecurityUtils.hasRole("SERVICE")
                && !(newStatus == AppointmentStatus.COMPLETED
                        && appointment.getStatus() == AppointmentStatus.CONFIRMED)) {
            throw new ForbiddenOperationException(
                    "Un service interne ne peut que clôturer un rendez-vous confirmé"
            );
        }

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
        if (newStatus == AppointmentStatus.COMPLETED && !SecurityUtils.hasRole("SERVICE")) {
            if (!callerIsPsychologist) {
                throw new ForbiddenOperationException(
                        "Seul le psychologue peut terminer la séance"
                );
            }
            if (appointment.getStatus() != AppointmentStatus.CONFIRMED) {
                throw new ForbiddenOperationException(
                        "Seule une séance confirmée peut être terminée"
                );
            }
            if (appointment.getStartTime().isAfter(LocalDateTime.now())) {
                throw new ForbiddenOperationException(
                        "La séance n'a pas encore commencé"
                );
            }
            if (!paymentClient.hasCompletedPayment(appointment.getId())) {
                throw new ForbiddenOperationException(
                        "Cette séance n'a pas été payée"
                );
            }
        }
        if (newStatus == AppointmentStatus.CANCELLED && callerIsPsychologist) {
            throw new ForbiddenOperationException(
                    "Seul le patient peut annuler ce rendez-vous"
            );
        }
        if (newStatus == AppointmentStatus.CONFIRMED) {
            if (appointment.getStatus() != AppointmentStatus.PENDING) {
                throw new ForbiddenOperationException(
                        "Seul un rendez-vous en attente peut être confirmé"
                );
            }
            if (!appointment.getStartTime().isAfter(LocalDateTime.now().plusHours(1))) {
                throw new ForbiddenOperationException(
                        "Le délai est dépassé : un rendez-vous doit être confirmé au moins 1 heure avant son début"
                );
            }
        }

        if (newStatus == AppointmentStatus.REJECTED && appointment.hasPendingModalityChange()) {
            return declineModalityChange(appointment);
        }

        boolean modalityConfirmation = newStatus == AppointmentStatus.CONFIRMED
                && appointment.hasPendingModalityChange();

        appointment.setStatus(
                newStatus
        );
        appointment.setModalityChangePending(Boolean.FALSE);

        if (newStatus == AppointmentStatus.CANCELLED) {
            appointment.setCancellationReason(CancellationReason.PATIENT);
            appointment.setCancelledAt(LocalDateTime.now());
        }

        Appointment updatedAppointment =
                appointmentRepository.save(
                        appointment
                );

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

        String title;
        String message;

        switch (newStatus) {
            case CONFIRMED:
                title = modalityConfirmation ? "Séance au cabinet confirmée" : "Rendez-vous confirmé";
                message = modalityConfirmation
                        ? "Votre psychologue vous recevra au cabinet pour cette séance."
                        : "Votre rendez-vous a été confirmé par le psychologue. "
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

        if (newStatus == AppointmentStatus.CANCELLED) {
            notifyPsychologist(
                    updatedAppointment.getId(),
                    updatedAppointment.getPsychologistId(),
                    "Rendez-vous annulé",
                    "Un patient a annulé son rendez-vous du "
                            + updatedAppointment.getStartTime().format(
                                    java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy 'à' HH:mm"))
                            + "."
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

        if (appointment.getStartTime().isBefore(LocalDateTime.now().plusHours(48))) {
            throw new RuntimeException(
                    "Un rendez-vous ne peut plus être reporté moins de 48 heures avant son début"
            );
        }

        if (request.getNewStartTime().isBefore(LocalDateTime.now().plusHours(2))) {
            throw new RuntimeException(
                    "Le nouveau créneau doit commencer au moins 2 heures après maintenant"
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
    public AppointmentResponse changeConsultationType(
            Long id,
            ConsultationType consultationType
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
                    "Seul le patient à l'origine du rendez-vous peut changer sa modalité"
            );
        }

        if (appointment.getStatus() != AppointmentStatus.PENDING
                && appointment.getStatus() != AppointmentStatus.CONFIRMED) {
            throw new RuntimeException(
                    "Seul un rendez-vous en attente ou confirmé peut être modifié"
            );
        }

        if (consultationType == ConsultationType.CHAT) {
            throw new RuntimeException("Cette modalité n'est pas proposée");
        }

        if (consultationType == appointment.getConsultationType()) {
            return mapToResponse(appointment);
        }

        if (appointment.getStartTime().isBefore(LocalDateTime.now().plusHours(24))) {
            throw new RuntimeException(
                    "La modalité ne peut plus être changée moins de 24 heures avant la séance"
            );
        }

        if (consultationType == ConsultationType.PHYSICAL) {
            checkReceivesAtOffice(appointment.getPsychologistId());
        }

        ConsultationType previousType = appointment.getConsultationType();
        boolean wasConfirmed = appointment.getStatus() == AppointmentStatus.CONFIRMED
                || appointment.hasPendingModalityChange();
        boolean needsReconfirmation = consultationType == ConsultationType.PHYSICAL && wasConfirmed;

        appointment.setPreviousConsultationType(previousType);
        appointment.setConsultationType(consultationType);
        appointment.setModalityChangePending(needsReconfirmation);
        if (needsReconfirmation) {
            appointment.setStatus(AppointmentStatus.PENDING);
        } else if (wasConfirmed) {
            appointment.setStatus(AppointmentStatus.CONFIRMED);
        }

        Appointment updatedAppointment = appointmentRepository.save(appointment);

        String when = updatedAppointment.getStartTime().format(
                java.time.format.DateTimeFormatter.ofPattern("dd/MM 'à' HH:mm"));

        notifyPsychologist(
                updatedAppointment.getId(),
                updatedAppointment.getPsychologistId(),
                needsReconfirmation ? "Séance au cabinet demandée" : "Modalité de séance modifiée",
                "Un patient souhaite que sa séance du " + when + " se fasse "
                        + modalityLabel(consultationType) + " plutôt qu'" + modalityLabel(previousType)
                        + (needsReconfirmation
                                ? ". Ouvrez la notification pour confirmer votre disponibilité."
                                : ".")
        );

        return mapToResponse(updatedAppointment);
    }

    private void checkReceivesAtOffice(Long psychologistId) {
        Map<String, Object> psychologist = ownershipResolver.getPsychologistProfile(psychologistId);
        Object address = psychologist == null ? null : psychologist.get("address");
        if (address == null || address.toString().isBlank()) {
            throw new RuntimeException("Ce psychologue ne reçoit pas au cabinet");
        }
    }

    private AppointmentResponse declineModalityChange(Appointment appointment) {
        ConsultationType declined = appointment.getConsultationType();
        appointment.revertModalityChange();
        Appointment saved = appointmentRepository.save(appointment);

        notifyPatient(
                saved.getId(),
                saved.getPatientId(),
                "Changement de modalité refusé",
                "Votre psychologue ne peut pas vous recevoir " + modalityLabel(declined)
                        + " à cette date : votre séance reste confirmée "
                        + modalityLabel(saved.getConsultationType()) + "."
        );

        return mapToResponse(saved);
    }

    private String modalityLabel(ConsultationType type) {
        if (type == null) return "";
        switch (type) {
            case VIDEO:
                return "en vidéo";
            case AUDIO:
                return "en audio";
            case PHYSICAL:
                return "au cabinet";
            default:
                return "par messagerie";
        }
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

        response.setCancellationReason(
                appointment.getCancellationReason()
        );

        response.setCancelledAt(
                appointment.getCancelledAt()
        );

        response.setPreviousConsultationType(
                appointment.getPreviousConsultationType()
        );

        response.setModalityChangePending(
                appointment.hasPendingModalityChange()
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

        if (!SecurityUtils.hasRole("PATIENT")
                || !ownershipResolver.resolveOwnPatientId().equals(appointment.getPatientId())) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez supprimer que vos propres rendez-vous"
            );
        }

        if (appointment.getStatus() != AppointmentStatus.CANCELLED
                && appointment.getStatus() != AppointmentStatus.REJECTED) {
            throw new ForbiddenOperationException(
                    "Seuls les rendez-vous annulés ou refusés peuvent être supprimés"
            );
        }

        appointmentRepository.delete(appointment);
    }

    @Override
    public boolean hasAnyAppointmentBetween(Long psychologistId, Long patientId, boolean requireCompleted, boolean requireAccepted) {
        if (requireAccepted) {
            return appointmentRepository.existsByPatientIdAndPsychologistIdAndStatusIn(
                    patientId, psychologistId,
                    java.util.List.of(AppointmentStatus.CONFIRMED, AppointmentStatus.COMPLETED)
            );
        }
        if (requireCompleted) {
            return appointmentRepository.existsByPatientIdAndPsychologistIdAndStatus(
                    patientId, psychologistId, AppointmentStatus.COMPLETED
            );
        }
        return appointmentRepository.existsByPatientIdAndPsychologistId(patientId, psychologistId);
    }
}
