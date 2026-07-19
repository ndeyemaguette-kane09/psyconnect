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
import lombok.Getter;
import lombok.Setter;

// Antécédents médicaux structurés, distincts du champ libre PatientProfile.medicalHistory
// (conservé pour compatibilité mais plus utilisé par le nouvel écran). Modifiable par
// le patient ET par un psychologue qui le suit (vérifié via PsyPatientLink),
// jamais par l'admin
@Entity
@Getter
@Setter
@Table(name = "medical_histories")
public class MedicalHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private Long patientProfileId;

    @Column(columnDefinition = "TEXT")
    private String allergies;

    @Column(columnDefinition = "TEXT")
    private String chronicConditions;

    @Column(columnDefinition = "TEXT")
    private String currentTreatments;

    @Column(columnDefinition = "TEXT")
    private String psychiatricHistory;

    private LocalDateTime updatedAt;

    // "PATIENT" ou "PSYCHOLOGIST" : qui a fait la dernière modification —
    // utile car la fiche est collaborative entre les deux
    private String lastUpdatedByRole;

    @PrePersist
    @PreUpdate
    protected void onSave() {
        this.updatedAt = LocalDateTime.now();
    }

    public MedicalHistory() {
    }
}
