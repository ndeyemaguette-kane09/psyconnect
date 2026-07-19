package com.example.userservice.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

// Avis d'un patient sur un psychologue. Un seul avis par couple
// patient-psychologue (modifiable après chaque nouvelle séance), uniquement
// si le patient a déjà eu un rendez-vous TERMINÉ avec ce psychologue (vérifié via
// AppointmentClient, cf. ReviewServiceImpl). Toujours anonyme : aucune
// référence au patient n'est jamais exposée (ni au psychologue, ni en public).
@Entity
@Getter
@Setter
@Table(
        name = "reviews",
        uniqueConstraints = @UniqueConstraint(
                columnNames = {"patientProfileId", "psychologistProfileId"}
        )
)
public class Review {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long patientProfileId;

    @Column(nullable = false)
    private Long psychologistProfileId;

    // Note de 1 à 5, validée côté service
    @Column(nullable = false)
    private Integer rating;

    @Column(columnDefinition = "TEXT")
    private String comment;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = this.createdAt;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public Review() {
    }
}
