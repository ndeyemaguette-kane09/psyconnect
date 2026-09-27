# TF-IDF et cosinus : un exemple complet

Un exemple calculé avec le vrai code du service de recommandation, étape par étape.
Il sert à comprendre le mécanisme, et à répondre si le jury demande « concrètement ? ».
Les psychologues sont fictifs, mais tous les chiffres sortent du code réel.

---

## Les données de départ

**Le patient** (Dakar) a écrit dans son profil :
- langue : *Français*
- ce qu'il recherche : *« Anxiété liée au travail »*

**Trois psychologues disponibles et validés :**

| Psy | Spécialité | Présentation | Langues | Ville | Note |
|---|---|---|---|---|---|
| A | Anxiété et stress | Stress au travail | Français | Dakar | 4,0 |
| B | Thérapie de couple | Conflits de couple | Français, Wolof | Dakar | 5,0 |
| C | Anxiété | Troubles anxieux | Wolof | Thiès | 4,5 |

---

## Étape 1 : nettoyer les textes

Minuscules, accents retirés, mots vides supprimés (*le, la, au, et, de…*).

| Texte | Mots gardés | Nombre de mots |
|---|---|---|
| Patient | francais, anxiete, liee, travail | 4 |
| Psy A | anxiete, stress, stress, travail, francais | 5 |
| Psy B | therapie, couple, conflits, couple, francais, wolof | 6 |
| Psy C | anxiete, troubles, anxieux, wolof | 4 |

Le vocabulaire commun contient **11 mots**. Chacun devient une colonne du tableau.

---

## Étape 2 : TF, la fréquence du mot dans le texte

**TF = nombre d'apparitions du mot ÷ nombre de mots du texte.**

Exemple : « stress » apparaît 2 fois dans les 5 mots du psy A, donc TF = 2 ÷ 5 = **0,40**.

| | anxiete | anxieux | conflits | couple | francais | liee | stress | therapie | travail | troubles | wolof |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Patient | 0,25 | · | · | · | 0,25 | 0,25 | · | · | 0,25 | · | · |
| Psy A | 0,20 | · | · | · | 0,20 | · | **0,40** | · | 0,20 | · | · |
| Psy B | · | · | 0,17 | **0,33** | 0,17 | · | · | 0,17 | · | · | 0,17 |
| Psy C | 0,25 | 0,25 | · | · | · | · | · | · | · | 0,25 | 0,25 |

