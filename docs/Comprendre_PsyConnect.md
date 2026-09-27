# Comprendre PsyConnect — fonctionnalités expliquées

Notes de révision écrites en langage clair, pour maîtriser le projet avant la
soutenance. Chaque section explique ce que fait la fonctionnalité, comment elle
marche, ce qu'il y a d'intéressant dedans, et ses limites.

Mis à jour le 11/09/2026.

---

## 1. Xalaat — le compagnon IA

### L'idée

Quand on n'a jamais consulté de psychologue, le plus dur n'est pas de prendre
rendez-vous : c'est de savoir quoi dire une fois assis en face. Xalaat aide le
patient à mettre des mots sur ce qu'il ressent **avant** sa première séance.

Le nom vient du wolof et signifie « pensée, réflexion ».

Ce n'est pas un thérapeute, et l'application ne laisse jamais croire le
contraire : pas de diagnostic, pas de conseil médical, pas de substitution au
psychologue. Ces interdictions sont écrites noir sur blanc dans les
instructions données au modèle.

### Comment ça marche

Microservice dédié `ai-companion-service` (port 8087), route `/companion/**`.

Le modèle de langage tourne **en local** sur la machine, via Ollama. Modèle
actuel : `qwen2.5:3b`. Aucune clé API, aucun service tiers, aucune donnée de
santé qui sort de l'infrastructure.

Le microservice est séparé volontairement : si l'IA rame ou plante, les
rendez-vous, paiements et messages continuent de fonctionner.

### La confidentialité

Contrainte dure du projet : **rien n'est enregistré**.

- Pas de base de données côté serveur
- Le contrôleur ne journalise jamais le contenu des échanges
- Rien n'est sauvegardé non plus côté téléphone

La conversation existe seulement dans la mémoire de l'écran ouvert. On ferme,
ça disparaît. Techniquement, c'est le téléphone qui renvoie l'historique à
chaque message ; le serveur ne garde rien entre deux appels.

Seules les métadonnées de traçage (durée, statut HTTP) partent vers Zipkin,
jamais le corps de la requête.

### Où le trouver

Bannière dorée sur l'accueil patient, sous la bannière du journal. Pas d'accès
côté psychologue : le compagnon est pensé pour le patient avant sa première
consultation.

### Le bug corrigé

Xalaat échouait à chaque message. Cause : l'application coupe toute requête
après 15 secondes, alors que Mistral 7B mettait environ 3 minutes à répondre
sur un MacBook M1 8 Go (66 s de chargement du modèle, puis ~4 mots par
seconde).

Deux corrections : un délai d'attente dédié de 90 secondes pour Xalaat
uniquement, et le passage à un modèle plus léger, `qwen2.5:3b`.

---

## 2. Le garde-fou de Xalaat

### Le principe

Chaque message du patient passe d'abord par un filtre (`RiskDetectionService`).
S'il repère un signal de détresse, **l'IA n'est jamais appelée** : l'application
renvoie directement un message fixe, écrit à l'avance, toujours le même.

### Pourquoi ne pas juste demander à l'IA d'être prudente

C'est la question centrale, et il faut l'avoir en tête.

On peut écrire dans les instructions du modèle « si la personne va mal, oriente
vers les urgences ». Ça marche la plupart du temps. Mais ce n'est pas une
garantie : un modèle de langage est probabiliste, il peut dériver si
l'utilisateur insiste ou reformule.

Le filtre, lui, est **déterministe** : même entrée, même sortie, toujours. Sur
un sujet où une mauvaise réponse peut coûter une vie, on ne parie pas sur la
bonne volonté d'un modèle. On met une règle en dur.

### Comment le filtre fonctionne

Une liste d'environ 30 expressions liées au suicide et à l'automutilation :
« me suicider », « envie de mourir », « me faire du mal », « en finir avec ma
vie », « le monde irait mieux sans moi »...

Ce sont des motifs de recherche, donc une seule ligne couvre plusieurs
variantes. Exemple : `en finir avec (ma vie|tout|cette vie|l'existence|mes
jours)` attrape les cinq formulations d'un coup.

Avant comparaison, le message est **normalisé** : minuscules, accents retirés.
« Épuisé » et « epuise » donnent le même résultat, et une personne qui écrit
sans accents (courant sur téléphone) est quand même détectée.

Un seul motif qui correspond suffit : réponse de secours immédiate, appel à
l'IA purement sauté.

### Le message de secours

Fixe, dans `CompanionPrompts.SAFETY_FALLBACK_MESSAGE`. Il dit en substance : ce
que tu traverses est difficile, je ne suis pas la bonne ressource pour ça,
voici qui appeler.

Numéros sénégalais réels et vérifiés :

- SAMU : **1515** (gratuit, 24h/24)
- Numéro vert du ministère de la Santé (ligne générale, pas propre à la santé mentale) : **800 00 50 50**
- Police Secours : **17**
- Pompiers : **18**

