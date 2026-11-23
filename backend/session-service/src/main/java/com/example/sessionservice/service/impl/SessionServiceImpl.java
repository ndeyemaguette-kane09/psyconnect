package com.example.sessionservice.service.impl;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.example.sessionservice.client.AppointmentClient;
import com.example.sessionservice.client.NotificationClient;
import com.example.sessionservice.client.PaymentClient;
import com.example.sessionservice.dto.AdminEmergencySessionResponse;
import com.example.sessionservice.dto.AppointmentDto;
import com.example.sessionservice.dto.SessionResponse;
import com.example.sessionservice.dto.StartEmergencySessionRequest;
import com.example.sessionservice.dto.StartSessionRequest;
import com.example.sessionservice.entity.Session;
import com.example.sessionservice.entity.SessionStatus;
import com.example.sessionservice.exception.ForbiddenOperationException;
import com.example.sessionservice.exception.ResourceNotFoundException;
import com.example.sessionservice.repository.SessionRepository;
import com.example.sessionservice.security.SecurityUtils;
import com.example.sessionservice.service.OwnershipResolver;
import com.example.sessionservice.service.SessionService;

@Service
public class SessionServiceImpl implements SessionService {

    private final SessionRepository sessionRepository;
    private final AppointmentClient appointmentClient;
    private final NotificationClient notificationClient;
    private final OwnershipResolver ownershipResolver;
    private final PaymentClient paymentClient;

    // au-delà, l'appel n'est plus proposé au psychologue
    private static final long EMERGENCY_RING_MINUTES = 15;

    // évite deux salons quand patient et psy rejoignent au même moment
    private final Object sessionStartLock = new Object();

    public SessionServiceImpl(
            SessionRepository sessionRepository,
            AppointmentClient appointmentClient,
            NotificationClient notificationClient,
            OwnershipResolver ownershipResolver,
            PaymentClient paymentClient
    ) {
        this.sessionRepository = sessionRepository;
        this.appointmentClient = appointmentClient;
        this.notificationClient = notificationClient;
        this.ownershipResolver = ownershipResolver;
        this.paymentClient = paymentClient;
    }

    // vérifie que l'appelant est bien patient ou psy du RDV
    private void checkParticipant(AppointmentDto appt) {
        if (SecurityUtils.hasRole("PATIENT")
                && ownershipResolver.resolveOwnPatientId().equals(appt.getPatientId())) return;
        if (SecurityUtils.hasRole("PSYCHOLOGIST")
                && ownershipResolver.resolveOwnPsychologistId().equals(appt.getPsychologistId())) return;
        throw new ForbiddenOperationException(
                "Cette session ne concerne pas un rendez-vous qui vous appartient");
    }

    @Override
    public SessionResponse startSession(StartSessionRequest request) {
        AppointmentDto appt = appointmentClient.getAppointment(request.getAppointmentId());
        checkParticipant(appt);

        synchronized (sessionStartLock) {
            Optional<Session> existing = sessionRepository
                    .findFirstByAppointmentIdAndStatus(appt.getId(), SessionStatus.IN_PROGRESS);
            if (existing.isPresent()) {
                return mapToResponse(existing.get());
            }

            if (!"CONFIRMED".equals(appt.getStatus())) {
                throw new RuntimeException(
                        "La session ne peut démarrer que pour un rendez-vous confirmé (paiement requis)");
            }

            LocalDateTime now = LocalDateTime.now();
            if (now.isBefore(appt.getStartTime().minusMinutes(10))) {
                throw new RuntimeException(
                        "Ce rendez-vous n'a pas encore commencé : vous pourrez rejoindre "
                                + "l'appel 10 minutes avant l'heure prévue");
            }
            if (now.isAfter(appt.getEndTime().plusMinutes(30))) {
                throw new RuntimeException("Le créneau de ce rendez-vous est terminé");
            }

            if (!paymentClient.isPaid(appt.getId())) {
                throw new RuntimeException(
                        "Ce rendez-vous n'est pas encore payé : réglez-le pour pouvoir rejoindre l'appel");
            }

            // nom de room Jitsi : psyconnect-{rdvId}-{uuid8}
            // les deux participants rejoignent le même room avec ce token
            String roomName = "psyconnect-" + appt.getId() + "-"
                    + UUID.randomUUID().toString().replace("-", "").substring(0, 8);

            Session session = new Session();
            session.setAppointmentId(appt.getId());
            session.setStatus(SessionStatus.IN_PROGRESS);
            session.setMeetingToken(roomName);
            session.setStartedAt(LocalDateTime.now());

            return mapToResponse(sessionRepository.save(session));
        }
    }

