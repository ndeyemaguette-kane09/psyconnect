# Logiciels et technologies utilisés — PsyConnect Sénégal

> Liste exhaustive extraite des fichiers de configuration réels du projet
> (`build.gradle`, `pubspec.yaml`, `requirements.txt`, `docker-compose.yml`).

---

## Langages de programmation

| Langage | Version | Rôle |
|---|---|---|
| Java | 17 (LTS) | Tous les microservices back-end |
| Dart | SDK ^3.6.1 | Application mobile Flutter |
| Python | 3.x | Service de recommandation ML |
| SQL | — | Requêtes PostgreSQL |
| JavaScript / Node.js | 22 | Scripts de génération de documents (CDC Word) |

---

## Back-end — Frameworks et bibliothèques Java

### Spring Boot & Spring Cloud (version BOM `2025.0.2`)

| Bibliothèque | Version | Usage |
|---|---|---|
| Spring Boot | 3.5.14 | Socle de tous les microservices |
| Spring Boot Starter Web | (BOM) | API REST (contrôleurs, JSON) |
| Spring Boot Starter Security | (BOM) | Sécurisation des routes, filtres JWT |
| Spring Boot Starter Data JPA | (BOM) | ORM (entités, repositories) |
| Spring Boot Starter Validation | (BOM) | Validation des DTOs (`@Valid`, `@NotBlank`…) |
| Spring Boot Starter Actuator | (BOM) | Métriques et health-checks |
| Spring Boot Starter AOP | (BOM) | Aspects Resilience4j |
| Spring Boot Starter WebSocket | (BOM) | Signaling WebRTC (video-service) |
| Spring Boot Starter Test | (BOM) | Tests unitaires et d'intégration |
| Spring Cloud Gateway | 2025.0.2 | API Gateway : routage, filtres, timeouts |
| Spring Cloud Netflix Eureka Client | 2025.0.2 | Enregistrement de chaque service sur Eureka |
| Spring Cloud Netflix Eureka Server | 2025.0.2 | Serveur de découverte de services |
| Spring AI | 1.0.8 | Intégration du LLM Ollama (compagnon Xalaat) |
| spring-ai-starter-model-ollama | 1.0.8 | Connecteur Spring AI → Ollama |
| Spring Security Test | (BOM) | Tests de sécurité (auth-service) |

### Bibliothèques tierces Java

| Bibliothèque | Version | Usage |
|---|---|---|
| JJWT API | 0.11.5 | Création et validation des tokens JWT |
| JJWT Impl | 0.11.5 | Implémentation JJWT (runtime) |
| JJWT Jackson | 0.11.5 | Sérialisation JSON des claims JWT |
| Resilience4j Spring Boot 3 | 2.2.0 | Circuit breaker sur les appels inter-services |
| Lombok | (BOM) | Réduction du boilerplate Java (`@Data`, `@Builder`…) |
| Micrometer Tracing Bridge Brave | (BOM) | Propagation des traces B3 entre services |
| Zipkin Reporter Brave | (BOM) | Export des traces vers le serveur Zipkin |
| PostgreSQL JDBC Driver | (BOM) | Connexion des services à PostgreSQL |
| H2 Database | (BOM) | Base de données en mémoire pour les tests |
| Hibernate | (BOM, via JPA) | ORM sous-jacent de Spring Data JPA |
| Jackson | (BOM, via Web) | Sérialisation/désérialisation JSON |
| JUnit Platform Launcher | (BOM) | Exécution des tests JUnit 5 |

### Outil de build back-end

| Outil | Version | Usage |
|---|---|---|
| Gradle | 8.x | Build, gestion des dépendances, tâches Java |
| io.spring.dependency-management | 1.1.7 | Plugin Gradle pour le BOM Spring |

---

## Front-end mobile — Flutter / Dart

### SDK et configuration

| Composant | Version | Usage |
|---|---|---|
| Flutter SDK | stable | Framework UI multiplateforme (Android & iOS) |
| Dart SDK | ^3.6.1 | Langage de l'application mobile |
| Material Design Icons | (intégré Flutter) | Icônes de l'interface |
| Cupertino Icons | ^1.0.8 | Icônes style iOS |

### Dépendances Flutter (pubspec.yaml)

