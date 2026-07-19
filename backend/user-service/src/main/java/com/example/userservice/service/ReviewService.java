package com.example.userservice.service;

import java.util.List;

import com.example.userservice.dto.CreateOrUpdateReviewRequest;
import com.example.userservice.dto.ReviewResponse;

public interface ReviewService {

    /**
     * Cree ou met a jour l'avis du patient appelant sur ce psychologue.
     * Refuse (403) si l'appelant n'est pas un patient ayant deja eu un
     * rendez-vous COMPLETED avec ce psychologue.
     */
    ReviewResponse upsertReview(
            Long psychologistId,
            CreateOrUpdateReviewRequest request,
            Long callerAuthUserId
    );

    // Liste publique et anonyme, triée du plus récent au plus ancien
    List<ReviewResponse> getPublicReviews(Long psychologistId);

    // avis du patient appelant (rating=null si pas encore d'avis)
    ReviewResponse getMyReview(Long psychologistId, Long callerAuthUserId);
}