    private void checkEmergencyParticipant(Session session) {
        if (SecurityUtils.hasRole("PATIENT")
                && ownershipResolver.resolveOwnPatientId().equals(session.getEmergencyPatientId())) return;
        if (SecurityUtils.hasRole("PSYCHOLOGIST")
                && ownershipResolver.resolveOwnPsychologistId().equals(session.getEmergencyPsychologistId())) return;
        throw new ForbiddenOperationException("Cet appel d'urgence ne vous concerne pas");
    }

    @Override
    public SessionResponse startEmergencySession(StartEmergencySessionRequest request) {
        if (!SecurityUtils.hasRole("PATIENT")) {
            throw new ForbiddenOperationException("Seul un patient peut lancer un appel d'urgence");
        }
        if (!ownershipResolver.resolveOwnPatientId().equals(request.getPatientId())) {
            throw new ForbiddenOperationException("Ce profil patient ne vous appartient pas");
        }
        if (!ownershipResolver.isOnEmergencyDuty(request.getPsychologistId())) {
            throw new ForbiddenOperationException("Ce psychologue n'est pas de garde en ce moment");
        }

        // room Jitsi SOS : préfixe "psyconnect-sos-" pour distinguer des sessions normales
        String roomName = "psyconnect-sos-" + request.getPatientId() + "-"
                + UUID.randomUUID().toString().replace("-", "").substring(0, 8);

        Session session = new Session();
        session.setEmergencyMode(true);
        session.setEmergencyPatientId(request.getPatientId());
        session.setEmergencyPsychologistId(request.getPsychologistId());
        session.setStatus(SessionStatus.IN_PROGRESS);
        session.setMeetingToken(roomName);
        session.setStartedAt(LocalDateTime.now());
        // appointmentId = null pour les sessions urgence

        Session saved = sessionRepository.save(session);

        notificationClient.send(
                request.getPsychologistId(),
                "Appel d'urgence",
                "Un patient a besoin de vous maintenant. Ouvrez PsyConnect pour rejoindre l'appel.",
                "SESSION",
                "PSYCHOLOGIST"
        );

        return mapToResponse(saved);
    }

