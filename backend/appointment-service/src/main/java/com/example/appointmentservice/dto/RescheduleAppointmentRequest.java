package com.example.appointmentservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;
import jakarta.validation.constraints.NotNull;

// body de PUT /appointments/{id}/reschedule, nouveau creneau propose par le patient
@Getter
@Setter
public class RescheduleAppointmentRequest {

    @NotNull(message = "La nouvelle date de début est obligatoire")
    private LocalDateTime newStartTime;

    @NotNull(message = "La nouvelle date de fin est obligatoire")
    private LocalDateTime newEndTime;
}
