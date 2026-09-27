# 02 — La recommandation de psychologues (ml-service)

Cette fiche suit le code de `backend/ml-service` tel qu'il est aujourd'hui. Tout ce qui est écrit ici a été vérifié dans les fichiers, et les exemples chiffrés ont été obtenus en exécutant le vrai `recommender.py`. Les points qui dépendent de user-service, de la passerelle et de Flutter ont aussi été vérifiés dans leur code (section 11).

---

## 1. Le service en une phrase

`ml-service` reçoit un identifiant de patient et renvoie les psychologues qui lui correspondent le mieux, classés par un score entre 0 et 1.

C'est du **filtrage par contenu** : on compare le texte du profil patient au texte du profil de chaque psy. Il n'y a pas d'entraînement, pas de données d'historique, pas de modèle sauvegardé. Tout est recalculé à chaque requête.

## 2. Les fichiers

| Fichier | Lignes | Rôle |
|---|---|---|
| `app/main.py` | 77 | L'API FastAPI : endpoints `/health` et `/recommendations/{patient_id}` |
| `app/recommender.py` | 189 | Le moteur : nettoyage du texte, TF-IDF, cosinus, score final |
| `app/user_service_client.py` | 70 | Les appels HTTP vers user-service, via la passerelle |
| `app/schemas.py` | 32 | La forme de la réponse JSON (Pydantic) |
| `app/config.py` | 21 | Les réglages, lus dans les variables d'environnement |
| `tests/test_recommender.py` | 204 | 12 tests du moteur |
| `requirements.txt` | 5 | fastapi, uvicorn, httpx, pydantic, numpy |
| `Dockerfile` | 12 | Image `python:3.12-slim`, port 8000 |

Il n'y a pas de scikit-learn : le TF-IDF et le cosinus sont écrits à la main avec numpy.

## 3. Où il se place dans l'architecture

```
App Flutter
   │  GET /recommendations/{patientId}?top_n=5   + Authorization: Bearer <jeton>
   ▼
API Gateway (8080) ── route fixe /recommendations/** ──► ml-service (8000)
                                                            │
                        ┌───────────────────────────────────┤
                        │ GET /patients/{id}                │ GET /psychologists?verifiedOnly=true
                        ▼                                   ▼
                 API Gateway ──────────► user-service ◄──── API Gateway
```

Trois choix à savoir expliquer :

**Pas d'Eureka.** Le service est écrit en Python et ne s'enregistre pas dans l'annuaire. La passerelle le joint par une adresse fixe : `ML_SERVICE_URL`, route [9] de `api-gateway/application.properties`, et non `lb://` comme les services Java. Maintenir un client Eureka en Python n'apportait rien pour un MVP.

**Il repasse par la passerelle.** Pour lire les données, il appelle `GATEWAY_URL` (`config.py`, ligne 7) et non user-service en direct. Il se comporte exactement comme l'app Flutter.

**Il n'a pas de jeton à lui.** Il récupère l'en-tête `Authorization` du patient (`main.py`, lignes 41-44) et le renvoie tel quel à user-service (`user_service_client.py`, fonction `_auth_headers`). C'est donc user-service qui décide si l'appelant a le droit de lire ce profil ; ml-service ne vérifie pas le jeton lui-même.

## 4. Le trajet d'une requête, étape par étape

### Étape 1 — Réception (`main.py`, `get_recommendations`)

- `patient_id` vient de l'URL.
- `top_n` vaut 5 par défaut (`DEFAULT_TOP_N`) et doit rester entre 1 et 20 (`ge=1`, `le=MAX_TOP_N`). Hors de ces bornes, FastAPI répond 422 sans rien exécuter.
- `authorization` est l'en-tête du jeton, facultatif au niveau de FastAPI.

### Étape 2 — Récupération des données (`user_service_client.py`)

Deux appels, l'un après l'autre :

1. `fetch_patient_profile` → `GET /patients/{id}`
2. `fetch_psychologists` → `GET /psychologists?verifiedOnly=true`

Le paramètre `verifiedOnly=true` garantit qu'un psy non approuvé ou refusé par l'admin n'est jamais proposé, quel que soit son score.

Chaque appel a un délai maximum de 5 secondes (`HTTP_TIMEOUT_SECONDS`).

Traduction des erreurs (`main.py`, lignes 50-56) :

