package com.example.appointmentservice.repository;

import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface AppointmentRepository
        extends JpaRepository<Appointment, Long> {


    // Conflit psy : créneau chevauche un RDV actif (PENDING ou CONFIRMED)
    boolean existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
            Long psychologistId,
            LocalDateTime endTime,
            LocalDateTime startTime,
            java.util.Collection<AppointmentStatus> statuses
    );

    // Conflit patient : même logique, côté patient
    boolean existsByPatientIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusIn(
            Long patientId,
            LocalDateTime endTime,
            LocalDateTime startTime,
            java.util.Collection<AppointmentStatus> statuses
    );

    // Reschedule psy : exclure le RDV en cours de modification
    boolean existsByPsychologistIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusInAndIdNot(
            Long psychologistId,
            LocalDateTime endTime,
            LocalDateTime startTime,
            java.util.Collection<AppointmentStatus> statuses,
            Long excludedId
    );

    // Reschedule patient : idem côté patient
    boolean existsByPatientIdAndStartTimeLessThanAndEndTimeGreaterThanAndStatusInAndIdNot(
            Long patientId,
            LocalDateTime endTime,
            LocalDateTime startTime,
            java.util.Collection<AppointmentStatus> statuses,
            Long excludedId
    );

List<Appointment> findByPsychologistId(Long psychologistId);

List<Appointment> findByPatientId(Long patientId);

List<Appointment> findByStatus(AppointmentStatus status);

long countByStatus(AppointmentStatus status);

// Conversation possible uniquement si patient et psychologue ont déjà un rendez-vous ensemble
boolean existsByPatientIdAndPsychologistId(Long patientId, Long psychologistId);

// avis patient : uniquement apres une seance COMPLETED
boolean existsByPatientIdAndPsychologistIdAndStatus(
        Long patientId, Long psychologistId, AppointmentStatus status);

boolean existsByPatientIdAndPsychologistIdAndStatusIn(
        Long patientId, Long psychologistId, java.util.Collection<AppointmentStatus> statuses);

// pour le rappel : RDV confirmés dans l'heure et pas encore notifiés
List<Appointment> findByStatusAndStartTimeBetweenAndReminderSentFalse(
        AppointmentStatus status,
        LocalDateTime from,
        LocalDateTime to
);
}