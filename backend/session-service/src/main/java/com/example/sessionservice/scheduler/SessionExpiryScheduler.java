package com.example.sessionservice.scheduler;

import java.time.LocalDateTime;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.example.sessionservice.client.AppointmentClient;
import com.example.sessionservice.client.NotificationClient;
import com.example.sessionservice.dto.AppointmentDto;
import com.example.sessionservice.entity.Session;
import com.example.sessionservice.entity.SessionStatus;
import com.example.sessionservice.repository.SessionRepository;

/**
 * Clôture automatiquement les sessions d'appel restées IN_PROGRESS au-delà de
 * la fenêtre de leur rendez-vous (heure de fin + 30 min de marge — la même
 * marge que celle utilisée pour autoriser la reconnexion côté
 * SessionServiceImpl.startSession et côté Flutter).
 *
 * Complément indispensable au choix produit "la séance reste active tant que
 * l'horaire du RDV n'est pas dépassé" : depuis que CallScreen ne ferme plus
 * la session au raccroché (voir _onConferenceTerminated), plus rien côté
 * client ne clôture jamais une session — sans ce job, elle resterait
 * IN_PROGRESS indéfiniment.
 *
 * Ne concerne pas les sessions d'urgence (appointmentId == null) : elles
 * n'ont pas de créneau de référence, leur clôture reste manuelle via
 * PUT /sessions/{id}/end.
 */
@Component
public class SessionExpiryScheduler {

    private static final Logger log = LoggerFactory.getLogger(SessionExpiryScheduler.class);

    // marge après l'heure de fin du RDV, alignée sur SessionServiceImpl.startSession
    // et sur callWindowOpen côté Flutter (appointments_tab.dart / agenda_tab.dart)
    private static final long GRACE_MINUTES = 30;

    private final SessionRepository sessionRepository;
    private final AppointmentClient appointmentClient;
    private final NotificationClient notificationClient;

    public SessionExpiryScheduler(
            SessionRepository sessionRepository,
            AppointmentClient appointmentClient,
            NotificationClient notificationClient
    ) {
        this.sessionRepository = sessionRepository;
        this.appointmentClient = appointmentClient;
        this.notificationClient = notificationClient;
    }

    // toutes les 5 minutes — même cadence que AppointmentReminderScheduler
    // (appointment-service), pour rester cohérent avec le reste du projet
    @Scheduled(fixedRate = 5 * 60 * 1000)
    public void closeExpiredSessions() {
        List<Session> candidates =
                sessionRepository.findByStatusAndAppointmentIdIsNotNull(SessionStatus.IN_PROGRESS);
        if (candidates.isEmpty()) return;

        LocalDateTime now = LocalDateTime.now();
        for (Session session : candidates) {
            try {
                closeIfExpired(session, now);
            } catch (Exception e) {
                // une session en échec (RDV introuvable, appointment-service
                // injoignable...) ne doit pas empêcher de traiter les autres
                log.warn("Impossible de vérifier/clôturer la session {} : {}",
                        session.getId(), e.getMessage());
            }
        }
    }

    private void closeIfExpired(Session session, LocalDateTime now) {
        AppointmentDto appt = appointmentClient.getAppointment(session.getAppointmentId());
        if (appt.getEndTime() == null || now.isBefore(appt.getEndTime().plusMinutes(GRACE_MINUTES))) {
            return;
        }

        session.setEndedAt(now);
        session.setStatus(SessionStatus.COMPLETED);
        sessionRepository.save(session);

        // best-effort, même logique que SessionServiceImpl.endSession
        appointmentClient.updateAppointmentStatus(appt.getId(), "COMPLETED");
        notificationClient.send(
                appt.getPatientId(),
                "Session terminée",
                "Votre session avec votre psychologue est terminée.",
                "SESSION",
                "PATIENT"
        );

        log.info("Session {} (RDV {}) clôturée automatiquement (créneau dépassé)",
                session.getId(), appt.getId());
    }
}
