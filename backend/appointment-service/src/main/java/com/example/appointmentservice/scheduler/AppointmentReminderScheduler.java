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
        LocalDateTime windowStart = now.plusMinutes(10);
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
                        "Votre rendez-vous commence dans 10 minutes, à " + time + ".",
                        "REMINDER",
                        "PATIENT"
                );

                notificationClient.send(
                        appointment.getPsychologistId(),
                        "Rappel de rendez-vous",
                        "Vous avez un rendez-vous dans 10 minutes, à " + time + ".",
                        "REMINDER",
                        "PSYCHOLOGIST"
                );

                appointment.setReminderSent(true);
                appointmentRepository.save(appointment);
            } catch (Exception e) {
                LOGGER.warn(
                        "Échec de l'envoi du rappel pour le rendez-vous {}",
                        appointment.getId(),
                        e
                );
            }
        }
    }
}
