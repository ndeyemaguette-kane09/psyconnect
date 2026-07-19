package com.example.appointmentservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

// fil de discussion entre un patient et un psy, une seule par paire
@Entity
@Table(
        name = "conversations",
        uniqueConstraints = @UniqueConstraint(columnNames = {"patientId", "psychologistId"})
)
@Getter
@Setter
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long patientId;

    @Column(nullable = false)
    private Long psychologistId;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    // date du dernier message, pour trier les conversations
    @Column(nullable = false)
    private LocalDateTime lastMessageAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.lastMessageAt = this.createdAt;
    }

    public Conversation() {
    }
}
