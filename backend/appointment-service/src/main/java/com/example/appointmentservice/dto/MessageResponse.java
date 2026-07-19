package com.example.appointmentservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class MessageResponse {

    private Long id;
    private Long conversationId;

    // id de qui a envoyé, pour savoir si la bulle va a gauche ou a droite
    private Long senderAuthUserId;

    private String content;
    private LocalDateTime sentAt;
    private LocalDateTime readAt;
}
