package com.example.aicompanionservice.service;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RiskDetectionServiceTest {

    private final RiskDetectionService service = new RiskDetectionService();

    @ParameterizedTest
    @ValueSource(strings = {
            "Je veux me suicider",
            "JE VEUX MOURIR",
            "J'aimerais mourir",
            "j’aimerais mourir",
            "Je veux  mourir",
            "Je veux en finir",
            "je vais en finir ce soir",
            "Je voudrais en finir avec ma vie",
            "J’ai préparé ma lettre",
            "je pense à m’automutiler",
            "Je n'ai plus envie de vivre",
            "Ça ne vaut plus le coup de vivre",
            "Le monde irait mieux sans moi",
            "Envie de disparaître",
            "Je n'en peux plus de vivre",
            "je n’en peux plus de cette vie",
            "J'en ai marre de la vie",
            "Je suis fatiguée de vivre",
            "J'ai envie d'en finir",
            "Je voudrais ne plus me réveiller",
            "Je\u00A0veux\u00A0mourir"
    })
    void intercepteLesFormulationsDeCrise(String message) {
        assertTrue(service.isRisky(message), message);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "J'ai peur de ne pas savoir quoi dire au psychologue",
            "J'ai envie de vivre pleinement",
            "Comment se passe une première consultation ?",
            "je ne veux pas mourir",
            "Je suis stressé par mes examens",
            "Je n'en peux plus de ce travail",
            "Je suis fatigué de mes cours"
    })
    void laissePasserLesMessagesOrdinaires(String message) {
        assertFalse(service.isRisky(message), message);
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {"   "})
    void messageVideNonRisque(String message) {
        assertFalse(service.isRisky(message));
    }
}
