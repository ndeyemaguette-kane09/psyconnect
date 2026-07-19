package com.example.userservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ClinicalNoteResponse {

    private Long id;
    private Long patientProfileId;
    private Long appointmentId;
    private String content;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
