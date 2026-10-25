# PsyConnect

Application mobile de mise en relation entre patients et psychologues au Sénégal, réalisée dans le cadre de mon mémoire de Master 2 Systèmes d'Informations Répartis (FST, Université Cheikh Anta Diop de Dakar, 2025-2026).

Le patient peut trouver un psychologue vérifié, réserver une consultation (vidéo, audio ou au cabinet), la payer depuis un portefeuille intégré et suivre son état entre les séances (journal d'humeur, questionnaires PHQ-9 et GAD-7). Le psychologue gère son agenda, ses patients et ses notes cliniques. L'administrateur valide les comptes des psychologues et traite les signalements.

Le compagnon Xalaat (« pensée » en wolof) aide le patient à préparer sa première consultation. Il repose sur un modèle de langage qui tourne en local avec Ollama, et un filtre placé avant le modèle oriente vers les numéros d'urgence dès qu'un message exprime une détresse.

## Architecture

Le back-end est découpé en microservices Spring Boot, avec un service Python pour la recommandation. L'application mobile passe toujours par la passerelle.

| Service | Port | Rôle |
|---|---|---|
| api-gateway | 8080 | Point d'entrée unique, routage vers les services |
| eureka-server | 8761 | Registre des services |
| auth-service | 8081 | Inscription, connexion, jetons JWT, mot de passe oublié |
| user-service | 8082 | Profils, disponibilités, portefeuille, notes cliniques, signalements, annonces |
| appointment-service | 8083 | Rendez-vous, messagerie, questionnaires, échéances automatiques |
| payment-service | 8085 | Paiements, remboursements, revenus des psychologues |
| notification-service | 8086 | Notifications dans l'application |
| ai-companion-service | 8087 | Compagnon Xalaat (Spring AI + Ollama) |
| session-service | 8089 | Consultations vidéo et audio (Jitsi Meet) |
| ml-service | 8000 | Recommandation de psychologues (FastAPI, TF-IDF) |

Chaque service qui stocke des données a sa propre base PostgreSQL. Chaque service vérifie lui-même le jeton JWT. Les appels entre services sont protégés par Resilience4j (retry et circuit breaker) et tracés avec Zipkin.

## Technologies

- Back-end : Java 17, Spring Boot 3.5, Spring Cloud Gateway, Eureka, Spring Data JPA, Spring Security, Resilience4j, Micrometer Tracing, Zipkin
- Recommandation : Python 3, FastAPI, NumPy
- IA : Spring AI, Ollama, modèle qwen2.5:3b
- Mobile : Flutter (Dart), Provider, Jitsi Meet SDK
- Données : PostgreSQL 16
- Déploiement : Docker, Docker Compose
- Tests : JUnit 5, tests Flutter

## Lancer le projet

Prérequis : Docker Desktop, JDK 17, Flutter, et [Ollama](https://ollama.com) avec le modèle du compagnon :

```bash
ollama pull qwen2.5:3b
```

1. Copier le fichier d'environnement et remplir les valeurs :

   ```bash
   cp .env.example .env
   ```

2. Compiler les services Java (les images Docker copient le `.jar` produit) :

   ```bash
   for s in backend/*/; do [ -f "$s/gradlew" ] && (cd "$s" && ./gradlew bootJar -x test); done
   ```

3. Démarrer l'ensemble :

   ```bash
   docker compose up --build -d
   ```

4. Lancer l'application mobile :

   ```bash
   cd frontend/psyconnect
   flutter pub get
   flutter run --dart-define=API_BASE_URL=http://<adresse-du-mac>:8080
   ```

Interfaces utiles une fois lancé : Eureka sur http://localhost:8761, Zipkin sur http://localhost:9411, Mailpit (e-mails de test) sur http://localhost:8025.

## Tests

- Back-end : `./gradlew test` dans chaque service.
- Mobile : `flutter test` dans `frontend/psyconnect`.

## Organisation du dépôt

```
backend/              microservices (un dossier par service)
frontend/psyconnect/  application Flutter
docker/               script de création des bases
docker-compose.yml    lancement de l'ensemble
start-dev.sh          lancement des services en mode développement (hors Docker)
```

## Limites connues

Le paiement mobile (Wave, Orange Money) est simulé, les échanges se font en HTTP dans l'environnement de développement et l'appel d'urgence sans rendez-vous reste un démonstrateur côté patient. Le détail est dans le mémoire.

## Auteure

Ndeye Maguette KANE, Master 2 SIR, FST-UCAD. Encadreur : Dr Elhadji Bassirou TOURÉ.
