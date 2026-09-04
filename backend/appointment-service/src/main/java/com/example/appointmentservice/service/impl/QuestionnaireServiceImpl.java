package com.example.appointmentservice.service.impl;

import com.example.appointmentservice.client.NotificationClient;
import com.example.appointmentservice.dto.AnswerQuestionnaireRequest;
import com.example.appointmentservice.dto.QuestionnaireResponseDto;
import com.example.appointmentservice.dto.SendQuestionnaireRequest;
import com.example.appointmentservice.entity.Questionnaire;
import com.example.appointmentservice.entity.QuestionnaireStatus;
import com.example.appointmentservice.entity.QuestionnaireType;
import com.example.appointmentservice.exception.ForbiddenOperationException;
import com.example.appointmentservice.exception.ResourceNotFoundException;
import com.example.appointmentservice.repository.QuestionnaireRepository;
import com.example.appointmentservice.security.SecurityUtils;
import com.example.appointmentservice.service.OwnershipResolver;
import com.example.appointmentservice.service.QuestionnaireService;

import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class QuestionnaireServiceImpl implements QuestionnaireService {

    private final QuestionnaireRepository questionnaireRepository;
    private final OwnershipResolver ownershipResolver;
    private final NotificationClient notificationClient;

    public QuestionnaireServiceImpl(
            QuestionnaireRepository questionnaireRepository,
            OwnershipResolver ownershipResolver,
            NotificationClient notificationClient
    ) {
        this.questionnaireRepository = questionnaireRepository;
        this.ownershipResolver = ownershipResolver;
        this.notificationClient = notificationClient;
    }

    @Override
    public QuestionnaireResponseDto sendQuestionnaire(SendQuestionnaireRequest request) {
        if (!SecurityUtils.hasRole("PSYCHOLOGIST")) {
            throw new ForbiddenOperationException(
                    "Seul un psychologue peut envoyer des questionnaires"
            );
        }

        Long psyId = ownershipResolver.resolveOwnPsychologistId();

        Questionnaire q = new Questionnaire();
        q.setType(request.getType());
        q.setPsychologistId(psyId);
        q.setPatientId(request.getPatientId());
        q.setAppointmentId(request.getAppointmentId());

        QuestionnaireResponseDto saved = mapToResponse(questionnaireRepository.save(q));

        String typeName = q.getType() == QuestionnaireType.PHQ9 ? "PHQ-9 (dépression)" : "GAD-7 (anxiété)";
        try {
            notificationClient.send(
                    q.getPatientId(),
                    "Nouveau questionnaire",
                    psychologistLabel(psyId) + " vous a envoyé un questionnaire " + typeName
                            + ". Répondez dès que possible.",
                    "QUESTIONNAIRE",
                    "PATIENT"
            );
        } catch (Exception ignored) {  }

        return saved;
    }

    @Override
    public List<QuestionnaireResponseDto> getPatientQuestionnaires(Long patientId) {
        if (!SecurityUtils.hasRole("PSYCHOLOGIST")) {
            throw new ForbiddenOperationException(
                    "Accès réservé au psychologue"
            );
        }

        Long psyId = ownershipResolver.resolveOwnPsychologistId();

        return questionnaireRepository
                .findByPsychologistIdAndPatientIdOrderBySentAtDesc(psyId, patientId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public List<QuestionnaireResponseDto> getMyPendingQuestionnaires() {
        if (!SecurityUtils.hasRole("PATIENT")) {
            throw new ForbiddenOperationException(
                    "Seul un patient peut consulter ses questionnaires en attente"
            );
        }

        Long patientId = ownershipResolver.resolveOwnPatientId();

        return questionnaireRepository
                .findByPatientIdAndStatusOrderBySentAtDesc(patientId, QuestionnaireStatus.SENT)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public List<QuestionnaireResponseDto> getMyQuestionnaires() {
        if (!SecurityUtils.hasRole("PATIENT")) {
            throw new ForbiddenOperationException(
                    "Seul un patient peut consulter son historique de questionnaires"
            );
        }

        Long patientId = ownershipResolver.resolveOwnPatientId();

        return questionnaireRepository
                .findByPatientIdOrderBySentAtDesc(patientId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public QuestionnaireResponseDto answerQuestionnaire(
            Long id, AnswerQuestionnaireRequest request
    ) {
        if (!SecurityUtils.hasRole("PATIENT")) {
            throw new ForbiddenOperationException(
                    "Seul le patient destinataire peut répondre au questionnaire"
            );
        }

        Long patientId = ownershipResolver.resolveOwnPatientId();

        Questionnaire q = questionnaireRepository
                .findByIdAndPatientId(id, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Questionnaire introuvable"
                ));

        if (q.getStatus() == QuestionnaireStatus.COMPLETED) {
            throw new ForbiddenOperationException(
                    "Ce questionnaire a déjà été complété"
            );
        }

        int expected = q.getType() == QuestionnaireType.PHQ9 ? 9 : 7;
        List<Integer> answers = request.getAnswers();

        if (answers == null || answers.size() != expected) {
            throw new IllegalArgumentException(
                    "Le questionnaire " + q.getType().name() + " requiert exactement "
                    + expected + " réponses (0 à 3 chacune)"
            );
        }

        for (Integer a : answers) {
            if (a == null || a < 0 || a > 3) {
                throw new IllegalArgumentException(
                        "Chaque réponse doit être comprise entre 0 et 3"
                );
            }
        }

        int score = answers.stream().mapToInt(Integer::intValue).sum();
        String answersStr = answers.stream()
                .map(String::valueOf)
                .collect(Collectors.joining(","));

        q.setAnswers(answersStr);
        q.setScore(score);
        q.setStatus(QuestionnaireStatus.COMPLETED);
        q.setCompletedAt(LocalDateTime.now());

        QuestionnaireResponseDto result = mapToResponse(questionnaireRepository.save(q));

        String typeName = q.getType() == QuestionnaireType.PHQ9 ? "PHQ-9" : "GAD-7";
        int maxScore = q.getType() == QuestionnaireType.PHQ9 ? 27 : 21;
        String severity = computeSeverity(q.getType(), score);
        try {
            notificationClient.send(
                    q.getPsychologistId(),
                    "Résultats questionnaire " + typeName,
                    patientLabel(q.getPatientId()) + " vous a envoyé les réponses du questionnaire "
                            + typeName + " — Score : " + score + "/" + maxScore
                            + " (" + severity + ")",
                    "QUESTIONNAIRE_RESULT",
                    "PSYCHOLOGIST"
            );
        } catch (Exception ignored) {  }

        return result;
    }

    private String psychologistLabel(Long psychologistId) {
        try {
            Map<String, Object> profile = ownershipResolver.getPsychologistProfile(psychologistId);
            Object firstName = profile.get("firstName");
            Object lastName = profile.get("lastName");
            String full = ((firstName == null ? "" : firstName.toString())
                    + " " + (lastName == null ? "" : lastName.toString())).trim();
            return full.isEmpty() ? "Votre psychologue" : "Dr. " + full;
        } catch (Exception ignored) {
            return "Votre psychologue";
        }
    }

    private String patientLabel(Long patientId) {
        try {
            Map<String, Object> profile = ownershipResolver.getPatientProfile(patientId);
            if (Boolean.TRUE.equals(profile.get("anonymousMode"))) {
                return "Votre patient(e)";
            }
            Object firstName = profile.get("firstName");
            String name = firstName == null ? "" : firstName.toString().trim();
            return name.isEmpty() ? "Votre patient(e)" : name;
        } catch (Exception ignored) {
            return "Votre patient(e)";
        }
    }

    private String computeSeverity(QuestionnaireType type, int score) {
        if (type == QuestionnaireType.PHQ9) {
            if (score <= 4)  return "Dépression minimale";
            if (score <= 9)  return "Dépression légère";
            if (score <= 14) return "Dépression modérée";
            if (score <= 19) return "Dépression modérément sévère";
            return "Dépression sévère";
        } else {
            if (score <= 4)  return "Anxiété minimale";
            if (score <= 9)  return "Anxiété légère";
            if (score <= 14) return "Anxiété modérée";
            return "Anxiété sévère";
        }
    }

    private QuestionnaireResponseDto mapToResponse(Questionnaire q) {
        QuestionnaireResponseDto dto = new QuestionnaireResponseDto();
        dto.setId(q.getId());
        dto.setType(q.getType());
        dto.setStatus(q.getStatus());
        dto.setPsychologistId(q.getPsychologistId());
        dto.setPatientId(q.getPatientId());
        dto.setAppointmentId(q.getAppointmentId());
        dto.setSentAt(q.getSentAt());
        dto.setCompletedAt(q.getCompletedAt());

        if (q.getAnswers() != null) {
            List<Integer> answers = Arrays.stream(q.getAnswers().split(","))
                    .map(Integer::parseInt)
                    .collect(Collectors.toList());
            dto.setAnswers(answers);
        }

        if (q.getScore() != null) {
            dto.setScore(q.getScore());
            dto.setSeverity(computeSeverity(q.getType(), q.getScore()));
        }

        return dto;
    }
}
