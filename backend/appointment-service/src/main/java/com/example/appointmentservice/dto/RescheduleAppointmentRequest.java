package com.example.appointmentservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;
import jakarta.validation.constraints.NotNull;

/** Corps de PUT /appointments/{id}/reschedule — nouveau créneau proposé par le patient. */
@Getter
@Setter
public class RescheduleAppointmentRequest {

    @NotNull(message = "La nouvelle date de début est obligatoire")
    private LocalDateTime newStartTime;

    @NotNull(message = "La nouvelle date de fin est obligatoire")
    private LocalDateTime newEndTime;
}
