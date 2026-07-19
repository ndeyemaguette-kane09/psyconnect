package com.example.appointmentservice.repository;

import com.example.appointmentservice.entity.Questionnaire;
import com.example.appointmentservice.entity.QuestionnaireStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface QuestionnaireRepository extends JpaRepository<Questionnaire, Long> {

    // PATIENT : questionnaires en attente
    List<Questionnaire> findByPatientIdAndStatusOrderBySentAtDesc(
            Long patientId, QuestionnaireStatus status);

    // PSY : historique d'un patient specifique (tous statuts)
    List<Questionnaire> findByPsychologistIdAndPatientIdOrderBySentAtDesc(
            Long psychologistId, Long patientId);

    // Psychologue : tous ses questionnaires envoyés
    List<Questionnaire> findByPsychologistIdOrderBySentAtDesc(Long psychologistId);

    // acces securise : patient peut repondre seulement a ses propres questionnaires
    Optional<Questionnaire> findByIdAndPatientId(Long id, Long patientId);

    // psy peut voir le detail de ses propres questionnaires
    Optional<Questionnaire> findByIdAndPsychologistId(Long id, Long psychologistId);

    // PATIENT : tous ses questionnaires (pending + completed), pour l'historique
    List<Questionnaire> findByPatientIdOrderBySentAtDesc(Long patientId);
}
