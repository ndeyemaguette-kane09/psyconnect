package com.example.sessionservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "sessions")
@Getter
@Setter
public class Session {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // null pour les sessions d'urgence (pas de RDV associé)
    private Long appointmentId;

    // session démarrée depuis le bouton SOS du patient, sans RDV préalable
    @Column(nullable = false, columnDefinition = "boolean default false")
    private Boolean emergencyMode = false;

    // IDs des profils psy et patient pour les sessions urgence (null si non-urgence)
    private Long emergencyPatientId;
    private Long emergencyPsychologistId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SessionStatus status;

    // nom de room Jitsi : psyconnect-{appointmentId}-{uuid8}
    @Column(nullable = false, unique = true)
    private String meetingToken;

    private LocalDateTime startedAt;
    private LocalDateTime endedAt;
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    public Session() {
    }
}