Détail important : le message précise qu'en cas d'urgence forte, mieux vaut
**appeler directement** que réserver une consultation, parce qu'une réservation
n'est pas instantanée. Il se termine par « Tu n'es pas seul·e ».

Côté téléphone, cette réponse arrive avec une étiquette `flagged: true` qui dit
à l'écran d'afficher la bulle en doré avec une icône distincte. Objectif purement
visuel : que les numéros sautent aux yeux au lieu de se noyer dans le fil.

### Deux choix assumés

**Volontairement permissif.** Le filtre préfère se déclencher trop souvent que
pas assez. Un faux positif, c'est quelqu'un qui reçoit un message bienveillant
et des numéros utiles sans en avoir besoin — désagréable, sans plus. Un faux
négatif, c'est quelqu'un en détresse qui reçoit une réponse générique. Les deux
erreurs n'ont pas le même poids.

**Limites documentées.** Détection par mots-clés en français : ne couvre ni le
wolof, ni l'argot, ni les fautes volontaires, ni les formulations indirectes.
C'est un garde-fou, pas une détection clinique fiable.

### Les deux couches

1. Le filtre en dur, avant l'IA — garanti, couverture limitée aux expressions
   listées
2. Les instructions du modèle, qui lui demandent quand même d'orienter vers une
   aide professionnelle — plus souple, couvre ce que le filtre rate, sans
   garantie

Le prompt le dit explicitement au modèle : « En pratique ce cas est intercepté
avant même de t'atteindre par un filtre dédié, mais garde ce réflexe. »

C'est de la défense en profondeur : si la première barrière laisse passer, la
seconde rattrape souvent.

---

## 3. Présenter Xalaat en soutenance (2-3 minutes)

Le fil : **le problème humain → la solution → le risque → comment on l'a
neutralisé**. Le jury retient la fin, donc la sécurité est le point d'arrivée,
pas un détail au milieu.

### Temps 1 — Le problème (~20 s)

> Quand on n'a jamais consulté de psychologue, le plus dur n'est pas de prendre
> rendez-vous — c'est de savoir quoi dire une fois assis en face. Beaucoup de
> gens abandonnent à ce moment-là. On a donc ajouté un compagnon de
> préparation : il s'appelle Xalaat, un mot wolof qui veut dire « pensée,
> réflexion ».

Le nom wolof se place dès la première phrase. Il ancre le projet dans son
contexte sénégalais. Ne pas le garder pour la fin.

### Temps 2 — Ce que c'est (~30 s)

> Xalaat aide le patient à mettre des mots sur ce qu'il ressent avant sa
> première séance. Ce n'est pas un thérapeute et l'application ne laisse jamais
> penser le contraire : ni diagnostic, ni conseil médical, ni substitution au
> psychologue. C'est un microservice dédié, avec un modèle de langage open
> source qui tourne en local via Ollama — donc aucune donnée de santé ne sort
> de l'infrastructure.

Trois arguments en une phrase : microservice isolé, modèle local, souveraineté
des données. Aucun n'est développé. Si le jury veut, il demandera.

### Temps 3 — Le risque, posé franchement (~25 s)

> Mettre une IA en face de quelqu'un qui va mal pose un vrai problème : que se
> passe-t-il si la personne exprime des idées suicidaires ? On peut écrire dans
> les instructions du modèle « oriente vers les urgences ». Mais un modèle de
> langage reste probabiliste — il peut dériver si l'utilisateur insiste ou
> reformule. Sur ce sujet-là, « ça marche la plupart du temps » n'est pas
> acceptable.

C'est le moment fort. Ralentir, marquer un temps avant « n'est pas acceptable ».

### Temps 4 — La réponse technique (~45 s)

> On a donc mis un filtre déterministe avant l'appel au modèle. Chaque message
> est analysé ; s'il contient un signal de détresse, l'IA n'est pas appelée du
> tout — l'application renvoie directement un message fixe avec les numéros
> d'urgence sénégalais vérifiés : le SAMU au 1515 et le numéro vert
> du ministère de la Santé, le 800 00 50 50. Ce message n'est jamais généré par
> l'IA, donc il ne peut pas varier. Sur ce chemin-là, il n'y a plus aucune part
> de hasard.

Mot à ne pas rater : **déterministe**. Définition si on la demande : même
entrée, même sortie, toujours.

### Temps 5 — La limite, assumée (~20 s)

> La détection se fait par expressions-clés en français. Elle ne couvre ni le
> wolof, ni l'argot, ni les formulations indirectes — c'est un garde-fou, pas
> une détection clinique. On l'a calibrée volontairement permissive : mieux
> vaut afficher des numéros utiles à quelqu'un qui n'en avait pas besoin que de
> rater quelqu'un qui en avait besoin. L'extension au wolof est la première
> évolution prévue.

Ne jamais sauter ce paragraphe. Une limite annoncée soi-même est une preuve de
maîtrise ; la même limite trouvée par le jury devient une faille.

### Support visuel

