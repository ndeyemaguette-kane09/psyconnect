package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

// Version allégée de AppointmentResponse (côté appointment-service), juste
// ce dont user-service a besoin pour vérifier qu'un psychologue a déjà eu un rendez-vous
// avec un patient donné (accès aux antécédents médicaux)
@Getter
@Setter
public class AppointmentSummary {

    private Long id;
    private Long patientId;
    private Long psychologistId;
    private String status;
}
