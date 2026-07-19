package com.example.userservice.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "psychologist_reports")
public class PsychologistReport {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // profil (pas authUserId) du patient qui signale
    @Column(nullable = false)
    private Long patientProfileId;

    // profil du psychologue signalé
    @Column(nullable = false)
    private Long psychologistProfileId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ReportReason reason;

    @Column(columnDefinition = "TEXT")
    private String description;

    // nom du fichier stocké sur disque ; null si le patient n'a pas joint de preuve
    private String evidenceFilename;

    // extension réelle du fichier (jpg, png, pdf…) pour le Content-Type au téléchargement
    private String evidenceExtension;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ReportStatus status;

    @Column(columnDefinition = "TEXT")
    private String adminNote;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @PrePersist
    private void prePersist() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (status == null) status = ReportStatus.PENDING;
    }

    @PreUpdate
    private void preUpdate() {
        updatedAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getPatientProfileId() { return patientProfileId; }
    public void setPatientProfileId(Long patientProfileId) { this.patientProfileId = patientProfileId; }

    public Long getPsychologistProfileId() { return psychologistProfileId; }
    public void setPsychologistProfileId(Long psychologistProfileId) { this.psychologistProfileId = psychologistProfileId; }

    public ReportReason getReason() { return reason; }
    public void setReason(ReportReason reason) { this.reason = reason; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getEvidenceFilename() { return evidenceFilename; }
    public void setEvidenceFilename(String evidenceFilename) { this.evidenceFilename = evidenceFilename; }

    public String getEvidenceExtension() { return evidenceExtension; }
    public void setEvidenceExtension(String evidenceExtension) { this.evidenceExtension = evidenceExtension; }

    public ReportStatus getStatus() { return status; }
    public void setStatus(ReportStatus status) { this.status = status; }

    public String getAdminNote() { return adminNote; }
    public void setAdminNote(String adminNote) { this.adminNote = adminNote; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
