package com.example.userservice.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.userservice.dto.CreateOrUpdateReviewRequest;
import com.example.userservice.dto.ReviewResponse;
import com.example.userservice.service.ReviewService;

import jakarta.servlet.http.HttpServletRequest;

// avis patient -> psychologue. La liste (GET /reviews) est publique et
// anonyme. PUT et /review/me exigent d'etre connecte en tant que patient
// ayant déjà eu une séance COMPLETED avec ce psychologue (vérifié dans le service).
@RestController
@RequestMapping("/psychologists/{id}")
public class ReviewController {

    private final ReviewService reviewService;

    public ReviewController(ReviewService reviewService) {
        this.reviewService = reviewService;
    }

    @GetMapping("/reviews")
    public ResponseEntity<List<ReviewResponse>> getPublicReviews(
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(reviewService.getPublicReviews(id));
    }

    @PutMapping("/review")
    public ResponseEntity<ReviewResponse> upsertReview(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestBody CreateOrUpdateReviewRequest request
    ) {
        return ResponseEntity.ok(
                reviewService.upsertReview(id, request, currentAuthUserId(httpRequest))
        );
    }

    @GetMapping("/review/me")
    public ResponseEntity<ReviewResponse> getMyReview(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(
                reviewService.getMyReview(id, currentAuthUserId(httpRequest))
        );
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
