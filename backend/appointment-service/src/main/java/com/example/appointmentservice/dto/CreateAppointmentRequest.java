package com.example.appointmentservice.dto;

import java.time.LocalDateTime;

import com.example.appointmentservice.entity.ConsultationType;

import lombok.Getter;
import lombok.Setter;
import jakarta.validation.constraints.NotNull;

@Getter
@Setter
public class CreateAppointmentRequest {

    @NotNull(message = "Patient id is required")
    private Long patientId;

    @NotNull(message = "Psychologist id is required")
    private Long psychologistId;

    @NotNull(message = "Start time is required")
    private LocalDateTime startTime;

    @NotNull(message = "End time is required")
    private LocalDateTime endTime;

    @NotNull(message = "Consultation type is required")
    private ConsultationType consultationType;
}
