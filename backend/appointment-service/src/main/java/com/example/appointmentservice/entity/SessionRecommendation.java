package com.example.appointmentservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

// tache ou conseil ecrit par le psy apres une seance (COMPLETED),
// visible par le patient sur son accueil. le patient peut la cocher
// une fois accomplie. jamais visible par un autre psy ou par l'admin
@Entity
@Table(name = "session_recommendations")
@Getter
@Setter
public class SessionRecommendation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ref cross-service vers l'appointment correspondant
    @Column(nullable = false)
    private Long appointmentId;

    // profil (pas authUser) du psy auteur
    @Column(nullable = false)
    private Long psychologistId;

    // profil (pas authUser) du patient destinataire
    @Column(nullable = false)
    private Long patientId;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    // le patient coche quand il a realise la tache
    @Column(nullable = false)
    private boolean completed = false;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public SessionRecommendation() {
    }
}