| Ce qui se passe côté user-service | Ce que renvoie ml-service |
|---|---|
| 404 sur le patient | 404 « Patient X non trouvé » |
| Pas de réponse, délai dépassé, erreur réseau | 502 « user-service indisponible » |
| Tout autre code que 200 (401, 403, 500…) | 502 « user-service indisponible : Réponse inattendue (code) » |

À noter : un refus d'accès (403) ressort en 502, pas en 403. La sécurité est bien appliquée puisque user-service refuse, mais le code d'erreur final est trompeur. C'est une limite connue.

### Étape 3 — Filtrer les disponibles (`recommender.py`, ligne 147)

On ne garde que les psys dont `available` est vrai. Si le champ est absent, le psy est considéré comme disponible (`p.get("available", True)`). S'il n'en reste aucun, on renvoie une liste vide.

Il y a donc **deux filtres** successifs : l'approbation admin (côté user-service) et la disponibilité (côté ml-service).

### Étape 4 — Construire les textes

- Patient (`build_patient_query`) : `preferredLanguage` + `medicalHistory`
- Psy (`build_psychologist_content`) : `specialty` + `bio` + `languages`

Un champ vide ou absent devient une chaîne vide, sans erreur.

**Piège de nom : `medicalHistory` n'est pas le dossier médical.** Ce champ texte est rempli par la case « Ce que vous recherchez » de l'inscription (exemple affiché : « anxiété liée au travail, gestion du stress »), modifiable ensuite dans « Modifier le profil ». Les vrais antécédents structurés (allergies, maladies chroniques, traitements, antécédents psychiatriques) sont dans une autre table, `MedicalHistory`, servie par `/patients/{id}/medical-history`, que ml-service ne lit jamais.

Côté langues : le patient choisit dans une liste fixe (Français, Wolof, Anglais — `profile_constants.dart`), le psy tape ses langues librement (indication affichée : « Ex : Français, Wolof »). Grâce au nettoyage de l'étape 5, « Français » et « francais » se rejoignent.

La ville n'est **pas** dans ces textes. Elle est traitée à part (étape 7) : c'est une information de contexte, pas de contenu, et si on l'avait mise dans le texte, « dakar » aurait pesé autant que « anxiete ».

### Étape 5 — Nettoyer le texte (`normalize_text`, `tokenize`)

1. Tout en minuscules.
2. Suppression des accents : la normalisation Unicode `NFKD` sépare « é » en « e » + accent, puis l'accent est retiré. « Anxiété » devient « anxiete ».
3. Découpage en mots : on garde seulement les suites de lettres et de chiffres (expression `[a-z0-9]+`), donc la ponctuation disparaît.
4. Suppression des mots vides (`FRENCH_STOPWORDS` : le, la, de, et, je, pas…) et des mots d'une seule lettre.

Exemple réel : `"Anxiété et troubles du sommeil"` → `['anxiete', 'troubles', 'sommeil']`

### Étape 6 — TF-IDF (`build_tfidf_matrix`)

On range tous les textes dans une liste : le patient en premier, puis les psys disponibles. On construit un tableau avec une ligne par texte et une colonne par mot du vocabulaire commun.

**TF** (ligne 68) : nombre de fois où le mot apparaît dans le texte, divisé par le nombre de mots du texte.

**IDF** (ligne 74) :

```
idf = ln( (1 + n) / (1 + df) ) + 1
```

- `n` = nombre de textes
- `df` = nombre de textes qui contiennent le mot

C'est la même formule que l'option « smooth » de scikit-learn. Un mot rare obtient un IDF élevé, un mot présent partout un IDF faible. Le « + 1 » final évite qu'un mot commun à tous tombe à zéro.

**TF-IDF** (ligne 76) = TF × IDF, case par case.

L'idée à retenir : un mot compte s'il est fréquent dans ce texte et rare dans les autres.

### Étape 7 — Le score de chaque psy (`rank_psychologists`)

Pour chaque psy, trois ingrédients :

**Similarité** (`cosine_similarity`) : on compare la ligne du patient à celle du psy.

```
cosinus = (A · B) / (‖A‖ × ‖B‖)
```

Le résultat va de 0 (aucun mot en commun) à 1 (même orientation). Si l'un des deux vecteurs est vide, on renvoie 0 pour éviter une division par zéro.

**Note** : `rating / 5`, bornée entre 0 et 1. Une note absente compte pour 0.

