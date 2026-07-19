package com.example.paymentservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

// Version allégée de AppointmentResponse (côté appointment-service), juste
// ce dont payment-service a besoin pour valider/rembourser un paiement
@Getter
@Setter
public class AppointmentSummary {

    private Long id;
    private Long patientId;
    private Long psychologistId;
    private String status;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
}
