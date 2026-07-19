package com.example.appointmentservice.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.util.Collections;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

import com.example.appointmentservice.dto.AnswerQuestionnaireRequest;
import com.example.appointmentservice.dto.QuestionnaireResponseDto;
import com.example.appointmentservice.entity.Questionnaire;
import com.example.appointmentservice.entity.QuestionnaireStatus;
import com.example.appointmentservice.entity.QuestionnaireType;
import com.example.appointmentservice.repository.QuestionnaireRepository;
import com.example.appointmentservice.service.OwnershipResolver;

/**
 * Tests unitaires pour le scoring PHQ-9 et GAD-7.
 *
 * PHQ-9 (dépression) : 9 questions × 0-3 → score 0-27
 *   0-4 minimal | 5-9 léger | 10-14 modéré | 15-19 modérément sévère | 20-27 sévère
 *
 * GAD-7 (anxiété) : 7 questions × 0-3 → score 0-21
 *   0-4 minimal | 5-9 léger | 10-14 modéré | 15-21 sévère
 */
@ExtendWith(MockitoExtension.class)
class QuestionnaireServiceImplTest {

    @Mock QuestionnaireRepository questionnaireRepository;
    @Mock OwnershipResolver       ownershipResolver;

    @InjectMocks QuestionnaireServiceImpl service;

    private static final Long PATIENT_ID = 1L;

