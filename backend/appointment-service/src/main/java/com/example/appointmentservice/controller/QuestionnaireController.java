package com.example.appointmentservice.controller;

import com.example.appointmentservice.dto.AnswerQuestionnaireRequest;
import com.example.appointmentservice.dto.QuestionnaireResponseDto;
import com.example.appointmentservice.dto.SendQuestionnaireRequest;
import com.example.appointmentservice.service.QuestionnaireService;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/questionnaires")
public class QuestionnaireController {

    private final QuestionnaireService questionnaireService;

    public QuestionnaireController(QuestionnaireService questionnaireService) {
        this.questionnaireService = questionnaireService;
    }

    @PostMapping
    public ResponseEntity<QuestionnaireResponseDto> sendQuestionnaire(
            @RequestBody @Valid SendQuestionnaireRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(questionnaireService.sendQuestionnaire(request));
    }

    @GetMapping("/patient/me/pending")
    public ResponseEntity<List<QuestionnaireResponseDto>> getMyPending() {
        return ResponseEntity.ok(questionnaireService.getMyPendingQuestionnaires());
    }

    @GetMapping("/patient/me")
    public ResponseEntity<List<QuestionnaireResponseDto>> getMyAll() {
        return ResponseEntity.ok(questionnaireService.getMyQuestionnaires());
    }

    @GetMapping("/patient/{patientId}")
    public ResponseEntity<List<QuestionnaireResponseDto>> getPatientQuestionnaires(
            @PathVariable Long patientId
    ) {
        return ResponseEntity.ok(
                questionnaireService.getPatientQuestionnaires(patientId)
        );
    }

    @PostMapping("/{id}/answers")
    public ResponseEntity<QuestionnaireResponseDto> answerQuestionnaire(
            @PathVariable Long id,
            @RequestBody @Valid AnswerQuestionnaireRequest request
    ) {
        return ResponseEntity.ok(
                questionnaireService.answerQuestionnaire(id, request)
        );
    }
}
