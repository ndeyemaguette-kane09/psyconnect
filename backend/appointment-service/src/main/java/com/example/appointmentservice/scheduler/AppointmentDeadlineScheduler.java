package com.example.appointmentservice.scheduler;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.example.appointmentservice.client.NotificationClient;
import com.example.appointmentservice.client.PaymentClient;
import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.CancellationReason;
import com.example.appointmentservice.repository.AppointmentRepository;

@Component
public class AppointmentDeadlineScheduler {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(AppointmentDeadlineScheduler.class);

    private static final DateTimeFormatter DATE_TIME =
            DateTimeFormatter.ofPattern("dd/MM/yyyy 'à' HH:mm");
    private static final DateTimeFormatter TIME =
            DateTimeFormatter.ofPattern("HH:mm");

    private static final long CONFIRMATION_DEADLINE_HOURS = 2;
    private static final long PAYMENT_REMINDER_HOURS = 3;
    private static final long PAYMENT_DEADLINE_HOURS = 1;

    private final AppointmentRepository appointmentRepository;
    private final NotificationClient notificationClient;
    private final PaymentClient paymentClient;

    public AppointmentDeadlineScheduler(
            AppointmentRepository appointmentRepository,
            NotificationClient notificationClient,
            PaymentClient paymentClient
    ) {
        this.appointmentRepository = appointmentRepository;
        this.notificationClient = notificationClient;
        this.paymentClient = paymentClient;
    }

    @Scheduled(fixedRate = 5 * 60 * 1000)
    public void enforceDeadlines() {

        LocalDateTime now = LocalDateTime.now();

        for (Appointment appointment : appointmentRepository.findByStatusAndStartTimeBefore(
                AppointmentStatus.PENDING, now.plusHours(CONFIRMATION_DEADLINE_HOURS))) {
            try {
                cancelUnanswered(appointment, now);
            } catch (Exception e) {
                LOGGER.warn("Annulation automatique impossible pour le rendez-vous {}",
                        appointment.getId(), e);
            }
        }

        for (Appointment appointment : appointmentRepository.findByStatusAndStartTimeBetween(
                AppointmentStatus.CONFIRMED, now.minusHours(24), now.plusHours(PAYMENT_REMINDER_HOURS))) {
            try {
                handleUnpaid(appointment, now);
            } catch (Exception e) {
                LOGGER.warn("Vérification du paiement impossible pour le rendez-vous {}",
                        appointment.getId(), e);
            }
        }
    }

    private void cancelUnanswered(Appointment appointment, LocalDateTime now) {

        boolean paid = paymentClient.hasCompletedPayment(appointment.getId());

        appointment.setStatus(AppointmentStatus.CANCELLED);
        appointment.setCancellationReason(CancellationReason.PSYCHOLOGIST_NO_RESPONSE);
        appointment.setCancelledAt(now);
        appointmentRepository.save(appointment);

        if (paid) {
            paymentClient.refundCompletedPayments(appointment.getId(), appointment.getPatientId());
        }

        if (appointment.getStartTime().isBefore(now) && !paid) {
            return;
        }

        String when = appointment.getStartTime().format(DATE_TIME);

        notificationClient.sendAboutAppointment(
                appointment.getPatientId(),
                "Rendez-vous annulé",
                "Votre demande de rendez-vous du " + when + " a été annulée : "
                        + "le psychologue ne l'a pas confirmée à temps. "
                        + (paid
                                ? "Votre paiement vous a été intégralement remboursé sur votre solde PsyConnect. "
                                : "")
                        + "Vous pouvez réserver un autre créneau.",
                "APPOINTMENT",
                "PATIENT",
                appointment.getId()
        );

        notificationClient.sendAboutAppointment(
                appointment.getPsychologistId(),
                "Rendez-vous annulé",
                "La demande de rendez-vous du " + when + " a été annulée automatiquement, "
                        + "faute de réponse de votre part au moins 2 heures avant la séance.",
                "APPOINTMENT",
                "PSYCHOLOGIST",
                appointment.getId()
        );
    }

    private void handleUnpaid(Appointment appointment, LocalDateTime now) {

        if (paymentClient.hasCompletedPayment(appointment.getId())) {
            return;
        }

        LocalDateTime paymentDeadline =
                appointment.getStartTime().minusHours(PAYMENT_DEADLINE_HOURS);

        if (!now.isBefore(paymentDeadline)) {
            appointment.setStatus(AppointmentStatus.CANCELLED);
            appointment.setCancellationReason(CancellationReason.UNPAID);
            appointment.setCancelledAt(now);
            appointmentRepository.save(appointment);

            if (appointment.getStartTime().isBefore(now)) {
                return;
            }

            String when = appointment.getStartTime().format(DATE_TIME);

            notificationClient.sendAboutAppointment(
                    appointment.getPatientId(),
                    "Rendez-vous annulé",
                    "Votre rendez-vous du " + when + " a été annulé : "
                            + "il n'a pas été payé au moins 1 heure avant la séance.",
                    "APPOINTMENT",
                    "PATIENT",
                    appointment.getId()
            );

            notificationClient.sendAboutAppointment(
                    appointment.getPsychologistId(),
                    "Rendez-vous annulé",
                    "Le rendez-vous du " + when + " a été annulé automatiquement : "
                            + "le patient ne l'a pas payé à temps. Le créneau est libéré.",
                    "APPOINTMENT",
                    "PSYCHOLOGIST",
                    appointment.getId()
            );
            return;
        }

        if (!Boolean.TRUE.equals(appointment.getPaymentReminderSent())) {
            notificationClient.sendAboutAppointment(
                    appointment.getPatientId(),
                    "Paiement en attente",
                    "Votre rendez-vous du " + appointment.getStartTime().format(DATE_TIME)
                            + " n'est pas encore payé. Réglez-le avant "
                            + paymentDeadline.format(TIME)
                            + ", sinon il sera annulé et le créneau libéré.",
                    "PAYMENT",
                    "PATIENT",
                    appointment.getId()
            );
            appointment.setPaymentReminderSent(true);
            appointmentRepository.save(appointment);
        }
    }
}