**Même ville** (`same_city_bonus`) : 1 si les villes sont identiques après nettoyage (« Thiès » = « thies »), 0 sinon, et 0 si l'une des deux manque.

Le score final (lignes 172-176) :

```
score = 0,6 × similarité + 0,25 × (note / 5) + 0,15 × même_ville
```

Les poids viennent de `config.py` (lignes 19-21) et sont passés explicitement par `main.py` (lignes 62-64). Ils sont modifiables par variables d'environnement (`CONTENT_WEIGHT`, `RATING_WEIGHT`, `CITY_WEIGHT`). Leur somme fait 1, donc le score reste entre 0 et 1.

### Étape 8 — Trier et répondre

Tri par score décroissant (ligne 187), puis on garde les `top_n` premiers.

La réponse (`schemas.py`) contient `patientId`, `count` et la liste `recommendations`. Chaque psy y apparaît avec ses informations publiques (nom, spécialité, bio, langues, ville, expérience, tarif, note, nombre d'avis, disponibilité) et trois champs calculés : `contentSimilarity`, `cityMatch`, `score`. Les champs renvoyés par user-service qui ne figurent pas dans ce schéma (adresse du cabinet, numéro de licence…) sont ignorés par Pydantic.

## 5. Exemple complet, exécuté sur le vrai code

Patient : langue « Wolof », « Ce que vous recherchez » = « Anxiété et troubles du sommeil », ville Dakar.

| Psy | Spécialité / bio | Langues | Note | Ville | Dispo |
|---|---|---|---|---|---|
| A | Anxiété / TCC, anxiété, sommeil | Wolof, Français | 4 | Thiès | oui |
| B | Thérapie de couple / Conflits de couple | Français | 5 | Dakar | oui |
| C | Dépression / Accompagnement dépression | Wolof | 3 | Dakar | oui |
| D | Anxiété | Wolof | 5 | Dakar | **non** |

D est retiré dès l'étape 3, malgré sa note de 5 et sa spécialité parfaite.

Textes nettoyés :

```
patient : wolof, anxiete, troubles, sommeil
A       : anxiete, tcc, anxiete, sommeil, wolof, francais
B       : therapie, couple, conflits, couple, francais
C       : depression, accompagnement, depression, wolof
```

IDF (4 textes) :

| Mot | Présent dans | IDF |
|---|---|---|
| wolof | 3 textes | 1,223 |
| anxiete, sommeil, francais | 2 textes | 1,511 |
| troubles, tcc, couple, depression… | 1 texte | 1,916 |

« wolof » est le mot le plus répandu, c'est donc celui qui pèse le moins.

Résultat :

| Rang | Psy | Similarité | × 0,6 | Note × 0,25 | Ville × 0,15 | **Score** |
|---|---|---|---|---|---|---|
| 1 | A | 0,616 | 0,369 | 0,200 | 0 | **0,570** |
| 2 | B | 0 | 0 | 0,250 | 0,15 | **0,400** |
| 3 | C | 0,108 | 0,065 | 0,150 | 0,15 | **0,365** |

Lecture :

- A gagne alors qu'il n'est pas à Dakar : le contenu pèse plus que la ville.
- B n'a aucun mot en commun avec le patient, mais sa note de 5 et sa ville le placent devant C.
- C ne partage que « wolof » avec le patient, d'où sa petite similarité.

## 6. Les cas limites, et comment le code les gère

**Le patient n'a rien renseigné.** Son vecteur est vide, donc toutes les similarités valent 0 et le classement se fait sur la note (plus la ville si elle est connue). Il n'y a pas de `if` spécial pour ça : c'est la formule qui donne ce comportement. Couvert par le test `test_empty_patient_query_falls_back_to_rating_ranking`.

**La ville du patient est inconnue.** Le bonus vaut 0 pour tout le monde : personne n'est avantagé ni pénalisé. Couvert par `test_missing_patient_city_penalizes_nobody`.

**Aucun psy disponible.** Liste vide, pas d'erreur.

**Un psy n'a pas encore de note.** Il compte pour 0 et perd jusqu'à 0,25 point face aux psys déjà notés.

## 7. Les tests

Fichier `tests/test_recommender.py`. Ils ne dépendent que de numpy et se lancent sans pytest :

```
cd backend/ml-service
python3 -m tests.test_recommender
```

Résultat : **12 passés, 0 échoué**.

| Test | Ce qu'il prouve |
|---|---|
| `test_tokenize_normalizes_accents_and_case` | accents et majuscules retirés, « et » supprimé |
| `test_cosine_similarity_identical_vectors_is_one` | deux vecteurs identiques donnent 1 |
| `test_cosine_similarity_zero_vector_is_zero` | un vecteur vide donne 0, sans crash |
| `test_unavailable_psychologists_are_excluded` | un psy indisponible n'apparaît jamais |
| `test_content_match_outranks_lower_rated_but_relevant_psychologist` | le psy pertinent (4/5) passe devant le mieux noté (5/5) |
| `test_empty_patient_query_falls_back_to_rating_ranking` | profil vide → classement par note |
| `test_top_n_truncates_results` | `top_n` limite bien la liste |
| `test_no_available_psychologists_returns_empty_list` | aucun dispo → liste vide |
| `test_build_psychologist_content_and_patient_query_are_strings` | les textes sont bien construits |
| `test_same_city_bonus_ignores_case_and_accents` | « Thiès » = « thies », « dakar » = « Dakar » |
| `test_same_city_breaks_the_tie_between_identical_psychologists` | à profil identique, la ville départage |
| `test_missing_patient_city_penalizes_nobody` | sans ville patient, scores identiques |

Ce qui n'est pas testé : `main.py` et `user_service_client.py` (l'API et les appels HTTP). Seul le moteur l'est. Les tests sont exclus de l'image Docker (`.dockerignore`).

