package com.example.userservice.service.impl;

import java.util.List;

import org.springframework.stereotype.Service;

import com.example.userservice.client.AppointmentClient;
import com.example.userservice.dto.CreateOrUpdateReviewRequest;
import com.example.userservice.dto.ReviewResponse;
import com.example.userservice.entity.PatientProfile;
import com.example.userservice.entity.PsychologistProfile;
import com.example.userservice.entity.Review;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.repository.PsychologistProfileRepository;
import com.example.userservice.repository.ReviewRepository;
import com.example.userservice.service.ReviewService;

@Service
public class ReviewServiceImpl implements ReviewService {

    private final ReviewRepository reviewRepository;
    private final PatientProfileRepository patientProfileRepository;
    private final PsychologistProfileRepository psychologistProfileRepository;
    private final AppointmentClient appointmentClient;

    public ReviewServiceImpl(
            ReviewRepository reviewRepository,
            PatientProfileRepository patientProfileRepository,
            PsychologistProfileRepository psychologistProfileRepository,
            AppointmentClient appointmentClient
    ) {
        this.reviewRepository = reviewRepository;
        this.patientProfileRepository = patientProfileRepository;
        this.psychologistProfileRepository = psychologistProfileRepository;
        this.appointmentClient = appointmentClient;
    }

    @Override
    public ReviewResponse upsertReview(
            Long psychologistId,
            CreateOrUpdateReviewRequest request,
            Long callerAuthUserId
    ) {

        if (request.getRating() == null
                || request.getRating() < 1
                || request.getRating() > 5) {
            throw new IllegalArgumentException("La note doit être comprise entre 1 et 5");
        }

        PsychologistProfile psychologistProfile = psychologistProfileRepository
                .findById(psychologistId)
                .orElseThrow(() -> new ResourceNotFoundException("Psychologist profile not found"));

        PatientProfile patientProfile = patientProfileRepository
                .findByAuthUserId(callerAuthUserId)
                .orElseThrow(() -> new ForbiddenOperationException(
                        "Seul un patient peut laisser un avis"
                ));

        if (!appointmentClient.hasCompletedAppointmentBetween(psychologistId, patientProfile.getId())) {
            throw new ForbiddenOperationException(
                    "Vous devez avoir terminé au moins une séance avec ce psychologue pour le noter"
            );
        }

        Review review = reviewRepository
                .findByPatientProfileIdAndPsychologistProfileId(patientProfile.getId(), psychologistId)
                .orElseGet(() -> {
                    Review created = new Review();
                    created.setPatientProfileId(patientProfile.getId());
                    created.setPsychologistProfileId(psychologistId);
                    return created;
                });

        review.setRating(request.getRating());
        review.setComment(request.getComment());

        Review saved = reviewRepository.save(review);

        recalculateRating(psychologistProfile);

        return mapToResponse(saved);
    }

    @Override
    public List<ReviewResponse> getPublicReviews(Long psychologistId) {

        if (!psychologistProfileRepository.existsById(psychologistId)) {
            throw new ResourceNotFoundException("Psychologist profile not found");
        }

        return reviewRepository
                .findByPsychologistProfileIdOrderByUpdatedAtDesc(psychologistId)
                .stream()
                .map(this::mapToResponse)
                .toList();
    }

    @Override
    public ReviewResponse getMyReview(Long psychologistId, Long callerAuthUserId) {

        PatientProfile patientProfile = patientProfileRepository
                .findByAuthUserId(callerAuthUserId)
                .orElseThrow(() -> new ForbiddenOperationException(
                        "Seul un patient peut consulter son propre avis"
                ));

        return reviewRepository
                .findByPatientProfileIdAndPsychologistProfileId(patientProfile.getId(), psychologistId)
                .map(this::mapToResponse)
                .orElseGet(ReviewResponse::new);
    }

    // recalcule la moyenne et le total a partir des avis reels, et persiste
    // sur PsychologistProfile (champs déjà utilisés par le tri/recommandations)
    private void recalculateRating(PsychologistProfile psychologistProfile) {
        List<Review> reviews = reviewRepository
                .findByPsychologistProfileIdOrderByUpdatedAtDesc(psychologistProfile.getId());

        int total = reviews.size();
        double average = total == 0
                ? 0.0
                : reviews.stream().mapToInt(Review::getRating).average().orElse(0.0);

        psychologistProfile.setRating(average);
        psychologistProfile.setTotalReviews(total);
        psychologistProfileRepository.save(psychologistProfile);
    }

    private ReviewResponse mapToResponse(Review review) {
        ReviewResponse response = new ReviewResponse();
        response.setRating(review.getRating());
        response.setComment(review.getComment());
        response.setUpdatedAt(review.getUpdatedAt());
        return response;
    }
}