| Package | Version | Usage |
|---|---|---|
| provider | ^6.1.2 | Gestion d'état (pattern ChangeNotifier) |
| http | ^1.2.2 | Appels REST vers l'API Gateway |
| http_parser | ^4.0.2 | Construction du Content-Type pour les uploads |
| flutter_secure_storage | ^9.2.2 | Stockage sécurisé du token JWT sur l'appareil |
| google_fonts | ^8.1.0 | Polices Playfair Display (titres) et DM Sans (corps) |
| flutter_svg | ^2.0.10+1 | Affichage du logo vectoriel SVG |
| file_picker | ^8.1.6 | Sélection du justificatif psy (PDF, image) |
| path_provider | ^2.1.4 | Accès au dossier temporaire de l'appareil |
| open_filex | ^4.5.0 | Ouverture de fichiers avec la visionneuse native |
| jitsi_meet_flutter_sdk | ^10.2.0 | Consultations vidéo via Jitsi Meet / WebRTC |

### Dépendances de développement Flutter

| Package | Version | Usage |
|---|---|---|
| flutter_lints | ^5.0.0 | Règles de linting Dart recommandées |
| flutter_launcher_icons | ^0.14.1 | Génération des icônes natives (iOS/Android/Web/macOS) |

---

## Service ML — Python

### Framework et bibliothèques

| Package | Version minimale | Usage |
|---|---|---|
| FastAPI | >=0.110 | API REST du service de recommandation |
| Uvicorn | >=0.29 | Serveur ASGI pour FastAPI |
| Pydantic | >=2.0 | Validation et sérialisation des schémas |
| HTTPX | >=0.27 | Appels HTTP asynchrones vers user-service |
| NumPy | >=1.26 | Calculs vectoriels pour TF-IDF et similarité cosinus |

> L'algorithme TF-IDF et la similarité cosinus sont implémentés manuellement
> en Python/NumPy, sans dépendance à scikit-learn.

---

## Infrastructure et déploiement

| Logiciel | Rôle |
|---|---|
| Docker | Conteneurisation de chaque service |
| Docker Compose | Orchestration locale de l'ensemble des services |
| PostgreSQL | Base de données relationnelle (1 instance par microservice) |
| Eureka Server | Découverte et enregistrement des services |
| Zipkin | Collecte et visualisation des traces distribuées |
| Ollama | Runtime LLM local (héberge le modèle qwen2.5:3b) |
| qwen2.5:3b | Modèle de langage utilisé par le compagnon Xalaat |
| coturn | Serveur TURN/STUN pour les appels WebRTC (Jitsi) |

---

## Protocoles et standards

| Protocole / Standard | Usage |
|---|---|
| REST / HTTP 1.1 | Communication entre l'app mobile et l'API Gateway |
| JWT (JSON Web Tokens) | Authentification et autorisation décentralisée |
| B3 Propagation | Propagation des traces distribuées (Brave/Zipkin) |
| WebRTC | Appels vidéo en temps réel (via Jitsi Meet SDK) |
| WebSocket (STOMP) | Signaling WebRTC (video-service) |
| HTTPS / TLS | Chiffrement des communications (déploiement) |
| BCrypt | Hachage des mots de passe |

---

## Outils de développement et documentation

| Outil | Usage |
|---|---|
| Git | Contrôle de version du projet |
| PlantUML | Génération des diagrammes UML (classes, séquences, cas d'utilisation, architecture) |
| Node.js + package `docx` | Génération programmatique du cahier des charges Word |
| pandoc | Conversion de documents Word en Markdown (lecture du code) |
| LibreOffice | Conversion docx → PDF pour vérification |
| pdftoppm (Poppler) | Rendu des pages PDF en images JPEG pour vérification visuelle |

---

## Récapitulatif par couche

```
┌─────────────────────────────────────────────────────┐
│  Application mobile Flutter (Dart 3.6)               │
│  provider · http · flutter_secure_storage            │
│  google_fonts · flutter_svg · file_picker            │
│  jitsi_meet_flutter_sdk · open_filex                 │
└───────────────────┬─────────────────────────────────┘
                    │ REST / JWT
┌───────────────────▼─────────────────────────────────┐
│  API Gateway (Spring Cloud Gateway 2025.0.2)         │
│  Eureka Client · Zipkin · Actuator                   │
└───────────────────┬─────────────────────────────────┘
                    │ lb:// (Eureka)
┌───────────────────▼─────────────────────────────────┐
│  Microservices Spring Boot 3.5.14 / Java 17          │
│  auth · user · appointment · payment                 │
│  notification · ai-companion · video · ml-service    │
│  JJWT · Resilience4j · Hibernate/JPA · Lombok       │
│  Micrometer Brave · Zipkin Reporter                  │
└───────────────────┬─────────────────────────────────┘
                    │
     ┌──────────────┼──────────────┐
     ▼              ▼              ▼
PostgreSQL       Ollama        FastAPI/NumPy
(x5 bases)    qwen2.5:3b     (ml-service)
```
