package com.example.appointmentservice.scheduler;

import java.time.LocalDateTime;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.example.appointmentservice.client.NotificationClient;
import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.repository.AppointmentRepository;

/**
 * Rappel automatique "1h avant le rendez-vous", en notification in-app au
 * patient et au psychologue.
 *
 * Tourne toutes les 5 minutes, fenêtre de 5 min centrée sur "maintenant +
 * 1h" : assez fin pour qu'un rendez-vous donné tombe forcément dans une
 * seule fenêtre. Seuls les rendez-vous CONFIRMED sont concernés (un
 * PENDING n'a pas de garantie de tenir).
 */
@Component
public class AppointmentReminderScheduler {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(AppointmentReminderScheduler.class);

    private static final long WINDOW_MINUTES = 5;

    private final AppointmentRepository appointmentRepository;
    private final NotificationClient notificationClient;

    public AppointmentReminderScheduler(
            AppointmentRepository appointmentRepository,
            NotificationClient notificationClient
    ) {
        this.appointmentRepository = appointmentRepository;
        this.notificationClient = notificationClient;
    }

    @Scheduled(fixedRate = 5 * 60 * 1000)
    public void sendUpcomingReminders() {

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = now.plusHours(1);
        LocalDateTime windowEnd = windowStart.plusMinutes(WINDOW_MINUTES);

        List<Appointment> dueForReminder =
                appointmentRepository
                        .findByStatusAndStartTimeBetweenAndReminderSentFalse(
                                AppointmentStatus.CONFIRMED,
                                windowStart,
                                windowEnd
                        );

        for (Appointment appointment : dueForReminder) {
            try {
                String time = appointment.getStartTime().toLocalTime().toString();

                notificationClient.send(
                        appointment.getPatientId(),
                        "Rappel de rendez-vous",
                        "Votre rendez-vous commence dans environ 1h, à " + time + ".",
                        "REMINDER"
                );

                notificationClient.send(
                        appointment.getPsychologistId(),
                        "Rappel de rendez-vous",
                        "Vous avez un rendez-vous dans environ 1h, à " + time + ".",
                        "REMINDER"
                );

                appointment.setReminderSent(true);
                appointmentRepository.save(appointment);
            } catch (Exception e) {
                // Best-effort, comme tous les autres envois de notification
                // de ce service : un rappel manqué ne doit jamais faire
                // échouer le job pour les autres rendez-vous de la fenêtre.
                LOGGER.warn(
                        "Échec de l'envoi du rappel pour le rendez-vous {}",
                        appointment.getId(),
                        e
                );
            }
        }
    }
}
