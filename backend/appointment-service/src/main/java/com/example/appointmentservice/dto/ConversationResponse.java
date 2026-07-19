package com.example.appointmentservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ConversationResponse {

    private Long id;
    private Long patientId;
    private Long psychologistId;
    private LocalDateTime createdAt;
    private LocalDateTime lastMessageAt;

    // apercu du dernier message, null si aucun message encore
    private String lastMessagePreview;

    // nb de messages non lus envoyés par l'autre
    private long unreadCount;
}
