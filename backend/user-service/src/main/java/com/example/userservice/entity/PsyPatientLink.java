package com.example.userservice.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

// lien explicite "ce psychologue suit ce patient".
// créé par le psy depuis la fiche du patient (bouton "Marquer comme suivi").
// remplace le contrôle appointment-service dans les notes cliniques :
// plus de dépendance réseau inter-service pour vérifier la relation.
//
// unicité (psyId, patientId) garantie par la contrainte DB.
@Entity
@Table(
    name = "psy_patient_links",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_psy_patient_link",
        columnNames = {"psychologist_profile_id", "patient_profile_id"}
    )
)
public class PsyPatientLink {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "psychologist_profile_id", nullable = false)
    private Long psychologistProfileId;

    @Column(name = "patient_profile_id", nullable = false)
    private Long patientProfileId;

    @Column(updatable = false)
    private LocalDateTime linkedAt;

    @PrePersist
    protected void onCreate() {
        this.linkedAt = LocalDateTime.now();
    }

    public PsyPatientLink() {}

    public Long getId() { return id; }

    public Long getPsychologistProfileId() { return psychologistProfileId; }
    public void setPsychologistProfileId(Long psychologistProfileId) {
        this.psychologistProfileId = psychologistProfileId;
    }

    public Long getPatientProfileId() { return patientProfileId; }
    public void setPatientProfileId(Long patientProfileId) {
        this.patientProfileId = patientProfileId;
    }

    public LocalDateTime getLinkedAt() { return linkedAt; }
}
