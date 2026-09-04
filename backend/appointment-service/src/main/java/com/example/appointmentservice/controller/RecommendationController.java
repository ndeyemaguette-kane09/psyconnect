package com.example.appointmentservice.controller;

import com.example.appointmentservice.dto.CreateRecommendationRequest;
import com.example.appointmentservice.dto.RecommendationResponse;
import com.example.appointmentservice.service.RecommendationService;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/session-recommendations")
public class RecommendationController {

    private final RecommendationService recommendationService;

    public RecommendationController(RecommendationService recommendationService) {
        this.recommendationService = recommendationService;
    }

    @PostMapping
    public ResponseEntity<RecommendationResponse> create(
            @Valid @RequestBody CreateRecommendationRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(recommendationService.createRecommendation(request));
    }

    @GetMapping("/patient/me")
    public ResponseEntity<List<RecommendationResponse>> getMyPending() {
        return ResponseEntity.ok(recommendationService.getMyPendingRecommendations());
    }

    @GetMapping("/appointment/{appointmentId}")
    public ResponseEntity<List<RecommendationResponse>> getByAppointment(
            @PathVariable Long appointmentId
    ) {
        return ResponseEntity.ok(recommendationService.getByAppointment(appointmentId));
    }

    @PatchMapping("/{id}/complete")
    public ResponseEntity<RecommendationResponse> markCompleted(
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(recommendationService.markCompleted(id));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        recommendationService.deleteRecommendation(id);
        return ResponseEntity.noContent().build();
    }
}
