package com.example.appointmentservice.entity;

import java.util.List;
import java.util.Set;

// PHQ-9 : depression (9 questions, score 0-27)
// GAD-7 : anxiete (7 questions, score 0-21)
// Echelle de Likert 0-3 pour chaque question :
//   0=Jamais  1=Plusieurs jours  2=Plus de la moitie des jours  3=Presque tous les jours
// PSS-10 : stress percu (10 questions, reponses 0-4, score 0-40), items 4, 5, 7 et 8 inverses
// EPDS : depression post-natale (10 questions, reponses 0-3, score 0-30), items 3 et 5 a 10 inverses
// la reponse stockee est la position de l'option choisie, le score tient compte des items inverses
public enum QuestionnaireType {
    PHQ9("PHQ-9", "dépression", 9, 3, Set.of()),
    GAD7("GAD-7", "anxiété", 7, 3, Set.of()),
    PSS10("PSS-10", "stress perçu", 10, 4, Set.of(3, 4, 6, 7)),
    EPDS("EPDS", "dépression post-natale", 10, 3, Set.of(2, 4, 5, 6, 7, 8, 9));

    private final String label;
    private final String theme;
    private final int itemCount;
    private final int maxAnswer;
    private final Set<Integer> reversedItems;

    QuestionnaireType(String label, String theme, int itemCount, int maxAnswer, Set<Integer> reversedItems) {
        this.label = label;
        this.theme = theme;
        this.itemCount = itemCount;
        this.maxAnswer = maxAnswer;
        this.reversedItems = reversedItems;
    }

    public String getLabel() { return label; }
    public String getTheme() { return theme; }
    public int getItemCount() { return itemCount; }
    public int getMaxAnswer() { return maxAnswer; }

    public int getMaxScore() {
        return itemCount * maxAnswer;
    }

    public int score(List<Integer> answers) {
        int total = 0;
        for (int i = 0; i < answers.size(); i++) {
            int a = answers.get(i);
            total += reversedItems.contains(i) ? maxAnswer - a : a;
        }
        return total;
    }
}
