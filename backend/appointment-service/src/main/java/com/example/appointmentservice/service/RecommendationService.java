package com.example.appointmentservice.service;

import com.example.appointmentservice.dto.CreateRecommendationRequest;
import com.example.appointmentservice.dto.RecommendationResponse;

import java.util.List;

public interface RecommendationService {

    // psy : ajoute une recommandation apres une seance terminee
    RecommendationResponse createRecommendation(
            CreateRecommendationRequest request);

    // patient : toutes ses recommandations non cochees
    List<RecommendationResponse> getMyPendingRecommendations();

    // psy ou patient : recommandations d'un RDV specifique
    List<RecommendationResponse> getByAppointment(Long appointmentId);

    // patient : coche une recommandation comme accomplie
    RecommendationResponse markCompleted(Long id);

    // Psychologue : supprime une de ses recommandations
    void deleteRecommendation(Long id);
}
