package com.example.aicompanionservice.dto;

public record ChatResponse(
        String reply,
        // true si le filtre de sécurité s'est déclenché (la réponse vient
        // du message fixe, pas du modèle). Permet au front d'adapter
        // l'affichage (ex: mettre en avant les numéros d'urgence visuellement).
        boolean flagged
) {
}