## 8. Lancer le service

En local :

```
cd backend/ml-service
pip install -r requirements.txt
python -m app.main
```

Le service écoute sur le port 8000. `GET /health` renvoie `{"status": "ok", "service": "ml-service"}`.

En Docker : le `Dockerfile` fait la même chose (`CMD ["python", "-m", "app.main"]`). `GATEWAY_URL` vaut `http://localhost:8080` par défaut, ce qui ne marche pas dans un conteneur (`localhost` y désigne le conteneur lui-même). `docker-compose.yml` le définit donc à `http://api-gateway:8080`.

Dans l'autre sens, la passerelle a besoin de `ML_SERVICE_URL`. Cette variable manquait dans `docker-compose.yml` : en Docker, la route `/recommendations/**` partait vers `localhost:8000` à l'intérieur du conteneur de la passerelle et échouait. L'app ne plantait pas grâce au repli Flutter (section 11), donc la panne était invisible. Corrigé le 24/09/2026 : `ML_SERVICE_URL: http://ml-service:8000` ajouté au service `api-gateway`.

## 9. Les limites du modèle

À dire soi-même avant que le jury les trouve :

1. **La négation est perdue.** « Je n'ai pas de dépression » donne `['depression']`, car « pas » est un mot vide. Le patient serait rapproché des spécialistes de la dépression.
2. **Pas de racinisation.** « anxieux » et « anxiete » sont deux mots différents pour le modèle, ils ne se reconnaissent pas.
3. **Pas de synonymes.** « angoisse » et « anxiété » ne se rapprochent pas.
4. **Pas d'évaluation chiffrée.** Il n'existe aucune mesure de qualité des recommandations (précision, taux de réservation…), faute de données réelles.
5. **Le nombre d'avis n'est pas pris en compte.** `totalReviews` est renvoyé mais n'entre pas dans le score : un psy à 5/5 sur un seul avis passe devant un psy à 4,8/5 sur cinquante.
6. **Désavantage des nouveaux psys.** Sans note, un psy perd jusqu'à 0,25 point.
7. **Le code 403 devient 502** (voir étape 2).
8. **Les deux appels vers user-service sont faits l'un après l'autre**, alors qu'ils sont indépendants.
9. **Langues du psy en texte libre.** Un psy qui écrit « French » au lieu de « Français » ne sera jamais rapproché d'un patient francophone sur la langue.

## 10. Questions probables du jury

**« C'est vraiment du machine learning ? »**
C'est une méthode de recherche d'information, sans apprentissage supervisé. Je l'ai choisie parce qu'une plateforme qui démarre n'a pas d'historique pour entraîner un modèle. Elle est adaptée au démarrage et peut évoluer vers un modèle entraîné quand les données existeront.

**« Pourquoi pas du filtrage collaboratif ? »**
Le filtrage collaboratif recommande à partir du comportement des autres utilisateurs (« les patients comme toi ont choisi X »). Sans historique de réservations et d'avis, il ne peut rien produire : c'est le problème du démarrage à froid. Le filtrage par contenu fonctionne dès le premier patient.

