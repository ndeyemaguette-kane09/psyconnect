# Validation du backend PsyConnect — 20 juin 2026

Ce document résume la mise en route et la validation complète du backend Spring Boot de PsyConnect, suite à la fusion de `payment-service` dans `appointment-service` et de `journal-service` dans `user-service`.

## 1. Contexte

Avant cette session, le code des microservices (auth-service, user-service, appointment-service, notification-service, api-gateway, eureka-server) compilait (`./gradlew build` validé), mais les services n'avaient jamais été lancés ensemble en local avec une collection de tests end-to-end.

Objectif de la session : démarrer tous les services localement et exécuter la collection Postman complète (`postman/PsyConnect.postman_collection.json`) pour valider le parcours patient/psychologue de bout en bout.

## 2. Architecture des bases de données

Chaque microservice possède sa propre base PostgreSQL, conformément aux valeurs par défaut déjà codées dans les `application.properties` :

| Service | Base de données | Port |
|---|---|---|
| auth-service | `psyconnect_auth` | 5433 |
| user-service | `psyconnect_user` | 5433 |
| appointment-service | `psyconnect_appointment` | 5433 |
| notification-service | `psyconnect_notification` | 5433 |
| session-service | `psyconnect_session` | 5433 |

PostgreSQL tourne dans un conteneur Docker, avec un mapping de port `5433:5432` (host:conteneur). Identifiants : `postgres` / `postgres`.

**Décision prise** : une ancienne base unique `psyconnect_db` contenait des données de test antérieures, créées avant que l'architecture par service ne soit figée. Plutôt que de migrer ces données, le choix a été fait de repartir sur l'architecture cible (une base par service), quitte à perdre les anciennes données de test — celles-ci n'avaient pas de valeur pour le mémoire. Les 5 bases ont été créées via `CREATE DATABASE` (opération non destructive, n'affecte pas `psyconnect_db`). Le schéma de chaque base est ensuite généré automatiquement par Hibernate (`spring.jpa.hibernate.ddl-auto=update`) au premier démarrage.

## 3. Problèmes rencontrés et résolus

| Problème | Cause | Résolution |
|---|---|---|
| `Task 'boot' is ambiguous` (Gradle) | Commande tapée `./gradlew boot run` (deux mots) au lieu de `./gradlew bootRun` | Correction de la commande |
| `Connection to localhost:5433 refused` (auth-service) | Conteneur PostgreSQL pas encore disponible au moment du lancement | Nouvelle tentative après confirmation que le conteneur Docker était bien up |
| Données de test introuvables dans les bases par service | Les anciennes données vivaient dans une base unique `psyconnect_db`, pas dans les bases par service attendues par défaut | Création des 5 bases dédiées, redémarrage propre de tous les services |

## 4. Ordre de démarrage

1. `eureka-server` (registre de services, port 8761)
2. `auth-service`, `user-service`, `appointment-service`, `notification-service` (chacun s'enregistre auprès d'Eureka)
3. `api-gateway` en dernier (port 8080, point d'entrée unique du frontend/Postman)

Vérification : tous les services apparaissent `UP` sur le dashboard Eureka (`http://localhost:8761`).

## 5. Résultats de la collection Postman

Exécution via Postman Runner, le 20 juin 2026 à 18:01:54 — **31 requêtes, 31 tests passés, 0 échec, 0 erreur**, durée totale 5,5 s, temps de réponse moyen 187 ms.

| Étape | Endpoint | Résultat |
|---|---|---|
| Inscription patient | `POST /auth/register/patient` | 200 — OK |
| Connexion patient | `POST /auth/login` | 200 — OK |
| Inscription psychologue | `POST /auth/register/psy` | 200 — OK |
| Connexion psychologue | `POST /auth/login` | 200 — OK |
| Profil courant (patient) | `GET /auth/me` | 200 — OK |
| Créer profil utilisateur (patient) | `POST /users` | 201 — OK |
| Créer profil patient | `POST /patients` | 201 — OK |
| Créer profil utilisateur (psychologue) | `POST /users` | 201 — OK |
| Créer profil psychologue | `POST /psychologists` | 201 — OK |
| Créer un rendez-vous | `POST /appointments` | 201 — statut initial `PENDING` |
| Récupérer le rendez-vous (avant paiement) | `GET /appointments/1` | 200 — toujours `PENDING` |
| Créer un paiement | `POST /payments` | 201 — statut `COMPLETED`, référence de transaction présente |
| Créer un paiement, montant invalide | `POST /payments` | 400 — rejeté en validation (cas négatif) |
| Récupérer un paiement par id | `GET /payments/1` | 200 — OK |
| Récupérer les paiements d'un rendez-vous | `GET /payments/appointment/1` | 200 — au moins un paiement |
| Vérifier le rendez-vous après paiement | `GET /appointments/1` | 200 — statut passé à `CONFIRMED` |
| Créer une entrée de journal | `POST /journal` | 201 — OK |
| Créer une entrée sans token | `POST /journal` | 403 — refusé sans authentification (cas négatif) |
| Lister mes entrées | `GET /journal` | 200 — au moins une entrée |
| Récupérer une entrée par id | `GET /journal/1` | 200 — OK |
| Modifier une entrée | `PUT /journal/1` | 200 — contenu mis à jour |
| Accès par le psychologue (interdit) | `GET /journal/1` (token psy) | 404 — accès refusé (cas négatif, ownership strict) |
| Supprimer une entrée | `DELETE /journal/1` | 204 — No Content |
| Vérifier la suppression | `GET /journal/1` | 404 — Not Found (confirmé supprimé) |

## 6. Conclusion

Le backend Spring Boot de PsyConnect est validé fonctionnellement de bout en bout : authentification JWT, gestion des profils (utilisateur, patient, psychologue), création et confirmation de rendez-vous, paiement simulé, et journal privé avec contrôle d'accès strict par patient. Les cas négatifs (montant invalide, accès sans token, accès croisé patient/psychologue) sont également couverts et se comportent comme attendu.

*Note : les captures d'écran des résultats Postman ont été visualisées pendant la session mais ne sont pas jointes à ce document (non accessibles en tant que fichiers) — le tableau ci-dessus reprend l'intégralité des résultats observés.*

## 7. Reste à faire

- `session-service` n'est aujourd'hui qu'un squelette Spring Boot vide (aucun contrôleur, aucune entité) — la simulation de session n'a pas encore été implémentée.
- Service ML de recommandation (FastAPI) — non démarré.
- Frontend Flutter — scaffold par défaut uniquement ; maquettes HTML détaillées disponibles dans `docs/PsyConnect Maquettes v2.html`.