    @BeforeEach
    void authenticateAsPatient() {
        var auth = new UsernamePasswordAuthenticationToken(
                String.valueOf(PATIENT_ID),
                null,
                List.of(new SimpleGrantedAuthority("ROLE_PATIENT"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    // --- Helpers ---

    /**
     * Crée un questionnaire fictif à l'état SENT pour le patient.
     */
    private Questionnaire buildQuestionnaire(QuestionnaireType type) {
        Questionnaire q = new Questionnaire();
        q.setId(1L);
        q.setType(type);
        q.setPatientId(PATIENT_ID);
        q.setPsychologistId(2L);
        q.setStatus(QuestionnaireStatus.SENT);
        return q;
    }

    /**
     * Appelle answerQuestionnaire() avec les réponses données et renvoie le DTO.
     */
    private QuestionnaireResponseDto answer(QuestionnaireType type, List<Integer> answers) {
        Questionnaire q = buildQuestionnaire(type);

        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(questionnaireRepository.findByIdAndPatientId(1L, PATIENT_ID))
                .thenReturn(Optional.of(q));
        // save renvoie l'objet modifié tel quel
        when(questionnaireRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        AnswerQuestionnaireRequest req = new AnswerQuestionnaireRequest();
        req.setAnswers(answers);

        return service.answerQuestionnaire(1L, req);
    }

    // ── PHQ-9 ──────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("PHQ-9 score 27 (9×3) → Dépression sévère")
    void phq9_allMax_isSevereDepression() {
        // 9 réponses à 3 → score max 27
        List<Integer> answers = Collections.nCopies(9, 3);
        QuestionnaireResponseDto resp = answer(QuestionnaireType.PHQ9, answers);

        assertEquals(27, resp.getScore());
        assertEquals("Dépression sévère", resp.getSeverity());
        assertEquals(QuestionnaireStatus.COMPLETED, resp.getStatus());
    }

    @Test
    @DisplayName("PHQ-9 score 0 → Dépression minimale")
    void phq9_allZero_isMinimalDepression() {
        List<Integer> answers = Collections.nCopies(9, 0);
        QuestionnaireResponseDto resp = answer(QuestionnaireType.PHQ9, answers);

        assertEquals(0, resp.getScore());
        assertEquals("Dépression minimale", resp.getSeverity());
    }

    @Test
    @DisplayName("PHQ-9 score 10 → Dépression modérée")
    void phq9_score10_isModerateDepression() {
        // 9 réponses dont certaines à 1 et certaines à 2 pour totaliser 10
        // ex: 1+2+1+2+1+1+1+0+1 = 10
        List<Integer> answers = List.of(1, 2, 1, 2, 1, 1, 1, 0, 1);
        QuestionnaireResponseDto resp = answer(QuestionnaireType.PHQ9, answers);

        assertEquals(10, resp.getScore());
        assertEquals("Dépression modérée", resp.getSeverity());
    }

    @Test
    @DisplayName("PHQ-9 avec 8 réponses au lieu de 9 → IllegalArgumentException")
    void phq9_wrongAnswerCount_throwsException() {
        Questionnaire q = buildQuestionnaire(QuestionnaireType.PHQ9);
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(questionnaireRepository.findByIdAndPatientId(1L, PATIENT_ID))
                .thenReturn(Optional.of(q));

        AnswerQuestionnaireRequest req = new AnswerQuestionnaireRequest();
        req.setAnswers(Collections.nCopies(8, 1)); // 8 au lieu de 9

        assertThrows(IllegalArgumentException.class,
                () -> service.answerQuestionnaire(1L, req));
    }

    @Test
    @DisplayName("PHQ-9 avec une réponse = 4 (hors plage 0-3) → IllegalArgumentException")
    void phq9_invalidAnswerValue_throwsException() {
        Questionnaire q = buildQuestionnaire(QuestionnaireType.PHQ9);
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(questionnaireRepository.findByIdAndPatientId(1L, PATIENT_ID))
                .thenReturn(Optional.of(q));

        AnswerQuestionnaireRequest req = new AnswerQuestionnaireRequest();
        req.setAnswers(List.of(1, 2, 4, 0, 1, 2, 1, 0, 1)); // 4 est invalide

        assertThrows(IllegalArgumentException.class,
                () -> service.answerQuestionnaire(1L, req));
    }

    // ── GAD-7 ──────────────────────────────────────────────────────────────────

    @Test
    @DisplayName("GAD-7 score 21 (7×3) → Anxiété sévère")
    void gad7_allMax_isSevereAnxiety() {
        List<Integer> answers = Collections.nCopies(7, 3);
        QuestionnaireResponseDto resp = answer(QuestionnaireType.GAD7, answers);

        assertEquals(21, resp.getScore());
        assertEquals("Anxiété sévère", resp.getSeverity());
    }

    @Test
    @DisplayName("GAD-7 score 7 → Anxiété légère")
    void gad7_score7_isMildAnxiety() {
        // 7 réponses à 1 → score 7
        List<Integer> answers = Collections.nCopies(7, 1);
        QuestionnaireResponseDto resp = answer(QuestionnaireType.GAD7, answers);

        assertEquals(7, resp.getScore());
        assertEquals("Anxiété légère", resp.getSeverity());
    }

    @Test
    @DisplayName("GAD-7 score 12 → Anxiété modérée")
    void gad7_score12_isModerateAnxiety() {
        // ex: 2+2+2+2+1+1+2 = 12
        List<Integer> answers = List.of(2, 2, 2, 2, 1, 1, 2);
        QuestionnaireResponseDto resp = answer(QuestionnaireType.GAD7, answers);

        assertEquals(12, resp.getScore());
        assertEquals("Anxiété modérée", resp.getSeverity());
    }

    @Test
    @DisplayName("GAD-7 avec 9 réponses au lieu de 7 → IllegalArgumentException")
    void gad7_wrongAnswerCount_throwsException() {
        Questionnaire q = buildQuestionnaire(QuestionnaireType.GAD7);
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(questionnaireRepository.findByIdAndPatientId(1L, PATIENT_ID))
                .thenReturn(Optional.of(q));

        AnswerQuestionnaireRequest req = new AnswerQuestionnaireRequest();
        req.setAnswers(Collections.nCopies(9, 1)); // 9 au lieu de 7

        assertThrows(IllegalArgumentException.class,
                () -> service.answerQuestionnaire(1L, req));
    }

    // ── Règle métier : questionnaire déjà complété ─────────────────────────────

    @Test
    @DisplayName("Répondre à un questionnaire déjà COMPLETED → ForbiddenOperationException")
    void answerQuestionnaire_alreadyCompleted_throwsForbidden() {
        Questionnaire q = buildQuestionnaire(QuestionnaireType.PHQ9);
        q.setStatus(QuestionnaireStatus.COMPLETED); // déjà rempli

        when(ownershipResolver.resolveOwnPatientId()).thenReturn(PATIENT_ID);
        when(questionnaireRepository.findByIdAndPatientId(1L, PATIENT_ID))
                .thenReturn(Optional.of(q));

        AnswerQuestionnaireRequest req = new AnswerQuestionnaireRequest();
        req.setAnswers(Collections.nCopies(9, 1));

        assertThrows(
                com.example.appointmentservice.exception.ForbiddenOperationException.class,
                () -> service.answerQuestionnaire(1L, req)
        );
    }
}
