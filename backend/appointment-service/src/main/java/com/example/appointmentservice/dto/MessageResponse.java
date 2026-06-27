package com.example.appointmentservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class MessageResponse {

    private Long id;
    private Long conversationId;

    /** authUserId de l'auteur — le client compare avec son propre authUserId pour aligner la bulle à gauche/droite. */
    private Long senderAuthUserId;

    private String content;
    private LocalDateTime sentAt;
    private LocalDateTime readAt;
}