Une capture de la bulle dorée avec les numéros d'urgence vaut mieux que trois
phrases. Pour une démo live, Ollama doit tourner — à tester avant, sinon c'est
90 secondes de silence en pleine soutenance. Le plus sûr : capture d'écran dans
les slides, démo live seulement si le jury la demande.

### Les questions du jury

**« Pourquoi pas ChatGPT, ce serait plus performant ? »**
Données de santé mentale. Les envoyer chez un tiers étranger pose un problème
de confidentialité et de conformité. Un modèle local est moins performant, mais
rien ne sort de l'infrastructure. Sur ce cas d'usage, c'est le bon arbitrage.

**« Votre filtre par mots-clés, c'est un peu rudimentaire, non ? »**
Assumer, ne pas se défendre. C'est rudimentaire et c'est voulu : la simplicité
est ce qui garantit la fiabilité. Un classifieur entraîné serait plus fin mais
redeviendrait probabiliste, donc faillible sur le cas exact qu'on veut
sécuriser. Le filtre est la garantie plancher, les instructions du modèle
rattrapent ce qu'il laisse passer. Deux couches, pas une.

**« Et si l'utilisateur écrit en wolof ? »**
Le filtre ne détecte pas, c'est identifié. Mais le modèle reçoit quand même
l'instruction d'orienter vers une aide professionnelle. La couverture est
dégradée, pas nulle. Enrichir la liste en wolof est la première évolution
prévue.

**« Vous engagez votre responsabilité si quelqu'un se fait du mal ? »**
Rester calme et factuelle. Xalaat ne se présente jamais comme un professionnel
de santé, le rappelle explicitement, et le cas de détresse renvoie
systématiquement vers les urgences. L'application oriente vers de vrais
psychologues : c'est tout l'objet de PsyConnect.

### Deux pièges

**Ne pas survendre.** Jamais « Xalaat détecte les personnes à risque ». Dire
« Xalaat intercepte certaines formulations explicites ». La première phrase est
fausse et un jury attentif la relèvera.

