package com.example.aicompanionservice.service;

import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.List;
import java.util.regex.Pattern;

// filtre lancé avant le modèle : si détresse, on renvoie les numéros d'urgence sans appeler le LLM
@Service
public class RiskDetectionService {

    private static final List<Pattern> RISK_PATTERNS = List.of(
            "suicid", "me suicider", "me suicide", "envie de me suicider",
            "me tuer", "envie de me tuer", "me donner la mort",
            "en finir avec (ma vie|tout|cette vie|l'existence|mes jours)",
            "en finir une bonne fois pour toutes",
            "envie de mourir", "veux mourir", "j'aimerais mourir",
            "(veux|voudrais|aimerais|envie de|souhaite) (juste |seulement |vraiment |simplement |tellement |tout simplement |bien )?(mourir|disparaitre|en finir)",
            "envies? de (mort|mourir|me tuer|en finir)",
            "(ne )?veux plus vivre", "plus envie d'etre (la|en vie)",
            "mettre fin a (mes jours|ma vie)", "me supprimer",
            "idees? noires", "pensees? (noires|de mort)",
            "(mieux|plus simple) (si j'etais|d'etre) morte?",
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
            "(ne plus|pas) me reveiller", "(voudrais|veux|aimerais) etre morte?",
            "(ne|n'?) ?(vois|trouve) plus (d'?|de |aucune )?(issue|solution|sortie|lumiere)",
            "a quoi bon (continuer|vivre|me battre|rester|tout ca)",
            "(mieux|soulages?|plus heureux|plus tranquilles?) (sans moi|si je (partais|disparaissais|mourais|n'etais plus la))",
            "(un|une) (poids|fardeau) pour (ma famille|mes proches|mes parents|les autres|tout le monde)",
            "de trop (dans ce monde|sur terre|ici)",
            "lettre d'?adieu", "(faire|dire) (mes )?adieux?", "dis au revoir a tout le monde",
            "(ne )?(jamais|plus) me reveiller", "(m'?endormir|dormir) pour (toujours|de bon)",
            "(tout|tous) (arreter|abandonner|lacher) (definitivement|pour de bon|pour toujours|meme la vie)",
            "partir pour (toujours|de bon)", "partir definitivement",
            "plus (la|aucune) force de (me battre|lutter|continuer|tenir|vivre)",
            "(ne serai|serai) bientot plus (la|de ce monde)", "bientot fini pour moi",
            "j'?ai donne mes affaires", "(n'en|en) aurai plus besoin",
            "(que tout|que ca) (s'?arrete|cesse)",
            "(pense|pensais|penser) (souvent |beaucoup |tout le temps |sans arret )?a la mort",
            "la mort (serait|sera) (une )?(delivrance|soulagement|solution)",
            "personne ne (remarquerait|verrait|me regretterait|se rendrait compte|me pleurerait)",
            "(ne plus|plus) exister", "plus envie d'?exister",
            "(plus|aucune) (aucune )?raisons? de (vivre|continuer|rester)",
            "(prefere|prefererais) (etre )?morte?", "plus etre en vie", "(supporte|supporter) plus d'?etre en vie",
            "devrais en finir", "pour en finir", "arreter de vivre", "(compte|vais|veux) me tuer",
            "(prendre|pris) ma decision",
            "me (scarifi|mutil)", "(entailles?|coupures?) sur (les|mes) (bras|poignets|cuisses|jambes)",
            "(encore|a nouveau|de nouveau) (me )?(suis )?coupee?", "me couper (les|le) (bras|poignets|veines)",
            "(avaler|prendre|pris|achete) (tous |toutes )?(mes |les |des )?(medicaments|cachets|comprimes)",
            "(pense|pensais|penser) a me pendre", "me pendre",
            "(envie de|veux|vais) crever", "me foutre en l'?air",
            "(degager|degage|sortir|partir) de cette vie",
            "plus envie d'?etre (la|en vie)", "plus envie de vivre",
            "(en )?peux plus (de )?(vivre|cette vie|la vie)", "jpp de vivre",
            "fatiguee?r? de (la vie|vivre)",
            "(j|g|je) ?ve[uxt]* (mourir|en finir?e?|plus vivre)",
            "\\bve[uxt]* en finir?e?",
            "b[eu]gg?( naa)? dee", "dee rekk", "sonn ci dund", "sonal dund",
            "want to die", "(kill|killing|end) (myself|my life)", "(don'?t|do not) want to live"
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
