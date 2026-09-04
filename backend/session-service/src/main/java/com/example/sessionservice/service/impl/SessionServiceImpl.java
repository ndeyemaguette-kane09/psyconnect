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

    // Verrou en memoire, un seul par instance du service : protege la sequence
    // "verifier qu'aucune session IN_PROGRESS n'existe puis en creer une" contre
    // une execution concurrente. Sans lui, deux appels quasi simultanes a
    // /sessions/start (typiquement patient + psy qui rejoignent en meme temps)
    // passent tous les deux le controle "aucune session en cours" AVANT que l'un
    // des deux ait sauvegarde la sienne : chacun cree alors sa propre session,
    // avec un meetingToken (donc un salon Jitsi) different -> les deux
    // participants se retrouvent chacun seul dans sa salle. C'est la cause
    // reelle du bug "salle d'attente" remonte par magui, pas une simple absence
    // de controle : le controle existait deja (existsByAppointmentIdAndStatus)
    // mais n'etait pas atomique avec la creation.
    // Limite assumee : ce verrou ne protege que cette instance JVM. Suffisant
    // ici (un seul exemplaire de chaque service, pas de scaling horizontal dans
    // ce MVP), a documenter comme limite si le sujet revient en soutenance.
    private final Object sessionStartLock = new Object();

    public SessionServiceImpl(
            SessionRepository sessionRepository,
            AppointmentClient appointmentClient,
            NotificationClient notificationClient,
            OwnershipResolver ownershipResolver
    ) {
        this.sessionRepository = sessionRepository;
        this.appointmentClient = appointmentClient;
        this.notificationClient = notificationClient;
        this.ownershipResolver = ownershipResolver;
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
            // "Get" avant "create" : si une session IN_PROGRESS existe deja pour
            // ce rendez-vous (demarree par l'autre participant, ou par nous-memes
            // apres avoir quitte puis relance l'appel), on la rejoint au lieu
            // d'en creer une nouvelle. C'est ce qui garantit que les deux
            // participants atterrissent toujours dans le meme salon Jitsi.
            // Volontairement AVANT les controles de statut/horaire ci-dessous :
            // rejoindre une session deja ouverte doit marcher meme si on s'y
            // reconnecte un peu apres la fin theorique du creneau.
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
            // +30 min de marge, alignee sur la fenetre "callWindowOpen" deja
            // utilisee cote Flutter (appointments_tab.dart / agenda_tab.dart) :
            // avant, le backend refusait un tout premier demarrage passe
            // l'heure de fin exacte, alors que l'UI le proposait encore.
            if (now.isAfter(appt.getEndTime().plusMinutes(30))) {
                throw new RuntimeException("Le créneau de ce rendez-vous est terminé");
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

    @Override
    public SessionResponse startEmergencySession(StartEmergencySessionRequest request) {
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

        return mapToResponse(sessionRepository.save(session));
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
            Session updated = sessionRepository.save(session);
            notificationClient.send(
                    session.getEmergencyPatientId(),
                    "Session d'urgence terminée",
                    "Votre session d'urgence est terminée. Prenez soin de vous.",
                    "SESSION",
                    "PATIENT"
            );
            return mapToResponse(updated);
        }

        AppointmentDto appt = appointmentClient.getAppointment(session.getAppointmentId());
        checkParticipant(appt);

        Session updated = sessionRepository.save(session);

        // marquer le RDV COMPLETED dans appointment-service (best-effort)
        appointmentClient.updateAppointmentStatus(appt.getId(), "COMPLETED");

        // notifier le patient
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
        // pas de vérification de participation pour les sessions urgence
        if (!Boolean.TRUE.equals(session.getEmergencyMode())) {
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
        if (s.getStartedAt() != null && s.getEndedAt() != null) {
            r.setDurationSeconds(Duration.between(s.getStartedAt(), s.getEndedAt()).getSeconds());
        }
        return r;
    }
}