**Ne pas réciter.** Retenir les cinq temps et les deux mots-clés (*déterministe*,
*avant l'appel au modèle*), pas les phrases. Un discours appris par cœur
s'entend, et si on perd le fil on perd tout.

---

## 4. Le moteur de recommandation

Attention : deux choses portent ce nom dans le projet. Celle-ci suggère des
psychologues au patient. L'autre (section 4.6) est un conseil donné par le psy
après une séance.

### Ce que ça fait

Sur l'accueil patient, une liste de psychologues s'affiche. Elle n'est ni
aléatoire ni alphabétique : elle est classée selon ce que le patient a
renseigné dans son profil.

Service à part, `ml-service`, écrit en **Python** (FastAPI) — le seul service
non-Java du projet. Une seule adresse : `/recommendations/{id_patient}`, qui
renvoie les 5 meilleurs psys.

### Le trajet d'une demande

1. `patient_home_screen.dart` (`_load()`) appelle
   `PsychologistService.getRecommendations(patientId, topN: 5)`.
2. La requête part vers la passerelle : `GET /recommendations/12?top_n=5`, avec
   le jeton du patient.
3. La passerelle la transmet à `ml-service` par une **adresse fixe**
   (`ML_SERVICE_URL`, route [9]) et non par `lb://` : le service Python n'est
   pas inscrit dans Eureka. Choix assumé — pas de client Eureka Python à
   maintenir pour un seul service.
4. `ml-service` (`app/main.py`) fait deux appels vers `user-service`, **en
   repassant par la passerelle** comme le ferait l'application :
   - `GET /patients/12` → le profil du patient ;
   - `GET /psychologists?verifiedOnly=true` → les psys validés par l'admin.
5. Il n'a pas de compte à lui : il **relaie le jeton du patient** tel quel
   (`app/user_service_client.py`). Sans ça, `user-service` répondrait 403.
6. Il calcule le classement (`app/recommender.py`) et renvoie la liste.

### Comment ça marche

L'idée de base : transformer du texte en nombres pour pouvoir comparer.

**Étape 1 — Fabriquer deux textes.**
Côté patient : langue préférée + le champ `medicalHistory`.
Côté psy : spécialité + bio + langues parlées.

Piège de nom à connaître : malgré son nom, `medicalHistory` **n'est pas** la
fiche d'antécédents médicaux. C'est le champ « Ce que vous recherchez » saisi à
l'inscription (ex. *« anxiété liée au travail »*) et modifiable dans le profil.
Les vrais antécédents (allergies, traitements, histoire psychiatrique) sont
dans une autre table, `MedicalHistory`, que le moteur **ne lit jamais**.
C'est un bon argument : on ne fait pas passer de données cliniques dans un
calcul de classement.

**Étape 2 — Nettoyer.**
Minuscules, accents retirés (« anxiété » devient « anxiete »), et on jette les
mots vides (*le, la, des, pour, avec*). Ces mots sont partout, donc ils ne
distinguent rien ; les garder fausserait la comparaison.

**Étape 3 — Peser chaque mot : le TF-IDF.**
Le nom fait peur, l'idée est simple : un mot compte d'autant plus qu'il est
rare.

- *TF* : combien de fois le mot apparaît dans ce texte, divisé par la longueur
  du texte. Un psy qui écrit trois fois « anxiété » dans sa bio, c'est
  probablement son domaine.
- *IDF* : à l'inverse, si tous les psys écrivent « psychologue », ce mot ne
  permet de choisir personne. Son poids s'effondre.

Chaque texte devient une liste de nombres, un par mot du vocabulaire. Le mot
« traumatisme » a un poids fort chez le psy spécialisé et zéro chez les autres.

**Étape 4 — Mesurer la ressemblance : le cosinus.**
Chaque texte est une flèche qui pointe dans une direction. Deux textes qui
parlent de la même chose pointent dans la même direction ; deux textes sans
rapport pointent ailleurs. Le cosinus mesure l'angle et le traduit en un nombre
entre 0 et 1. **0 = rien en commun, 1 = identique.**

**Étape 5 — Mélanger trois signaux.**

```
score = 0,6 × ressemblance + 0,25 × (note du psy / 5) + 0,15 × même_ville
```

Soit 60 % pertinence, 25 % réputation, 15 % proximité. `même_ville` vaut 1 si
le patient et le psy sont dans la même ville (accents et majuscules ignorés),
0 sinon. Les trois poids font 1, donc le score reste entre 0 et 1. Ils sont
réglables sans toucher au code (`CONTENT_WEIGHT`, `RATING_WEIGHT`,
`CITY_WEIGHT` dans `app/config.py`). Tri par score décroissant, les 5 premiers
sont renvoyés.

Pourquoi la ville est à part et pas dans le texte : c'est un signal de
contexte, pas de contenu. Mise dans le TF-IDF, « Dakar » concurrencerait
« anxiété ». Et c'est un **bonus, jamais un filtre** : les séances peuvent se
faire en visio, donc un bon psy d'une autre ville reste proposé.

### Un exemple chiffré (calculé avec le vrai code)

Patient : langue *Français*, recherche *« anxiété liée au travail »*, ville
*Dakar*. Après nettoyage : `francais anxiete liee travail`.

| Psy | Spécialité | Ville | Note | Ressemblance | Score |
|---|---|---|---|---|---|
| A | Anxiété et stress (bio : stress au travail) | Dakar | 4,0 | 0,37 | **0,57** |
| B | Thérapie de couple | Dakar | 5,0 | 0,11 | 0,47 |
| C | Anxiété (parle wolof) | Thiès | 4,5 | 0,12 | 0,29 |
| D | Dépression — indisponible | Dakar | 3,0 | — | écarté |

Calcul pour A : 0,6 × 0,37 + 0,25 × 4/5 + 0,15 × 1 = 0,22 + 0,20 + 0,15 = 0,57.

À remarquer : B passe devant C alors que C est spécialiste de l'anxiété. B
partage le mot « français », est à Dakar et a 5 étoiles ; C ne partage que
« anxiété ». C'est le comportement voulu par les poids, mais un jury attentif
peut le relever — voir « Le point fragile ».

### Quatre détails bien pensés

**Seuls les psys validés et disponibles sont candidats.** Le service demande
`verifiedOnly=true` (un psy en attente ou refusé par l'admin n'est jamais
recommandé), puis écarte ceux marqués `available=false`, avant tout calcul.

**Le démarrage à froid est géré.** Un nouveau patient qui n'a rien rempli
produit un texte vide, donc une ressemblance de 0 partout. Le score se réduit
alors à la note, plus le bonus ville s'il l'a renseignée. Il voit les mieux
notés, près de chez lui en premier. Pas d'écran vide, pas de plantage. Savoir
nommer ce cas (« cold start ») fait bonne impression.

**Filet côté application.** Si `ml-service` ne répond pas (ou renvoie une liste
vide), `patient_home_screen.dart` prend la liste des psys validés, la trie par
note et garde les 5 premiers. Le patient ne voit pas la panne.

**Le service est testé.** `tests/test_recommender.py` : 12 tests, tous passent
(accents, cosinus, exclusion des indisponibles, démarrage à froid, bonus ville).
C'est la partie la mieux testée hors Java.

### Le point fragile — à connaître avant le jury

`ml-service` s'appelle « ML », mais **il n'y a aucun apprentissage dedans**. Pas
de modèle entraîné, pas de données historiques, rien qui s'améliore avec
l'usage. C'est un calcul de similarité pur : mêmes profils en entrée, même
résultat aujourd'hui comme dans six mois.

TF-IDF et le cosinus sont des techniques classiques de **recherche
d'information**, pas d'apprentissage automatique. Elles sont enseignées en cours
de ML, ce qui explique la confusion, mais ce n'est pas la même famille.

Dire « j'ai un service de machine learning » sans nuance, c'est offrir au jury
sa question suivante : « et il apprend quoi, exactement ? »

**La formulation qui protège :**

> J'ai un service de recommandation par filtrage de contenu, en TF-IDF et
> similarité cosinus. Ce n'est pas de l'apprentissage — il n'y a pas de modèle
> entraîné — c'est un calcul de similarité déterministe. Je l'ai choisi parce
> qu'au démarrage d'une plateforme, il n'y a pas d'historique de consultations
> sur lequel entraîner quoi que ce soit. Un système par apprentissage aurait
> été vide le premier jour ; celui-ci fonctionne dès le premier patient.

Cette réponse est bien meilleure qu'une défense de « c'est quand même du ML ».
Elle montre qu'on connaît la différence **et** que le choix était motivé par une
contrainte réelle.

**Deux autres limites à dire avant qu'on te les dise :**

- *Les mots doivent coïncider.* TF-IDF compare des mots, pas des idées :
  « angoisse » ne rapproche pas d'« anxiété ». Des synonymes ou des
  plongements de mots (*embeddings*) corrigeraient ça.
- *Les poids sont choisis, pas appris.* 0,6 / 0,25 / 0,15 sont des valeurs
  raisonnées, pas mesurées. L'exemple ci-dessus montre qu'ensemble, note et
  ville (40 %) peuvent passer devant la spécialité. Avec de l'historique, on
  pourrait les ajuster sur les réservations réellement faites.

**Perspective d'évolution** : quand la plateforme aura de l'historique (qui a
consulté qui, qui est resté en suivi), on pourra passer au **filtrage
collaboratif**, qui lui apprend vraiment. On ouvre la porte sans prétendre
l'avoir franchie.

### 4.6 L'autre « recommandation »

Rien à voir : ce sont les recommandations post-séance. Le psy, après une
consultation, donne un conseil ou un exercice à son patient
(`SessionRecommendation`, dans `appointment-service`). Le patient les voit sur
son accueil et peut les cocher comme faites. Purement humain, aucun calcul.
Côté passerelle, elles passent par `/session-recommendations/**` justement pour
ne pas entrer en conflit avec `/recommendations/**`, réservé à `ml-service`.

---

## 5. Les questionnaires PHQ-9 et GAD-7

### L'idée

Un psychologue ne peut pas se fier uniquement à « comment vous sentez-vous ? ».
Il lui faut une mesure chiffrée, comparable d'une séance à l'autre.

Deux standards internationaux :

- **PHQ-9** → dépression, 9 questions, score 0 à 27
- **GAD-7** → anxiété, 7 questions, score 0 à 21

Chaque question se répond sur la même échelle en 4 niveaux (échelle de
Likert) : *Jamais (0)*, *Plusieurs jours (1)*, *Plus de la moitié des jours
(2)*, *Presque tous les jours (3)*. On additionne.

Ces questionnaires ne sont pas inventés pour le projet, et c'est l'argument :
des instruments validés cliniquement plutôt qu'un test maison.

### Le parcours

Le psy ouvre la fiche d'un patient et envoie un questionnaire. Le patient reçoit
une notification, le remplit sur son téléphone. Dès qu'il valide, le psy reçoit
le score **et** son interprétation.

Seuils officiels du PHQ-9 : 0-4 minimale, 5-9 légère, 10-14 modérée, 15-19
modérément sévère, 20+ sévère.

Le psy ne reçoit pas « score : 16 » tout sec, mais « 16/27, dépression
modérément sévère ». La différence entre une donnée brute et une information
exploitable.

### Ce qui est bien fait

**Le serveur ne fait confiance à personne.** Chaque opération vérifie le rôle :
seul un psy envoie, seul un patient répond. Et pas n'importe quel patient — la
requête cherche le questionnaire par son identifiant **et** par l'identifiant du
patient connecté. Si ça ne correspond pas, il n'existe pas. Sans ça, quelqu'un
pouvant deviner un numéro pourrait répondre à la place d'un autre ou lire ses
réponses.

**Les réponses sont vérifiées une par une** : le bon nombre (9 ou 7), et chaque
valeur entre 0 et 3. Un score calculé sur des données invalides est pire que pas
de score : il donne une fausse confiance à un professionnel qui va décider
dessus.

**On ne répond qu'une fois.** Si le questionnaire est déjà complété, l'opération
est refusée. La mesure reste datée et comparable : deux passages sont deux
questionnaires distincts.

**L'anonymat tient jusque dans les notifications.** Avant d'écrire le prénom du
patient, le code vérifie si celui-ci a activé le mode anonyme. Si oui, la
notification dit « Votre patient(e) ». Le respect de l'anonymat n'est pas
seulement dans l'écran principal.

**Les notifications ne cassent pas l'essentiel.** L'envoi est entouré d'un
`try/catch` qui ignore l'erreur : si le service de notifications est en panne, le
questionnaire est quand même enregistré et le score quand même calculé. Même
logique de « tomber en marche » que dans le reste du projet.

### Le vrai sujet : la question 9

La neuvième question du PHQ-9 ne ressemble à aucune autre. Elle demande, en
substance, si la personne a eu des pensées qu'elle serait mieux morte ou de se
faire du mal. C'est la question d'idéation suicidaire.

Dans un simple total, elle pèse **exactement autant** que « avez-vous mal
dormi ». Conséquence : quelqu'un pouvait répondre « presque tous les jours » à
la question 9, avoir un score global bas parce que le reste allait à peu près,
et **il ne se passait rien**. Le psy voyait « dépression légère » et passait à
autre chose.

Le filet ne regarde plus le total. Il regarde **cette question isolément** : dès
que la réponse est à 2 ou plus, deux choses se déclenchent.

**Côté patient** : une carte de soutien apparaît pendant la saisie, juste sous
la question — pas à la fin. Non bloquante (il continue s'il veut), avec un
bouton « Parler à quelqu'un maintenant » qui mène à l'écran d'urgence.

**Côté psy** : dans la liste des questionnaires du patient, la ligne est
encadrée en rouge avec la mention « Idées suicidaires signalées (item 9) — à
traiter en priorité ». Impossible de passer à côté.

Point remarquable : tout a été fait **côté application, sans toucher au
serveur**. Les réponses détaillées étaient déjà renvoyées par l'interface, il
suffisait de les lire au bon endroit. Le correctif le plus important du projet a
coûté le moins de code.

### La limite honnête

Deux questionnaires seulement, et **codés en dur**. Un troisième demanderait de
toucher une demi-douzaine d'endroits (type côté serveur, calcul du score,
seuils, questions côté application). Ce n'est pas extensible.

C'est un arbitrage, pas un oubli : empiler des questionnaires ne démontre rien
de plus, et le temps a été mis sur la question 9. Le dire comme ça si on
demande.

Si un troisième devait arriver, l'EPDS (dépression post-partum) aurait le plus
de sens ici, vu l'enjeu de santé maternelle au Sénégal — plus pertinent qu'une
énième échelle générique. Son item 10 porte aussi sur l'auto-agression, donc le
filet devrait être étendu.

---

## 6. Le solde et le circuit de l'argent

### Pourquoi un solde plutôt qu'un paiement direct

Au départ, le patient payait sa séance par Wave ou Orange Money. Problème à
l'annulation : l'écran affichait « le paiement a été remboursé » et rien ne
bougeait. Aucun mouvement visible nulle part.

D'où le changement, inspiré de Yassir Pay : **le patient a un solde dans
l'application**. Il le recharge via Wave ou Orange Money, paie ses séances
depuis ce solde, et tout remboursement le recrédite — visiblement,
immédiatement, avec un montant qui change à l'écran.

Meilleure conception, et pas seulement pour l'affichage : ça découple le
paiement de l'opérateur. La séance se paie en interne, et l'application ne
parle à Wave qu'au moment de la recharge ou du retrait. Deux problèmes séparés
au lieu d'un seul emmêlé.

À dire clairement en soutenance : **les opérateurs sont simulés**. Aucune
intégration réelle. C'est une maquette fonctionnelle du circuit financier.
L'annoncer soi-même évite la question gênante.

### Le circuit

**Recharge** → le patient choisit Wave, Orange Money ou carte, saisit un
montant, son solde augmente.

**Paiement** → il paie sa séance, son solde diminue. Le moyen de paiement
enregistré est toujours `WALLET`, jamais l'opérateur, parce que l'opérateur n'a
servi qu'à la recharge.

**Annulation** → son solde remonte du montant remboursé.

**Côté psy** → il ne touche pas au solde patient. Il a son propre revenu,
calculé à partir des paiements encaissés, dont il peut demander le retrait vers
Wave ou Orange Money.

**La commission** : la plateforme prend 20 % par défaut, réglable par l'admin.
Le psy voit deux chiffres, le brut encaissé et le net qui lui revient. Le calcul
est identique partout dans le code, pour que l'admin et le psy ne voient jamais
deux montants différents pour la même chose.

### Les cinq conditions avant qu'un franc bouge

Quand le patient appuie sur « Payer », le serveur vérifie, dans cet ordre :

1. C'est bien son rendez-vous ?
2. Il n'est pas annulé ou refusé ?
3. Il est confirmé par le psy ? (on ne paie pas une demande en attente)
4. Il n'est pas déjà payé ?
5. Le solde suffit ?

Elles sont cumulatives : une seule qui manque, le paiement est refusé.

### Le montant n'est pas au choix

Point à ne pas confondre. Le montant du paiement est **fixé par le
psychologue** : c'est son tarif. Le patient voit « Payer 22 000 F CFA » et
appuie. Il ne saisit rien.

Le choix du montant existe ailleurs, au moment de la **recharge** : là, le
patient tape ce qu'il veut mettre et choisit l'opérateur.

- **Recharge** → montant choisi, opérateur choisi
- **Paiement** → montant imposé, aucun choix, un seul bouton

### Le double paiement

Bug réel : le bouton « Payer » pouvait débiter deux fois le même rendez-vous. Un
doigt nerveux, deux appuis rapprochés, deux débits.

Deux corrections possibles, qui ne se valent pas.

**Côté application** : désactiver le bouton après le premier appui. Ça marche
pour un vrai double-tap et c'est agréable, mais ça ne protège de rien de
sérieux — l'application peut planter, quelqu'un peut appeler l'interface
directement.

**Côté serveur** : avant tout débit, chercher s'il existe déjà un paiement
terminé pour ce rendez-vous. Si oui, refuser. Cette vérification-là, personne ne
peut la contourner.

Les deux ont été faites, mais elles n'ont pas le même statut. Formule à
retenir : **une vérification côté client est une politesse, une vérification
côté serveur est une règle.**

### Le débit sans paiement, et la compensation

Le passage le plus intéressant, né d'un incident réel.

Le paiement se fait en deux temps :

1. Débiter le solde du patient — mais le solde vit dans **un autre service**,
   sur **une autre base de données**
2. Enregistrer le paiement — ça, c'est local

Un jour, l'étape 2 a échoué à cause d'une contrainte oubliée en base. Le solde
est passé de 33 000 à 11 000 francs et **aucun paiement n'a été enregistré**.
L'argent avait disparu.

Dans une application classique, une transaction annule tout en cas d'échec :
c'est le « tout ou rien » des bases de données. Ici, le débit s'est passé dans
une base qui n'est pas la nôtre, il est déjà validé chez elle. Impossible de
revenir en arrière. **C'est le problème central des microservices** : on perd la
transaction unique.

La solution s'appelle la **compensation**. Puisqu'on ne peut pas annuler, on
fait l'opération inverse : si l'enregistrement échoue après le débit, le code
**recrédite automatiquement** le solde du patient, puis relaie l'erreur. Le
patient voit un message d'échec, mais son argent est revenu.

Un cran plus loin : si le recrédit échoue lui aussi, ça part dans les logs en
niveau ERROR avec le numéro du rendez-vous. À ce stade, seul un humain peut
rattraper — autant lui laisser exactement l'information dont il a besoin.

C'est un **saga pattern**, version simple. Terme à retenir : *cohérence par
compensation*.

### Le détail qui montre la nuance

Différence de traitement entre deux échecs :

- L'**enregistrement du paiement** échoue → compensation, on rend l'argent
- La **notification** échoue → on logge un avertissement et on continue

Pourquoi cette asymétrie ? Un paiement non enregistré est une perte d'argent ;
un message non envoyé est un désagrément. Annuler un paiement valide parce
qu'une notification n'est pas partie, ce serait faire payer au patient une panne
qui ne le concerne pas.

Chaque échec est traité selon ce qu'il coûte. Même raisonnement que les trois
filets de sécurité côté rendez-vous : tomber en marche ou tomber fermé, selon
l'enjeu.

### Deux limites à assumer

**Le remboursement rend l'intégralité au patient**, commission comprise. Dans un
vrai système, la plateforme retiendrait probablement quelque chose sur une
annulation tardive. Choix de simplicité, pas oubli.

**Les opérateurs sont simulés.** La référence de transaction est un identifiant
aléatoire préfixé `SIM-`. Le préfixe est honnête : le code ne prétend pas être
connecté à quoi que ce soit.

### Résumé oral du circuit de paiement

> Une fois que le psychologue a confirmé le rendez-vous, le patient peut payer.
> Le montant est celui du psychologue, il n'a rien à saisir — juste un bouton.
> Le paiement se fait depuis son solde PsyConnect, qu'il a rechargé avant via
> Wave ou Orange Money.
>
> Avant que le moindre franc bouge, le serveur vérifie cinq choses : que le
> rendez-vous lui appartient, qu'il est confirmé par le psy, qu'il n'est ni
> annulé ni refusé, qu'il n'est pas déjà payé, et que le solde suffit. Une seule
> qui manque, le paiement est refusé.
>
> Le double paiement est bloqué à deux niveaux. Côté application, le bouton se
> désactive au premier appui — mais ça, c'est du confort. La vraie garantie est
> côté serveur : il refuse s'il trouve déjà un paiement enregistré pour ce
> rendez-vous.
>
> Le point délicat, c'est que le solde vit dans un service et le paiement dans
> un autre. Je ne peux donc pas faire une transaction unique qui annulerait tout
> en cas d'échec. Ça m'est arrivé en test : le solde débité, le paiement jamais
> enregistré, l'argent disparu. Comme je ne peux pas annuler le débit, je fais
> l'opération inverse — le code recrédite automatiquement le patient. C'est de
> la cohérence par compensation.

---

## 7. Vocabulaire à ne pas confondre

**Compensation** ≠ **remboursement**

- *Compensation* : une panne technique, rattrapée automatiquement par le code
  (débit sans paiement enregistré)
- *Remboursement* : une règle métier, le patient annule un rendez-vous payé et
  son solde est recrédité

Ne pas les confondre devant le jury : la compensation est le meilleur argument
technique de la partie paiement, et l'appeler « remboursement » la fait perdre.

**Recharge** ≠ **paiement**

- *Recharge* : montant choisi par le patient, opérateur choisi
- *Paiement* : montant imposé par le tarif du psy, aucun choix

**« Détecter »** ≠ **« intercepter »**

Ne jamais dire « Xalaat détecte les personnes à risque ». Dire « Xalaat
intercepte certaines formulations explicites ». La première affirmation est
fausse.

**« Machine learning »** ≠ **« recommandation par similarité »**

`ml-service` ne fait aucun apprentissage. Dire « filtrage de contenu, TF-IDF et
similarité cosinus » et préciser que ce n'est pas de l'apprentissage.

---

## 8. Le fil rouge

Deux mécanismes de sécurité dans le projet, techniquement sans rapport, qui
racontent la même chose :

- Le **garde-fou de Xalaat**, qui intercepte avant l'IA
- Le **filet de l'item 9** du PHQ-9, qui isole la question d'idéation suicidaire

À chaque fois qu'un chemin pouvait croiser une détresse réelle, une porte de
sortie vers de l'aide humaine a été ajoutée. Ce n'est pas deux fonctionnalités,
c'est une ligne de conduite — et ça se raconte comme tel en soutenance.

---

## 9. Glossaire — le vocabulaire du projet

Termes à maîtriser, regroupés par domaine. La glose entre parenthèses sert
seulement à lever l'ambiguïté quand le mot a plusieurs sens courants.

### Architecture

Microservice · Monolithe · Annuaire de services (Eureka) · Passerelle d'API
(gateway) · Couplage / découplage · Hétérogénéité technologique · Point de
défaillance unique (SPOF) · Scalabilité horizontale

### Résilience

Tolérance aux pannes · Disjoncteur (circuit breaker) · Repli (fallback) ·
Nouvelle tentative (retry) · Dégradation de service · Tomber en marche /
tomber fermé (fail-open / fail-safe) · Délai d'expiration (timeout) · Traçage
distribué (Zipkin)

### Données et cohérence

Transaction ACID · Atomicité · Validation / annulation (commit / rollback) ·
Une base par service · Cohérence forte vs cohérence à terme (eventual
consistency) · Saga · Compensation · Commit en deux phases (2PC) · Théorème
CAP · Idempotence (rejouer une opération sans effet supplémentaire — le vrai
nom du mécanisme anti-double-paiement) · Contrainte d'intégrité · Migration de
schéma · Problème N+1

### API et échanges

REST · Point d'entrée (endpoint) · Verbes HTTP · Codes de statut (401, 402,
403, 404, 503) · DTO · Sérialisation / désérialisation · Corps de requête
(payload) · Contrat d'API · Appel inter-services

