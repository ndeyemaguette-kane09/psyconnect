package com.example.aicompanionservice.service;

import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.List;
import java.util.regex.Pattern;

// filtre lancé avant le modèle : si détresse, on renvoie les numéros d'urgence sans appeler le LLM
@Service
public class RiskDetectionService {

    private static final List<Pattern> RISK_PATTERNS = List.of(
            "me suicider", "me suicide", "envie de me suicider",
            "me tuer", "envie de me tuer", "me donner la mort",
            "en finir avec (ma vie|tout|cette vie|l'existence|mes jours)",
            "en finir une bonne fois pour toutes",
            "envie de mourir", "veux mourir", "j'aimerais mourir",
            "plus envie de vivre", "ca ne vaut plus le coup de vivre",
            "(veux|vais|voudrais) en finir",
            "me faire du mal", "me blesser volontairement",
            "m'automutiler", "automutilation", "me scarifier", "scarification",
            "avaler (tous les |des )?medicaments", "faire une overdose",
            "me pendre", "me jeter (du|par la)", "sauter du (pont|toit|immeuble|balcon)",
            "plus la force de continuer", "plus aucune raison de continuer",
            "personne ne me manquerait", "le monde irait mieux sans moi",
            "je veux disparaitre", "envie de disparaitre",
            "plus rien ne me retient", "j'ai prepare (ma|ce qu'il faut pour)",
            "(n'en|ne) peux plus (de )?(vivre|cette vie|la vie)",
            "plus la force de vivre", "fatiguee? de vivre",
            "marre de (vivre|la vie|cette vie)",
            "envie d'en finir", "ma vie n'a plus (de|aucun) sens",
            "(ne plus|pas) me reveiller", "(voudrais|veux|aimerais) etre morte?"
    ).stream()
            .map(p -> Pattern.compile(p, Pattern.CASE_INSENSITIVE))
            .toList();

    public boolean isRisky(String message) {

        if (message == null || message.isBlank()) {
            return false;
        }

        String normalized = normalize(message);

        for (Pattern pattern : RISK_PATTERNS) {
            if (pattern.matcher(normalized).find()) {
                return true;
            }
        }

        return false;
    }

    private String normalize(String text) {

        String lower = text.toLowerCase();

        String withoutAccents = Normalizer
                .normalize(lower, Normalizer.Form.NFD)
                .replaceAll("[\\p{InCombiningDiacriticalMarks}]", "");

        return withoutAccents
                .replaceAll("[\\u2018\\u2019\\u02BC\\u0060\\u00B4]", "'")
                .replaceAll("[\\u00A0\\u202F]", " ")
                .replaceAll("\\s+", " ");
    }
}
