package com.example.userservice.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

// Toujours anonyme : pas de patientId ni de nom, ni dans la liste publique,
// ni dans la réponse "mon avis" (le patient se reconnaît via l'endpoint
// /me, pas via un champ d'identité dans le DTO)
@Getter
@Setter
public class ReviewResponse {

    // null si le patient n'a pas encore laissé d'avis (réponse "mon avis")
    private Integer rating;

    private String comment;

    private LocalDateTime updatedAt;
}