### Sécurité

Authentification vs autorisation (deux choses différentes) · Jeton JWT ·
Revendications (claims) · Contrôle d'accès par rôle (RBAC) · Vérification de
propriété (ownership) · Hachage vs chiffrement (à ne jamais confondre) ·
Chiffrement en transit / au repos · TLS · Pseudonymisation vs anonymisation ·
Surface d'attaque · Validation côté serveur · Limitation de fréquence (rate
limiting) · Loi n°2008-12 · CDP · RGPD

### IA et Xalaat

Modèle de langage (LLM) · Inférence locale · Prompt système · Garde-fou
(guardrail) · Déterministe vs probabiliste · Expression régulière (regex) ·
Normalisation de texte · Faux positif / faux négatif · Hallucination · Défense
en profondeur · Jetons (tokens) · Souveraineté des données

### Recommandation

Filtrage de contenu · Filtrage collaboratif · TF-IDF · Similarité cosinus ·
Vectorisation · Mots vides (stop words) · Tokenisation · Démarrage à froid
(cold start) · Pondération

### Clinique

Échelle de Likert · PHQ-9 · GAD-7 · EPDS · Instrument psychométrique validé ·
Seuils de sévérité · Idéation suicidaire · Triage

### Mobile

Flutter · Dart · Widget · Gestion d'état (Provider) · Reconstruction (rebuild) ·
Jetons de design (design tokens) · Multiplateforme

### Exploitation

Docker · Conteneur · Image · Build (Gradle) · Variables d'environnement ·
Niveaux de log (WARN, ERROR)

### Qualité

Test unitaire · Test d'intégration · Bouchon (mock) · Couverture de tests ·
Dette technique · Refactoring · Régression

### Les six à réviser en priorité

Ceux qui reviennent le plus dans le projet, et ceux où une confusion se voit
immédiatement :

1. **Transaction ACID** — au sens base de données, pas au sens paiement
2. **Cohérence à terme** — l'alternative quand la transaction unique est
   impossible
3. **Compensation** — l'opération inverse, faute de pouvoir annuler
4. **Idempotence** — rejouer sans effet supplémentaire
5. **Authentification vs autorisation** — qui tu es, vs ce que tu as le droit
   de faire
6. **Hachage vs chiffrement** — un chiffrement se déchiffre, un hachage non

Les deux derniers sont des pièges classiques de jury. « J'ai chiffré les mots
de passe » fait tiquer : on ne chiffre pas un mot de passe, on le hache, parce
qu'on ne doit jamais pouvoir le retrouver.
