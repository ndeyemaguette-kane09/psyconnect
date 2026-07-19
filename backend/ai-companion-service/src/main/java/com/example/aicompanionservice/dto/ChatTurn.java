package com.example.aicompanionservice.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Un tour de la conversation, tel que renvoye par le client a chaque appel.
 *
 * Ce service ne stocke AUCUN historique cote serveur : c'est le client
 * (l'app Flutter) qui garde la conversation en memoire et la renvoie en
 * entier a chaque message. Rien n'est jamais ecrit en base ni journalise
 * ici (cf. CompanionController) : c'est la condition de confidentialite
 * posee pour cette fonctionnalite.
 */
public record ChatTurn(

        @Pattern(regexp = "user|assistant", message = "role doit etre 'user' ou 'assistant'")
        String role,

        @NotBlank
        String content
) {
}
