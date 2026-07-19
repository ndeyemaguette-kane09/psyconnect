package com.example.appointmentservice.dto;

import java.time.LocalDateTime;

import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.ConsultationType;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AppointmentResponse {

    private Long id;
    private Long patientId;
    private Long psychologistId;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private ConsultationType consultationType;
    private AppointmentStatus status;

    // Date de création, inchangée même si le rendez-vous est reporté
    private LocalDateTime createdAt;
}
