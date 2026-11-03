package com.example.userservice.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

// lien "ce psy suit ce patient", créé depuis la fiche patient
// (bouton "Marquer comme suivi"), unique par (psyId, patientId)
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
