package com.example.userservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

// toujours anonyme : ni patientId ni nom, même pour "mon avis"
@Getter
@Setter
public class ReviewResponse {

    // null si le patient n'a pas encore laissé d'avis (réponse "mon avis")
    private Integer rating;

    private String comment;

    private LocalDateTime updatedAt;
}
