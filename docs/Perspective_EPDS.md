# Perspective — intégrer l'EPDS au module de questionnaires

L'EPDS (Edinburgh Postnatal Depression Scale) est l'outil de référence pour le dépistage de la
dépression du post-partum. Il existe une version française validée, et l'échelle est dans le domaine
public comme le PHQ-9 et le GAD-7.

L'intérêt pour PsyConnect est direct : la dépression du post-partum est largement sous-détectée, la
santé maternelle est un enjeu de santé publique au Sénégal, et le module de questionnaires existe
déjà. C'est l'extension fonctionnelle la plus pertinente du projet.

Ce document explique pourquoi ce n'est pas l'ajout d'une valeur d'énumération, et ce qu'il faudrait
faire pour l'implémenter correctement.

---

## Pourquoi le GAD-7 s'est ajouté sans effort

Le GAD-7 est le clone structurel du PHQ-9 :

| | PHQ-9 | GAD-7 |
|---|---|---|
| Items | 9 | 7 |
| Échelle | Likert 0-3 | Likert 0-3 |
| Libellés de réponse | identiques | identiques |
| Fenêtre de rappel | 2 semaines | 2 semaines |
| Score | somme brute | somme brute |

Une seule dimension varie : le nombre d'items. Le code a donc été écrit en binaire, sous la forme
`type == PHQ9 ? valeurPhq9 : valeurGad7`.

## Les branchements binaires à reprendre

Dix-sept emplacements font aujourd'hui cette hypothèse. Ajouter une troisième valeur à l'énumération
ne produit **aucune erreur de compilation** : chaque ternaire classerait silencieusement l'EPDS
comme un GAD-7.

**Backend — `appointment-service`**

| Fichier | Ligne | Hypothèse binaire |
|---|---|---|
| `service/impl/QuestionnaireServiceImpl.java` | 60 | libellé du type dans la notification |
| `service/impl/QuestionnaireServiceImpl.java` | 150 | nombre de réponses attendu (9 ou 7) |
| `service/impl/QuestionnaireServiceImpl.java` | 180 | libellé court du type |
| `service/impl/QuestionnaireServiceImpl.java` | 181 | score maximal (27 ou 21) |
| `service/impl/QuestionnaireServiceImpl.java` | 225 | `computeSeverity` — bandes de sévérité |
| `entity/QuestionnaireType.java` | 7 | énumération à deux valeurs |

**Frontend**

| Fichier | Ligne | Hypothèse binaire |
|---|---|---|
| `features/patient/models/questionnaire_models.dart` | 88 | item de risque réservé au PHQ-9 |
| `features/patient/models/questionnaire_models.dart` | 95 | `maxScore` |
| `features/patient/models/questionnaire_models.dart` | 98 | liste des questions |
| `features/patient/models/questionnaire_models.dart` | 101 | `typeName` |
| `features/patient/models/questionnaire_models.dart` | 103 | `typeDescription` |
| `features/patient/models/questionnaire_models.dart` | 111 | désérialisation depuis le JSON |
| `features/patient/screens/questionnaire_history_screen.dart` | 154, 159 | couleur de texte et de fond associées au type |
| `features/patient/screens/questionnaire_fill_screen.dart` | 136 | mise en avant de l'item de risque |
| `features/patient/screens/questionnaire_fill_screen.dart` | 487 | bandes de sévérité affichées |
| `features/patient/services/questionnaire_service.dart` | 46 | sérialisation vers le JSON |
| `features/psychologist/screens/patient_questionnaires_screen.dart` | 100 | message de confirmation d'envoi |

Le seul endroit qui échouerait bruyamment est la ligne 150 du backend : un EPDS soumet 10 réponses,
la validation en attend 7.

## Les quatre hypothèses que l'EPDS invalide

**1. Le score maximal n'est plus binaire.** L'EPDS compte 10 items, score de 0 à 30.

**2. Les libellés de réponse ne sont plus partagés.** Le PHQ-9 et le GAD-7 utilisent la même échelle
(`kAnswerLabels` : « Jamais », « Plusieurs jours », « Plus de la moitié des jours », « Presque tous
les jours »). L'EPDS associe à chaque item ses propres modalités de réponse. La constante partagée
doit devenir une propriété de l'item, pas du questionnaire.

**3. Sept items sont cotés en sens inverse** (items 3, 5, 6, 7, 8, 9 et 10). Le score n'est pas la
somme brute des réponses dans l'ordre d'affichage. C'est le point le plus dangereux : une somme
naïve produit des scores plausibles et faux, sans aucun signal d'erreur.

**4. La fenêtre de rappel est de 7 jours**, pas de 2 semaines. Le texte d'introduction du
questionnaire ne peut plus être commun.

À quoi s'ajoute une contrainte fonctionnelle : l'échelle vise une population précise (période
péri- et post-natale). L'envoi ne peut pas être proposé indifféremment pour tout patient.

## Le point critique — l'item 10

L'item 10 de l'EPDS porte sur les idées de se faire du mal. Le mécanisme de détection existe déjà
dans le projet, mais il est verrouillé sur un seul type :

```dart
// features/patient/models/questionnaire_models.dart:88
bool get signalsImmediateRisk {
  if (type != QuestionnaireType.PHQ9) return false;
  ...
  return a[kPhq9RiskItemIndex] >= kRiskThreshold;
}
```

Un EPDS ajouté sans toucher à cette méthode aurait son item le plus critique **non surveillé**.

Deux paramètres doivent donc dépendre du type, et non plus être des constantes globales :

- l'**index** de l'item de risque (8 pour le PHQ-9, 9 pour l'EPDS) ;
- le **seuil** de déclenchement. La convention pour l'EPDS est plus stricte que pour le PHQ-9 :
  toute réponse non nulle à l'item 10 justifie une attention, là où `kRiskThreshold` vaut
  aujourd'hui 2.

## Le refactoring proposé

Remplacer les dix-sept branchements par un **descripteur par type**, défini une seule fois de chaque
côté et consulté partout ailleurs :

```
QuestionnaireDescriptor
  ├── code                (PHQ9 | GAD7 | EPDS)
  ├── nom affiché, description, fenêtre de rappel
  ├── items               (libellé + modalités de réponse propres à l'item)
  ├── itemsInverses       (indices cotés en sens inverse)
  ├── scoreMaximal
  ├── bandesDeSeverite    (seuil → libellé)
  └── itemDeRisque        (index + seuil de déclenchement, ou aucun)
```

Le score, la sévérité, le nombre de réponses attendu, l'affichage et la détection de risque se
déduisent alors du descripteur. Ajouter une quatrième échelle devient une entrée de configuration,
plus une modification de code.

## Estimation

| Lot | Contenu |
|---|---|
| 1 | Descripteur backend + `computeSeverity` et validation pilotés par le descripteur |
| 2 | Descripteur frontend + suppression des ternaires dans les modèles et les écrans |
| 3 | Données de l'EPDS : 10 items, modalités par item, items inversés, bandes de sévérité |
| 4 | Item de risque paramétré par type, et restriction de la population cible à l'envoi |
| 5 | Tests : cotation inversée, score maximal, déclenchement du risque à partir de 1 |

Le lot 5 n'est pas optionnel. Une échelle de dépistage dont la cotation n'est pas testée est plus
risquée que pas d'échelle du tout, puisqu'elle produit des résultats crédibles.

## Décision

Reporté après la soutenance. La valeur de cette extension n'est pas le troisième questionnaire :
c'est le passage d'un branchement binaire à une configuration par type, qui rend le module
réellement extensible.