**« Pourquoi numpy et pas scikit-learn ? »**
Au départ, scikit-learn n'était pas installable dans mon environnement de développement, alors que numpy l'était et me permettait de tester. L'implémentation manuelle a un avantage : chaque calcul est visible et vérifié par les tests. La formule IDF est celle de scikit-learn.

**« Pourquoi diviser par la longueur du texte dans le TF ? »**
Pour le cosinus, cette division ne change rien : multiplier un vecteur par un nombre ne change pas sa direction, donc pas l'angle. Le classement serait le même sans elle.

**« Comment avez-vous choisi 0,6 / 0,25 / 0,15 ? »**
Ce sont des choix de conception, pas des valeurs apprises. Le contenu pèse le plus parce que c'est le besoin du patient. La note sert de départage de qualité. La ville a le poids le plus faible parce que la visio rend la distance secondaire. Les trois sont réglables sans toucher au code, et leur somme fait 1 pour que le score reste entre 0 et 1.

**« Pourquoi la ville n'est pas dans le TF-IDF ? »**
Parce que c'est une information de contexte, pas de contenu. Dans le texte, « dakar » aurait concurrencé les mots qui décrivent le besoin du patient.

**« Un patient peut-il obtenir les recommandations d'un autre ? »**
Non. ml-service ne vérifie pas le jeton lui-même : il le relaie à user-service, qui n'autorise la lecture de `GET /patients/{id}` qu'au patient propriétaire, à un psychologue ou à l'admin. Un autre patient est refusé, et la requête échoue (en 502, voir limite 7). Nuance à connaître : un psychologue connecté, lui, pourrait appeler l'adresse avec l'identifiant de n'importe quel patient, puisque user-service lui ouvre les fiches patients.

**« Un psy non validé peut-il être recommandé ? »**
Non. La liste est demandée avec `verifiedOnly=true`, puis filtrée sur `available`.

**« Et si le service ML tombe ? »**
L'accueil patient (`patient_home_screen.dart`, `_load()`) attrape l'erreur. Si ml-service ne répond pas, ou s'il renvoie une liste vide, l'app prend la liste des psys validés (`getAllPsychologists()`, avec `verifiedOnly=true`), la trie par note et garde les 5 premiers. Le patient voit toujours une liste. Petite différence : ce repli ne retire pas les psys indisponibles.

**« Envoyez-vous des données médicales à un service externe ? »**
Non. ml-service fait partie de la plateforme, il lit les données avec le jeton du patient lui-même et ne stocke rien : aucune base de données, aucun fichier. Et il ne lit que ce que le patient a écrit comme besoin (« Ce que vous recherchez ») et sa langue ; le dossier d'antécédents structurés n'entre jamais dans le calcul.

---

## 11. Vérifié côté user-service, passerelle et Flutter

| Point | Résultat | Où |
|---|---|---|
| Champ `medicalHistory` | Toujours rempli : c'est « Ce que vous recherchez » (inscription + Modifier le profil). Distinct des antécédents structurés, que ml-service ne lit pas | `PatientProfileResponse.java`, `register_screen.dart`, `edit_profile_screen.dart` |
| Ville du patient | Présente dans `GET /patients/{id}`, recopiée depuis `UserProfile.city` | `PatientProfileServiceImpl.mapToResponse` |
| Ville, langues, note, dispo du psy | Tous présents dans `GET /psychologists` | `PsychologistProfileResponse.java` |
| Note du psy | Recalculée comme moyenne des avis à chaque nouvel avis | `ReviewServiceImpl.java` |
| Format de la langue | Patient : liste fixe « Français / Wolof / Anglais ». Psy : texte libre. Même mot après nettoyage tant que le psy écrit en français (voir limite 9) | `profile_constants.dart`, `edit_psychologist_profile_screen.dart` |
| Repli Flutter | Confirmé : tri par note des psys validés, 5 premiers, aussi si la liste ML est vide | `patient_home_screen.dart`, `psychologist_service.dart` |
| Route passerelle | `/recommendations/**` → `${ML_SERVICE_URL:http://localhost:8000}`, route [9]. Les conseils post-séance passent par `/session-recommendations/**` pour éviter le conflit | `api-gateway/application.properties` |
| Docker | `ML_SERVICE_URL` manquait côté passerelle, ajouté le 24/09/2026 (section 8) | `docker-compose.yml` |
