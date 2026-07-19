package com.example.appointmentservice.repository;

import com.example.appointmentservice.entity.SessionRecommendation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SessionRecommendationRepository
        extends JpaRepository<SessionRecommendation, Long> {

    // toutes les recommandations non cochees du patient (vue accueil)
    List<SessionRecommendation> findByPatientIdAndCompletedFalseOrderByCreatedAtDesc(
            Long patientId);

    // toutes les recommandations d'un RDV (vue psy apres seance)
    List<SessionRecommendation> findByAppointmentIdOrderByCreatedAtDesc(
            Long appointmentId);

    // Vérification de propriété psychologue avant édition/suppression
    Optional<SessionRecommendation> findByIdAndPsychologistId(
            Long id, Long psychologistId);

    // Vérification de propriété patient avant cochage
    Optional<SessionRecommendation> findByIdAndPatientId(
            Long id, Long patientId);
}
