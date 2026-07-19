package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class CreateOrUpdateClinicalNoteRequest {

    private String content;

    // optionnel : rattache la note a une seance precise
    private Long appointmentId;
}
