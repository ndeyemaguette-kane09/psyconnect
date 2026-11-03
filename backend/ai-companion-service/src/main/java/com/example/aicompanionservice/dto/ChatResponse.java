package com.example.aicompanionservice.dto;

public record ChatResponse(
        String reply,
        // true si le garde-fou a répondu à la place du modèle
        boolean flagged
) {
}
