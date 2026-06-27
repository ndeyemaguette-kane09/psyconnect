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

    /** Aperçu du dernier message (null si la conversation n'a encore aucun message). */
    private String lastMessagePreview;

    /** Nombre de messages non lus envoyés par l'autre participant. */
    private long unreadCount;
}
