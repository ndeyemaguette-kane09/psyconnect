package com.example.appointmentservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * Un message dans une {@link Conversation}. {@code senderAuthUserId} est
 * l'authUserId du JWT (pas patientId/psychologistId) : ça permet de savoir
 * "ce message est-il de moi ?" par simple comparaison, sans avoir besoin de
 * connaître le rôle de l'auteur ni de résoudre son profil métier.
 */
@Entity
@Table(name = "messages")
@Getter
@Setter
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long conversationId;

    @Column(nullable = false)
    private Long senderAuthUserId;

    @Column(nullable = false, length = 2000)
    private String content;

    @Column(nullable = false)
    private LocalDateTime sentAt;

    /** Null tant que le destinataire n'a pas ouvert/marqué la conversation comme lue. */
    private LocalDateTime readAt;

    @PrePersist
    protected void onCreate() {
        this.sentAt = LocalDateTime.now();
    }

    public Message() {
    }
}
