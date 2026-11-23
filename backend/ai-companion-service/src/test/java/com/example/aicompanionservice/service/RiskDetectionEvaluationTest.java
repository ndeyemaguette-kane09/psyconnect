package com.example.aicompanionservice.service;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import static org.junit.jupiter.api.Assertions.assertTrue;

class RiskDetectionEvaluationTest {

    private record Exemple(boolean crise, String categorie, String message) {
    }

    private final RiskDetectionService service = new RiskDetectionService();

    @ParameterizedTest
    @ValueSource(strings = {"jeu_evaluation", "jeu_test"})
    void evalueLeGardeFouSurLeJeuEtiquete(String nomDuJeu) throws IOException {
        List<Exemple> jeu = chargerJeu(nomDuJeu);

        int vraisPositifs = 0;
        int fauxPositifs = 0;
        int vraisNegatifs = 0;
        int fauxNegatifs = 0;
        List<String> crisesManquees = new ArrayList<>();
        List<String> faussesAlertes = new ArrayList<>();

        for (Exemple e : jeu) {
            boolean detecte = service.isRisky(e.message());
            if (e.crise() && detecte) {
                vraisPositifs++;
            } else if (e.crise()) {
                fauxNegatifs++;
                crisesManquees.add("[" + e.categorie() + "] " + e.message());
            } else if (detecte) {
                fauxPositifs++;
                faussesAlertes.add("[" + e.categorie() + "] " + e.message());
            } else {
                vraisNegatifs++;
            }
        }

        double rappel = ratio(vraisPositifs, vraisPositifs + fauxNegatifs);
        double precision = ratio(vraisPositifs, vraisPositifs + fauxPositifs);
        double f1 = ratio(2 * precision * rappel, precision + rappel);
        double tauxFaussesAlertes = ratio(fauxPositifs, fauxPositifs + vraisNegatifs);

        StringBuilder rapport = new StringBuilder();
        rapport.append("Évaluation du garde-fou de Xalaat : ").append(nomDuJeu).append("\n\n");
        rapport.append("Messages : ").append(jeu.size())
                .append(" (crise : ").append(vraisPositifs + fauxNegatifs)
                .append(", ordinaires : ").append(fauxPositifs + vraisNegatifs).append(")\n\n");
        rapport.append("Vrais positifs : ").append(vraisPositifs).append('\n');
        rapport.append("Faux négatifs : ").append(fauxNegatifs).append('\n');
        rapport.append("Faux positifs : ").append(fauxPositifs).append('\n');
        rapport.append("Vrais négatifs : ").append(vraisNegatifs).append("\n\n");
        rapport.append("Rappel : ").append(pourcent(rappel)).append('\n');
        rapport.append("Précision : ").append(pourcent(precision)).append('\n');
        rapport.append("F1 : ").append(pourcent(f1)).append('\n');
        rapport.append("Taux de fausses alertes : ").append(pourcent(tauxFaussesAlertes)).append("\n\n");
        rapport.append("Crises manquées :\n");
        crisesManquees.forEach(m -> rapport.append("- ").append(m).append('\n'));
        rapport.append("\nFausses alertes :\n");
        faussesAlertes.forEach(m -> rapport.append("- ").append(m).append('\n'));

        System.out.println(rapport);
        Path sortie = Path.of("build", "evaluation", "garde-fou-" + nomDuJeu + ".txt");
        Files.createDirectories(sortie.getParent());
        Files.writeString(sortie, rapport.toString(), StandardCharsets.UTF_8);

        assertTrue(vraisPositifs + fauxNegatifs > 0);
        assertTrue(fauxPositifs + vraisNegatifs > 0);
    }

    private List<Exemple> chargerJeu(String nomDuJeu) throws IOException {
        List<Exemple> jeu = new ArrayList<>();
        try (BufferedReader lecteur = new BufferedReader(new InputStreamReader(
                getClass().getResourceAsStream("/garde-fou/" + nomDuJeu + ".csv"), StandardCharsets.UTF_8))) {
            lecteur.readLine();
            String ligne;
            while ((ligne = lecteur.readLine()) != null) {
                if (ligne.isBlank()) {
                    continue;
                }
                String[] champs = ligne.split(";", 3);
                jeu.add(new Exemple("CRISE".equals(champs[0]), champs[1], champs[2]));
            }
        }
        return jeu;
    }

    private static double ratio(double numerateur, double denominateur) {
        return denominateur == 0 ? 0 : numerateur / denominateur;
    }

    private static String pourcent(double valeur) {
        return String.format(Locale.FRANCE, "%.1f %%", valeur * 100);
    }
}