    @Override
    public List<SessionResponse> getIncomingEmergencySessions() {
        if (!SecurityUtils.hasRole("PSYCHOLOGIST")) {
            throw new ForbiddenOperationException("Réservé aux psychologues");
        }
        Long psychologistId = ownershipResolver.resolveOwnPsychologistId();
        return sessionRepository
                .findByEmergencyModeTrueAndEmergencyPsychologistIdAndStatusAndStartedAtAfter(
                        psychologistId,
                        SessionStatus.IN_PROGRESS,
                        LocalDateTime.now().minusMinutes(EMERGENCY_RING_MINUTES))
                .stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    @Override
    public SessionResponse joinEmergencySession(Long id) {
        Session session = findEmergencySession(id);
        if (!SecurityUtils.hasRole("PSYCHOLOGIST")) {
            throw new ForbiddenOperationException("Réservé au psychologue appelé");
        }
        checkEmergencyParticipant(session);
        if (session.getStatus() != SessionStatus.IN_PROGRESS) {
            throw new ForbiddenOperationException("Cet appel d'urgence n'est plus en cours");
        }
        if (session.getPsychologistJoinedAt() == null) {
            session.setPsychologistJoinedAt(LocalDateTime.now());
            session = sessionRepository.save(session);
        }
        return mapToResponse(session);
    }

    @Override
    public SessionResponse cancelEmergencySession(Long id) {
        Session session = findEmergencySession(id);
        if (!SecurityUtils.hasRole("PATIENT")) {
            throw new ForbiddenOperationException("Seul le patient peut annuler son appel");
        }
        checkEmergencyParticipant(session);
        if (session.getStatus() != SessionStatus.IN_PROGRESS) {
            return mapToResponse(session);
        }
        session.setStatus(SessionStatus.CANCELLED);
        session.setEndedAt(LocalDateTime.now());
        return mapToResponse(sessionRepository.save(session));
    }

    @Override
    public SessionResponse declineEmergencySession(Long id) {
        Session session = findEmergencySession(id);
        if (!SecurityUtils.hasRole("PSYCHOLOGIST")) {
            throw new ForbiddenOperationException("Réservé au psychologue appelé");
        }
        checkEmergencyParticipant(session);
        if (session.getStatus() != SessionStatus.IN_PROGRESS
                || session.getPsychologistJoinedAt() != null) {
            return mapToResponse(session);
        }
        session.setStatus(SessionStatus.CANCELLED);
        session.setDeclinedByPsychologist(true);
        session.setEndedAt(LocalDateTime.now());
        return mapToResponse(sessionRepository.save(session));
    }

    @Override
    public List<AdminEmergencySessionResponse> listEmergencySessionsForAdmin() {
        if (!SecurityUtils.hasRole("ADMIN")) {
            throw new ForbiddenOperationException("Réservé à l'administrateur");
        }
        return sessionRepository.findByEmergencyModeTrueOrderByStartedAtDesc()
                .stream()
                .map(s -> {
                    AdminEmergencySessionResponse r = new AdminEmergencySessionResponse();
                    r.setId(s.getId());
                    r.setPsychologistId(s.getEmergencyPsychologistId());
                    r.setStatus(s.getStatus());
                    r.setRequestedAt(s.getStartedAt());
                    r.setAnsweredAt(s.getPsychologistJoinedAt());
                    r.setEndedAt(s.getEndedAt());
                    r.setDeclinedByPsychologist(Boolean.TRUE.equals(s.getDeclinedByPsychologist()));
                    if (s.getPsychologistJoinedAt() != null && s.getEndedAt() != null) {
                        r.setDurationSeconds(Duration.between(
                                s.getPsychologistJoinedAt(), s.getEndedAt()).getSeconds());
                    }
                    return r;
                })
                .collect(Collectors.toList());
    }

    private Session findEmergencySession(Long id) {
        Session session = sessionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Session non trouvée"));
        if (!Boolean.TRUE.equals(session.getEmergencyMode())) {
            throw new ForbiddenOperationException("Cette session n'est pas un appel d'urgence");
        }
        return session;
    }

    @Override
    public SessionResponse endSession(Long id) {
        Session session = sessionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Session non trouvée"));

        if (session.getStatus() != SessionStatus.IN_PROGRESS) {
            throw new RuntimeException("Cette session n'est pas en cours");
        }

        session.setEndedAt(LocalDateTime.now());
        session.setStatus(SessionStatus.COMPLETED);

        // pour les sessions urgence, pas de RDV à mettre à jour
        if (Boolean.TRUE.equals(session.getEmergencyMode())) {
            checkEmergencyParticipant(session);
            return mapToResponse(sessionRepository.save(session));
        }

        if (!SecurityUtils.hasRole("PSYCHOLOGIST")) {
            throw new ForbiddenOperationException("Seul le psychologue peut terminer la séance");
        }

        AppointmentDto appt = appointmentClient.getAppointment(session.getAppointmentId());
        checkParticipant(appt);

        Session updated = sessionRepository.save(session);

        // best-effort
        appointmentClient.updateAppointmentStatus(appt.getId(), "COMPLETED");

        notificationClient.send(
                appt.getPatientId(),
                "Session terminée",
                "Votre session avec votre psychologue est terminée.",
                "SESSION",
                "PATIENT"
        );

        return mapToResponse(updated);
    }

    @Override
    public SessionResponse getSessionById(Long id) {
        Session session = sessionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Session non trouvée"));
        if (Boolean.TRUE.equals(session.getEmergencyMode())) {
            checkEmergencyParticipant(session);
        } else {
            AppointmentDto appt = appointmentClient.getAppointment(session.getAppointmentId());
            checkParticipant(appt);
        }
        return mapToResponse(session);
    }

    @Override
    public List<SessionResponse> getSessionsByAppointmentId(Long appointmentId) {
        AppointmentDto appt = appointmentClient.getAppointment(appointmentId);
        checkParticipant(appt);
        return sessionRepository.findByAppointmentId(appointmentId)
                .stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    private SessionResponse mapToResponse(Session s) {
        SessionResponse r = new SessionResponse();
        r.setId(s.getId());
        r.setAppointmentId(s.getAppointmentId());
        r.setStatus(s.getStatus());
        r.setMeetingToken(s.getMeetingToken());
        r.setStartedAt(s.getStartedAt());
        r.setEndedAt(s.getEndedAt());
        r.setCreatedAt(s.getCreatedAt());
        r.setEmergencyMode(s.getEmergencyMode());
        r.setEmergencyPatientId(s.getEmergencyPatientId());
        r.setEmergencyPsychologistId(s.getEmergencyPsychologistId());
        r.setPsychologistJoinedAt(s.getPsychologistJoinedAt());
        r.setDeclinedByPsychologist(Boolean.TRUE.equals(s.getDeclinedByPsychologist()));
        if (s.getStartedAt() != null && s.getEndedAt() != null) {
            r.setDurationSeconds(Duration.between(s.getStartedAt(), s.getEndedAt()).getSeconds());
        }
        return r;
    }
}
