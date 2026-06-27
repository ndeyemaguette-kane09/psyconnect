package com.example.appointmentservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * Fil de discussion entre UN patient et UN psychologue. Une seule
 * conversation par paire (patientId, psychologistId) — cf. contrainte
 * d'unicité ci-dessous et {@code findByPatientIdAndPsychologistId} dans
 * {@link com.example.appointmentservice.repository.ConversationRepository}.
 */
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

    /**
     * Horodatage du dernier message envoyé (ou de la création si aucun
     * message encore) — sert uniquement à trier la liste des conversations
     * par activité récente, cf. ConversationRepository.
     */
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
