package com.example.userservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class MedicalHistoryResponse {

    private Long patientId;
    private String allergies;
    private String chronicConditions;
    private String currentTreatments;
    private String psychiatricHistory;
    private LocalDateTime updatedAt;
    private String lastUpdatedByRole;
}
