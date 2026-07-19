package com.example.appointmentservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class RecommendationResponse {

    private Long id;
    private Long appointmentId;
    private Long psychologistId;
    private Long patientId;
    private String content;
    private boolean completed;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
