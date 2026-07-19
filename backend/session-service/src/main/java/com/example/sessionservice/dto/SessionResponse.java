package com.example.sessionservice.dto;

import java.time.LocalDateTime;

import com.example.sessionservice.entity.SessionStatus;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class SessionResponse {

    private Long id;
    private Long appointmentId;
    private SessionStatus status;
    private String meetingToken;
    private LocalDateTime startedAt;
    private LocalDateTime endedAt;
    private Long durationSeconds;
    private LocalDateTime createdAt;
    private Boolean emergencyMode;
    private Long emergencyPatientId;
    private Long emergencyPsychologistId;
}
