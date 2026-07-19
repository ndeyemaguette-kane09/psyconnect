package com.example.appointmentservice.dto;

import jakarta.validation.constraints.NotNull;
import java.util.List;

// patient soumet ses reponses : liste d'entiers 0-3
// PHQ-9 : exactement 9 valeurs ; GAD-7 : exactement 7 valeurs
// la validation du compte est faite dans QuestionnaireServiceImpl
public class AnswerQuestionnaireRequest {

    @NotNull
    private List<Integer> answers;

    public List<Integer> getAnswers() { return answers; }
    public void setAnswers(List<Integer> answers) { this.answers = answers; }
}
