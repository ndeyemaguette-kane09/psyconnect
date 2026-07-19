package com.example.sessionservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

/**
 * Sous-ensemble des champs d'Appointment retournés par appointment-service.
 * Utilisé par AppointmentClient pour valider le RDV avant de créer/terminer une session.
 */
@Getter
@Setter
public class AppointmentDto {

    private Long id;
    private Long patientId;
    private Long psychologistId;
    private String status;            // PENDING, CONFIRMED, COMPLETED, CANCELLED…
    private String consultationType;  // VIDEO, AUDIO, IN_PERSON
    private LocalDateTime startTime;
    private LocalDateTime endTime;
}
