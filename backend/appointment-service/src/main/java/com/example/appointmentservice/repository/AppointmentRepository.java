package com.example.appointmentservice.repository;

import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface AppointmentRepository
        extends JpaRepository<Appointment, Long> {


            boolean existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThan(
        Long psychologistId,
        LocalDateTime endTime,
        LocalDateTime startTime
);

/**
 * Variante utilisée par le report de rendez-vous (reschedule) : exclut le
 * rendez-vous en cours de modification du contrôle de conflit, sinon il se
 * bloquerait toujours lui-même sur son propre ancien créneau.
 */
boolean existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndIdNot(
        Long psychologistId,
        LocalDateTime endTime,
        LocalDateTime startTime,
        Long excludedId
);

List<Appointment> findByPsychologistId(Long psychologistId);

List<Appointment> findByPatientId(Long patientId);

List<Appointment> findByStatus(AppointmentStatus status);

long countByStatus(AppointmentStatus status);

/**
 * Utilisé par MessagingServiceImpl : une conversation ne peut être ouverte
 * qu'entre un patient et un psychologue ayant déjà au moins un rendez-vous
 * ensemble (peu importe son statut — même un rendez-vous PENDING ou
 * CANCELLED atteste d'une mise en relation légitime).
 */
boolean existsByPatientIdAndPsychologistId(Long patientId, Long psychologistId);

/**
 * Utilisé par AppointmentReminderScheduler : sélectionne les rendez-vous
 * confirmés dont le créneau de rappel (1h avant le début) vient d'être
 * atteint et qui n'ont pas déjà été notifiés, pour éviter les doublons à
 * chaque passage du job planifié.
 */
List<Appointment> findByStatusAndStartTimeBetweenAndReminderSentFalse(
        AppointmentStatus status,
        LocalDateTime from,
        LocalDateTime to
);
}