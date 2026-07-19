package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UpdateMedicalHistoryRequest {

    private String allergies;
    private String chronicConditions;
    private String currentTreatments;
    private String psychiatricHistory;
}
