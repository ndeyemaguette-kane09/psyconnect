package com.example.appointmentservice.service;

import com.example.appointmentservice.dto.CreateRecommendationRequest;
import com.example.appointmentservice.dto.RecommendationResponse;

import java.util.List;

public interface RecommendationService {

    
    RecommendationResponse createRecommendation(
            CreateRecommendationRequest request);

    
    List<RecommendationResponse> getMyPendingRecommendations();

    
    List<RecommendationResponse> getByAppointment(Long appointmentId);

    
    RecommendationResponse markCompleted(Long id);

    
    void deleteRecommendation(Long id);
}
