package com.example.userservice.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import java.time.LocalDateTime;

public class ReportResponse {

    private Long id;
    private Long patientProfileId;
    private Long psychologistProfileId;
    private String reason;       // enum name : PRIX_ABUSIF, …
    private String reasonLabel;  // libellé lisible : "Tarif abusif", …
    private String description;
    private boolean hasEvidence; // true si un fichier a été joint
    private String status;
    private String adminNote;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime updatedAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getPatientProfileId() { return patientProfileId; }
    public void setPatientProfileId(Long patientProfileId) { this.patientProfileId = patientProfileId; }

    public Long getPsychologistProfileId() { return psychologistProfileId; }
    public void setPsychologistProfileId(Long psychologistProfileId) { this.psychologistProfileId = psychologistProfileId; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getReasonLabel() { return reasonLabel; }
    public void setReasonLabel(String reasonLabel) { this.reasonLabel = reasonLabel; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public boolean isHasEvidence() { return hasEvidence; }
    public void setHasEvidence(boolean hasEvidence) { this.hasEvidence = hasEvidence; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getAdminNote() { return adminNote; }
    public void setAdminNote(String adminNote) { this.adminNote = adminNote; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
