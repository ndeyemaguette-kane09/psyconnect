package com.example.appointmentservice.dto;

import com.example.appointmentservice.entity.QuestionnaireStatus;
import com.example.appointmentservice.entity.QuestionnaireType;

import java.time.LocalDateTime;
import java.util.List;

// DTO de réponse pour un questionnaire (renommé QuestionnaireResponseDto
// pour eviter la collision avec QuestionnaireResponse qui est une classe
// standard de Spring)
public class QuestionnaireResponseDto {

    private Long id;
    private QuestionnaireType type;        // PHQ9 ou GAD7
    private QuestionnaireStatus status;    // SENT ou COMPLETED
    private Long psychologistId;
    private Long patientId;
    private Long appointmentId;
    private List<Integer> answers;         // null si SENT
    private Integer score;                 // null si SENT
    private String severity;              // interpretation du score (null si SENT)
    private LocalDateTime sentAt;
    private LocalDateTime completedAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public QuestionnaireType getType() { return type; }
    public void setType(QuestionnaireType type) { this.type = type; }

    public QuestionnaireStatus getStatus() { return status; }
    public void setStatus(QuestionnaireStatus status) { this.status = status; }

    public Long getPsychologistId() { return psychologistId; }
    public void setPsychologistId(Long psychologistId) { this.psychologistId = psychologistId; }

    public Long getPatientId() { return patientId; }
    public void setPatientId(Long patientId) { this.patientId = patientId; }

    public Long getAppointmentId() { return appointmentId; }
    public void setAppointmentId(Long appointmentId) { this.appointmentId = appointmentId; }

    public List<Integer> getAnswers() { return answers; }
    public void setAnswers(List<Integer> answers) { this.answers = answers; }

    public Integer getScore() { return score; }
    public void setScore(Integer score) { this.score = score; }

    public String getSeverity() { return severity; }
    public void setSeverity(String severity) { this.severity = severity; }

    public LocalDateTime getSentAt() { return sentAt; }
    public void setSentAt(LocalDateTime sentAt) { this.sentAt = sentAt; }

    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }
}