*(« · » = 0, le mot n'apparaît pas.)*

---

## Étape 3 : IDF, la rareté du mot parmi tous les textes

On compte dans combien des 4 textes le mot apparaît. Moins il apparaît, plus son IDF
est élevé.

**IDF = ln( (1 + nombre de textes) ÷ (1 + nombre de textes contenant le mot) ) + 1**

| Mot | Présent dans | IDF | Lecture |
|---|---|---|---|
| anxiete, francais | 3 textes sur 4 | **1,22** | banal : il distingue peu |
| travail, wolof | 2 textes sur 4 | **1,51** | moyen |
| anxieux, conflits, couple, liee, stress, therapie, troubles | 1 seul texte | **1,92** | rare : il distingue beaucoup |

Exemple : « anxiete » est dans 3 textes, donc IDF = ln(5 ÷ 4) + 1 = 0,22 + 1 = **1,22**.

---

## Étape 4 : TF-IDF = TF × IDF

Chaque case du tableau TF est multipliée par l'IDF de sa colonne. Chaque ligne devient
la « liste de nombres » (le vecteur) qui représente le texte.

| | anxiete | anxieux | conflits | couple | francais | liee | stress | therapie | travail | troubles | wolof |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Patient | 0,31 | · | · | · | 0,31 | 0,48 | · | · | 0,38 | · | · |
| Psy A | 0,24 | · | · | · | 0,24 | · | **0,77** | · | 0,30 | · | · |
| Psy B | · | · | 0,32 | **0,64** | 0,20 | · | · | 0,32 | · | · | 0,25 |
| Psy C | 0,31 | 0,48 | · | · | · | · | · | · | · | 0,48 | 0,38 |

Exemple : « stress » chez le psy A : 0,40 × 1,92 = **0,77**. C'est le mot qui le
caractérise le plus.

---

## Étape 5 : le cosinus, la ressemblance entre deux textes

**cosinus(A, B) = (A · B) ÷ (‖A‖ × ‖B‖)**

- **A · B** (le produit scalaire) : on multiplie les cases de même colonne, puis on
  additionne. Seuls les mots **communs** aux deux textes comptent, car un 0 annule le
  produit.
- **‖A‖** (la norme) : la « longueur » de la flèche, c'est-à-dire la racine carrée de
  la somme des carrés de ses nombres.
- On divise par les longueurs pour ne garder que la **direction**. Ainsi, une
  présentation longue n'est pas avantagée face à une présentation courte.

**Le calcul pour le patient et le psy A :**

1. Mots communs : anxiete, francais, travail.
   Produit scalaire = 0,31×0,24 + 0,31×0,24 + 0,38×0,30 ≈ **0,264**
2. Longueur du patient ≈ **0,748**. Longueur du psy A ≈ **0,894**
3. Cosinus = 0,264 ÷ (0,748 × 0,894) ≈ **0,39**

**Résultats pour les trois psychologues :**

| Psy | Mots communs avec le patient | Cosinus |
|---|---|---|
| A | anxiete, francais, travail | **0,39** |
| B | francais | 0,10 |
| C | anxiete | 0,15 |

Le cosinus va de **0** (aucun mot en commun) à **1** (mêmes mots, dans les mêmes
proportions). Il ne peut pas être négatif ici, parce que les poids TF-IDF ne le sont
jamais. Dans l'absolu, un cosinus peut descendre jusqu'à −1.

---

## Étape 6 : le score final

**score = 0,6 × cosinus + 0,25 × (note ÷ 5) + 0,15 × même ville**

| Psy | 0,6 × cosinus | 0,25 × note/5 | 0,15 × ville | **Score** | Rang |
|---|---|---|---|---|---|
| A | 0,6 × 0,39 = 0,24 | 0,25 × 0,8 = 0,20 | 0,15 × 1 = 0,15 | **0,59** | 1er |
| B | 0,6 × 0,10 = 0,06 | 0,25 × 1,0 = 0,25 | 0,15 × 1 = 0,15 | **0,46** | 2e |
| C | 0,6 × 0,15 = 0,09 | 0,25 × 0,9 = 0,23 | 0,15 × 0 = 0 | **0,32** | 3e |

---

## Ce que cet exemple révèle (à savoir dire)

**1. Le bon psychologue arrive premier.** A partage le plus de mots importants avec le
patient (anxiété, travail) et il est à Dakar.

**2. La limite des synonymes, visible ici.** Le psy C est spécialiste de l'anxiété,
mais le patient écrit « anxiété » et C écrit « anxieux ». Pour TF-IDF, ce sont **deux
mots différents** : C ne profite que d'un seul mot commun. Le calcul compare des mots,
pas du sens. Des synonymes ou des « plongements de mots » (embeddings) corrigeraient
ce défaut.

**3. Les poids ont des effets à assumer.** B, thérapeute de couple, passe devant C,
spécialiste de l'anxiété. Décomposition de l'écart :

| | B | C | Qui gagne |
|---|---|---|---|
| Ressemblance (0,6 × cosinus) | 0,06 | 0,09 | C |
| Note (0,25 × note/5) | 0,25 | 0,23 | à peu près égal |
| Ville (0,15 × même ville) | 0,15 | 0 | **B, et c'est ce qui fait la différence** |

C'est donc surtout **la ville** qui fait passer B devant, alors que le discours du projet
dit que la ville n'est qu'un bonus, parce que la visio rend la distance secondaire. À
assumer comme une limite du réglage des poids.

**4. La langue n'est qu'un mot parmi d'autres.** C ne parle pas français, et dans la
réalité c'est un vrai obstacle. Mais le calcul ne le sait pas : « francais » est un mot
du texte comme « couple » ou « travail ». Une amélioration logique : traiter la langue
comme un **filtre** (on ne propose pas un psychologue avec qui le patient ne peut pas
communiquer), et non comme un mot.

---

## À dire à l'oral, en 30 secondes

> « Chaque texte est transformé en liste de nombres : un mot pèse lourd s'il est
> fréquent dans ce texte et rare dans les autres. C'est TF-IDF. Ensuite, le cosinus
> mesure si deux listes "pointent dans la même direction", de 0 (rien en commun) à 1
> (identiques). Enfin, je combine cette ressemblance avec la note et la ville pour
> obtenir le score final. »
