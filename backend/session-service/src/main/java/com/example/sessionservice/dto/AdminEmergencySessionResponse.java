package com.example.sessionservice.dto;

import java.time.LocalDateTime;

import com.example.sessionservice.entity.SessionStatus;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AdminEmergencySessionResponse {

    private Long id;
    private Long psychologistId;
    private SessionStatus status;
    private LocalDateTime requestedAt;
    private LocalDateTime answeredAt;
    private LocalDateTime endedAt;
    private Long durationSeconds;
    private Boolean declinedByPsychologist;
}
