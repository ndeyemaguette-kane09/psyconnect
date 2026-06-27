package com.example.appointmentservice.service.impl;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.example.appointmentservice.client.NotificationClient;
import com.example.appointmentservice.dto.SessionResponse;
import com.example.appointmentservice.dto.StartSessionRequest;
import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.Session;
import com.example.appointmentservice.entity.SessionStatus;
import com.example.appointmentservice.exception.ForbiddenOperationException;
import com.example.appointmentservice.exception.ResourceNotFoundException;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.SessionRepository;
import com.example.appointmentservice.security.SecurityUtils;
import com.example.appointmentservice.service.OwnershipResolver;
import com.example.appointmentservice.service.SessionService;

@Service
public class SessionServiceImpl implements SessionService {

    private final SessionRepository sessionRepository;
    private final AppointmentRepository appointmentRepository;
    private final NotificationClient notificationClient;
    private final OwnershipResolver ownershipResolver;

    public SessionServiceImpl(
            SessionRepository sessionRepository,
            AppointmentRepository appointmentRepository,
            NotificationClient notificationClient,
            OwnershipResolver ownershipResolver
    ) {
        this.sessionRepository = sessionRepository;
        this.appointmentRepository = appointmentRepository;
        this.notificationClient = notificationClient;
        this.ownershipResolver = ownershipResolver;
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
                "Cette session ne concerne pas un rendez-vous qui vous appartient"
        );
    }

    @Override
    public SessionResponse startSession(StartSessionRequest request) {

        Appointment appointment =
                appointmentRepository.findById(request.getAppointmentId())
                        .orElseThrow(() -> new ResourceNotFoundException(
                                "Rendez-vous non trouvé"
                        ));

        checkParticipant(appointment);

        if (appointment.getStatus() != AppointmentStatus.CONFIRMED) {
            throw new RuntimeException(
                    "La session ne peut démarrer que pour un rendez-vous confirmé (paiement requis)"
            );
        }

        // Fenêtre autorisée : 10 min avant le créneau jusqu'à sa fin. Le
        // frontend applique déjà ce filtre côté UI, mais la vraie garantie
        // reste ce contrôle serveur.
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime earliestStart = appointment.getStartTime().minusMinutes(10);

        if (now.isBefore(earliestStart)) {
            throw new RuntimeException(
                    "Ce rendez-vous n'a pas encore commencé : vous pourrez "
                            + "rejoindre l'appel 10 minutes avant l'heure prévue"
            );
        }

        if (now.isAfter(appointment.getEndTime())) {
            throw new RuntimeException(
                    "Le créneau de ce rendez-vous est terminé"
            );
        }

        boolean alreadyInProgress = sessionRepository
                .existsByAppointmentIdAndStatus(
                        appointment.getId(),
                        SessionStatus.IN_PROGRESS
                );

        if (alreadyInProgress) {
            throw new RuntimeException(
                    "Une session est déjà en cours pour ce rendez-vous"
            );
        }

        // Simulation : pas d'intégration réelle avec Agora SDK, on génère
        // un jeton de session simulé et on enregistre le début de session.
        Session session = new Session();
        session.setAppointmentId(appointment.getId());
        session.setStatus(SessionStatus.IN_PROGRESS);
        session.setMeetingToken("SIM-AGORA-" + UUID.randomUUID());
        session.setStartedAt(LocalDateTime.now());

        Session savedSession = sessionRepository.save(session);

        appointment.setMeetingLink(savedSession.getMeetingToken());
        appointmentRepository.save(appointment);

        return mapToResponse(savedSession);
    }

    @Override
    public SessionResponse endSession(Long id) {

        Session session = sessionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Session non trouvée"
                ));

        Appointment appointment =
                appointmentRepository.findById(session.getAppointmentId())
                        .orElseThrow(() -> new ResourceNotFoundException(
                                "Rendez-vous non trouvé"
                        ));

        checkParticipant(appointment);

        if (session.getStatus() != SessionStatus.IN_PROGRESS) {
            throw new RuntimeException(
                    "Cette session n'est pas en cours"
            );
        }

        session.setEndedAt(LocalDateTime.now());
        session.setStatus(SessionStatus.COMPLETED);

        Session updatedSession = sessionRepository.save(session);

        appointment.setStatus(AppointmentStatus.COMPLETED);
        appointmentRepository.save(appointment);

        sendSessionEndedNotification(appointment);

        return mapToResponse(updatedSession);
    }

    @Override
    public SessionResponse getSessionById(Long id) {

        Session session = sessionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Session non trouvée"
                ));

        Appointment appointment =
                appointmentRepository.findById(session.getAppointmentId())
                        .orElseThrow(() -> new ResourceNotFoundException(
                                "Rendez-vous non trouvé"
                        ));

        checkParticipant(appointment);

        return mapToResponse(session);
    }

    @Override
    public List<SessionResponse> getSessionsByAppointmentId(Long appointmentId) {

        Appointment appointment = appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Rendez-vous non trouvé"
                ));

        checkParticipant(appointment);

        return sessionRepository.findByAppointmentId(appointmentId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    private void sendSessionEndedNotification(Appointment appointment) {

        notificationClient.send(
                appointment.getPatientId(),
                "Session terminée",
                "Votre session avec votre psychologue est terminée.",
                "SESSION"
        );
    }

    private SessionResponse mapToResponse(Session session) {

        SessionResponse response = new SessionResponse();

        response.setId(session.getId());
        response.setAppointmentId(session.getAppointmentId());
        response.setStatus(session.getStatus());
        response.setMeetingToken(session.getMeetingToken());
        response.setStartedAt(session.getStartedAt());
        response.setEndedAt(session.getEndedAt());
        response.setCreatedAt(session.getCreatedAt());

        if (session.getStartedAt() != null && session.getEndedAt() != null) {
            response.setDurationSeconds(
                    Duration.between(
                            session.getStartedAt(),
                            session.getEndedAt()
                    ).getSeconds()
            );
        }

        return response;
    }
}
