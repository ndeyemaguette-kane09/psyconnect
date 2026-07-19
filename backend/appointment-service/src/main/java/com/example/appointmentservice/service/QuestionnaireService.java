package com.example.appointmentservice.service;

import com.example.appointmentservice.dto.AnswerQuestionnaireRequest;
import com.example.appointmentservice.dto.QuestionnaireResponseDto;
import com.example.appointmentservice.dto.SendQuestionnaireRequest;

import java.util.List;

public interface QuestionnaireService {

    // PSY : envoie un questionnaire a un patient
    QuestionnaireResponseDto sendQuestionnaire(SendQuestionnaireRequest request);

    // PSY : historique des questionnaires pour un patient specifique
    List<QuestionnaireResponseDto> getPatientQuestionnaires(Long patientId);

    // Patient : questionnaires en attente de réponse
    List<QuestionnaireResponseDto> getMyPendingQuestionnaires();

    // PATIENT : tous ses questionnaires (historique complet — pending + completed)
    List<QuestionnaireResponseDto> getMyQuestionnaires();

    // Patient : soumet ses réponses
    QuestionnaireResponseDto answerQuestionnaire(Long id, AnswerQuestionnaireRequest request);
}
