# 06 — Le psy envoie un PHQ-9, le patient y répond

Ce fil suit un questionnaire clinique standardisé, de l'envoi par le psychologue jusqu'au score affiché
sur la fiche du patient. Il contient aussi le filet de sécurité de la question 9 du PHQ-9, l'un des
arguments éthiques les plus forts du projet.

Vérifié dans le code le 24/09/2026. Service : `appointment-service` (`QuestionnaireServiceImpl`).

---

## En une phrase

Le psychologue envoie un PHQ-9 (dépression, 9 questions) ou un GAD-7 (anxiété, 7 questions) ; le patient
répond de 0 à 3 à chaque question ; le serveur vérifie, additionne, classe la sévérité et prévient le psy ;
l'application repère à part la question 9, celle sur les idées suicidaires.

## Les deux échelles

| | PHQ-9 | GAD-7 |
|---|---|---|
| Mesure | symptômes dépressifs | symptômes anxieux |
| Questions | 9 | 7 |
| Réponses | 0 « jamais » à 3 « presque tous les jours » | idem |
| Score max | 27 | 21 |
| Références | Kroenke et al., 2001 | Spitzer et al., 2006 |

Ce sont des **outils de dépistage**, pas de diagnostic. L'écran de résultats le rappelle au patient.

## Étape 1 — Le psy envoie (`sendQuestionnaire`, ligne 43)

Depuis la fiche patient (`patient_questionnaires_screen.dart`, ligne 92) : `POST /questionnaires`.

- Seul un **psychologue** peut envoyer (ligne 44).
- L'identifiant du psy vient du **jeton**, pas de la requête (`resolveOwnPsychologistId`).
- Le questionnaire est créé en attente ; le patient reçoit une notification `QUESTIONNAIRE` du type
  « Dr. Diallo vous a envoyé un questionnaire PHQ-9 (dépression) ».

## Étape 2 — Le patient voit ses questionnaires en attente

`GET /questionnaires/patient/me/pending` : le « me » veut dire que le serveur déduit le patient du jeton.
Pas d'identifiant dans l'adresse, donc rien à falsifier.

## Étape 3 — Le patient répond (`answerQuestionnaire`, ligne 127)

`POST /questionnaires/{id}/answers` avec la liste des réponses. Le serveur vérifie :

1. l'appelant est un **patient** ;
2. le questionnaire **lui appartient** (`findByIdAndPatientId` : on cherche par identifiant ET patient,
   donc le questionnaire d'un autre est simplement « introuvable ») ;
3. il n'est **pas déjà complété** ;
4. il y a **exactement 9 réponses** pour un PHQ-9, 7 pour un GAD-7 ;
5. chaque réponse est **entre 0 et 3**.

Puis il additionne, enregistre les réponses, le score et la date, et passe le questionnaire en
`COMPLETED`.

Le serveur **recalcule** le score lui-même : il ne reçoit que les réponses. L'application ne peut pas
envoyer un faux score.

## Étape 4 — La sévérité (`computeSeverity`, ligne 225)

| Score PHQ-9 | Sévérité | Score GAD-7 | Sévérité |
|---|---|---|---|
| 0–4 | minimale | 0–4 | minimale |
| 5–9 | légère | 5–9 | légère |
| 10–14 | modérée | 10–14 | modérée |
| 15–19 | modérément sévère | 15–21 | sévère |
| 20–27 | sévère | | |

Ce sont les seuils publiés des échelles, pas des valeurs inventées.

## Étape 5 — Le psy est prévenu

Notification `QUESTIONNAIRE_RESULT` : « Awa vous a envoyé les réponses du questionnaire PHQ-9 — Score :
12/27 (Dépression modérée) ».

Respect de l'anonymat : si le patient a activé le **mode anonyme**, la notification dit « Votre
patient(e) » au lieu de son prénom (`patientLabel`, ligne 211).

## Étape 6 — Le filet de sécurité de la question 9

La question 9 du PHQ-9 porte sur les **idées suicidaires ou d'automutilation**. Un score total faible peut
cacher une réponse inquiétante à cette seule question. Le projet la traite donc à part, **quel que soit le
score**.

`frontend/psyconnect/lib/features/patient/models/questionnaire_models.dart` :

```dart
const int kPhq9RiskItemIndex = 8;   // la 9e question (on compte à partir de 0)
const int kRiskThreshold = 2;       // « plus de la moitié des jours » ou plus

bool get signalsImmediateRisk => a[kPhq9RiskItemIndex] >= kRiskThreshold;   // ligne 87
```

- **Côté patient** (`questionnaire_fill_screen.dart`) : dès qu'il répond 2 ou 3 à la question 9, une carte
  « Parler à quelqu'un maintenant » apparaît sous la question et sur l'écran de résultats. Elle ouvre
  l'écran d'urgence. Elle est **non bloquante** : il peut continuer le questionnaire.
- **Côté psy** (`patient_questionnaires_screen.dart`, ligne 595) : le questionnaire est encadré en rouge
  avec « Idées suicidaires signalées (item 9) — à traiter en priorité ».

Le serveur n'a pas été modifié pour ça : les réponses détaillées sont déjà renvoyées par l'API, et le
calcul se fait dans l'application.

---

## Ce que ce fil démontre

| Notion | Où |
|---|---|
| Validation des entrées côté serveur | nombre et plage des réponses |
| Le serveur calcule, le client ne fait que saisir | score recalculé |
| Identité tirée du jeton | `/me/pending`, `resolveOwnPsychologistId` |
| Recherche par identifiant ET propriétaire | `findByIdAndPatientId` |
| Respect du mode anonyme | `patientLabel` |
| Démarche éthique | filet de la question 9 |

## Limites à connaître

1. **La notification au psy ne signale pas la question 9.** Elle donne le score et la sévérité ; l'alerte
   rouge n'apparaît que lorsque le psy ouvre la fiche. Une réponse à risque avec un score faible arrive
   donc sous la forme d'une notification banale. Correctif simple : tester la question 9 dans
   `answerQuestionnaire` et adapter le titre de la notification.
2. **N'importe quel psychologue peut envoyer un questionnaire à n'importe quel patient.**
   `sendQuestionnaire` ne vérifie pas de lien de suivi ni de rendez-vous commun.
3. **Types codés en dur** (`enum QuestionnaireType { PHQ9, GAD7 }`) : ajouter l'EPDS (dépression
   post-partum), prévu en perspective, demande de toucher l'énumération Java, l'énumération Dart, le
   score, les seuils et le filet (sa question 10 porte aussi sur l'auto-agression).
4. Pas de questionnaire en libre accès pour le patient dans l'application : c'est toujours le psy qui
   l'envoie. Les trois tests en libre accès sont sur le site vitrine.

## Questions probables du jury

**« Pourquoi ces deux échelles ? »**
Elles sont validées, courtes, gratuites, traduites en français et utilisées en soins primaires dans le
monde entier. Dépression et anxiété sont les deux troubles les plus fréquents.

**« Le patient peut-il tricher ? »**
Sur ses réponses, oui, comme sur papier : c'est une auto-évaluation. Sur le score, non : le serveur le
recalcule.

**« Que fait l'application face à une réponse suicidaire ? »**
Elle ne diagnostique rien et ne bloque rien. Elle propose immédiatement une aide humaine, et elle signale
la réponse au psychologue en priorité sur la fiche. C'est la même ligne de conduite que le garde-fou de
Xalaat (fil 11).
