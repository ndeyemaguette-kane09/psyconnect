package com.example.appointmentservice.dto;

import com.example.appointmentservice.entity.QuestionnaireType;
import jakarta.validation.constraints.NotNull;

// psy envoie un questionnaire PHQ-9 ou GAD-7 a un patient
public class SendQuestionnaireRequest {

    @NotNull
    private QuestionnaireType type;

    @NotNull
    private Long patientId;

    // optionnel : lie a un RDV specifique (ex: post-seance)
    private Long appointmentId;

    public QuestionnaireType getType() { return type; }
    public void setType(QuestionnaireType type) { this.type = type; }

    public Long getPatientId() { return patientId; }
    public void setPatientId(Long patientId) { this.patientId = patientId; }

    public Long getAppointmentId() { return appointmentId; }
    public void setAppointmentId(Long appointmentId) { this.appointmentId = appointmentId; }
}
