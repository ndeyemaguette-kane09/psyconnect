package com.example.appointmentservice.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

// questionnaire standardise PHQ-9 (depression) ou GAD-7 (anxiete)
// envoye par le psy, rempli par le patient
//
// les reponses sont stockees sous forme de chaine separee par virgules
// ex: "1,2,0,3,2,1,0,2,1" pour PHQ-9 (9 valeurs 0-3)
// le score est calcule automatiquement a la soumission
@Entity
@Table(name = "questionnaires")
public class Questionnaire {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private QuestionnaireType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private QuestionnaireStatus status = QuestionnaireStatus.SENT;

    @Column(nullable = false)
    private Long psychologistId;

    @Column(nullable = false)
    private Long patientId;

    // optionnel : lie a un RDV specifique
    private Long appointmentId;

    // Réponses une fois remplies : "0,1,2,3,0,1,2,0,1" (null si SENT)
    @Column(columnDefinition = "TEXT")
    private String answers;

    // score total (null si SENT, calcule lors de la soumission)
    private Integer score;

    @Column(updatable = false)
    private LocalDateTime sentAt;

    private LocalDateTime completedAt;

    @PrePersist
    protected void onCreate() {
        this.sentAt = LocalDateTime.now();
    }

    public Questionnaire() {
    }

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

    public String getAnswers() { return answers; }
    public void setAnswers(String answers) { this.answers = answers; }

    public Integer getScore() { return score; }
    public void setScore(Integer score) { this.score = score; }

    public LocalDateTime getSentAt() { return sentAt; }
    public void setSentAt(LocalDateTime sentAt) { this.sentAt = sentAt; }

    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }
}
