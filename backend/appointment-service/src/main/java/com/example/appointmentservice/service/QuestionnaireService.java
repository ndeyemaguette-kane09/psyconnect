package com.example.appointmentservice.service;

import com.example.appointmentservice.dto.AnswerQuestionnaireRequest;
import com.example.appointmentservice.dto.QuestionnaireResponseDto;
import com.example.appointmentservice.dto.SendQuestionnaireRequest;

import java.util.List;

public interface QuestionnaireService {

   
    QuestionnaireResponseDto sendQuestionnaire(SendQuestionnaireRequest request);

    
    List<QuestionnaireResponseDto> getPatientQuestionnaires(Long patientId);

    
    List<QuestionnaireResponseDto> getMyPendingQuestionnaires();

    
    List<QuestionnaireResponseDto> getMyQuestionnaires();

    QuestionnaireResponseDto answerQuestionnaire(Long id, AnswerQuestionnaireRequest request);
}
