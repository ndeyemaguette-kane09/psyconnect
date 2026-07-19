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

// Note clinique privée rédigée par un psychologue sur un patient qu'il suit
// (cf. CDC section 4.2 "Notes cliniques privées : espace personnel pour les
// notes post-séance"). Contrairement à MedicalHistory (collaboratif
// patient+psy), une note ici n'est JAMAIS visible par le patient, ni par
// l'admin, ni par un autre psychologue même s'il suit le même patient
// (CDC section 6 : "jamais visibles par des tiers non autorisés") —
// le contrôle d'accès est fait dans ClinicalNoteServiceImpl, jamais exposé
// via un endpoint public pour le patient
@Entity
@Getter
@Setter
@Table(name = "clinical_notes")
public class ClinicalNote {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long patientProfileId;

    // Auteur de la note — seul ce psychologue pourra jamais la lire/modifier/
    // supprimer ; même un confrère ayant suivi ce patient ne la verra pas
    @Column(nullable = false)
    private Long psychologistProfileId;

    // Rendez-vous concerné, optionnel : une note peut être prise "à froid"
    // sans être rattachée à une séance précise (id appointment-service, pas
    // de FK inter-service — simple référence comme ailleurs dans le projet)
    private Long appointmentId;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

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

    public ClinicalNote() {
    }
}
