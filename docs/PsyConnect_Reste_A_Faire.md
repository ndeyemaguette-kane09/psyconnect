# PsyConnect Sénégal — Reste à faire

Document de suivi établi le 21/06/2026, à partir de :
- l'audit du code réel vs `docs/Psyconnect Mvp Architecture And Business Rules Reworked.pdf` ;
- la comparaison des 23 maquettes produites (patient/psychologue/admin) avec l'app Flutter actuelle.

Deux familles de tâches : ce qui manque pour que l'app **rattrape les maquettes**, et ce que **les maquettes devraient corriger** pour rester honnêtes avec ce que le backend permet réellement.

## 0. Recommandation ML jamais appelée par l'app — ✅ corrigé le 22/06/2026

`PatientHomeScreen` affichait une liste "Recommandé pour vous" calculée côté client (top 5 par note) — confirmé par grep, aucune référence à `/recommendations` dans tout `lib/`. Le service ML (`GET /recommendations/{patientId}`, filtrage de contenu + similarité cosinus) était déjà construit, testé unitairement (9/9) et validé end-to-end via Postman (50/50), mais jamais appelé.

**Correctif appliqué** : `PsychologistService.getRecommendations()` (nouveau) appelle `GET /recommendations/{patientId}?top_n=5` via le gateway (route `/recommendations/**` → ml-service, déjà en place dans `application.properties`) ; `PatientHomeScreen._load()` l'utilise désormais pour remplir "Recommandé pour vous", avec repli automatique sur l'ancien tri par note si le service ML est indisponible (502/timeout) ou si le patientId est absent — jamais d'écran vide. `ApiConstants.recommendations()` ajouté pour construire l'URL.

Fichiers modifiés : `lib/core/constants/api_constants.dart`, `lib/features/patient/services/psychologist_service.dart`, `lib/features/patient/screens/patient_home_screen.dart`.

**À vérifier sur ta machine** (le sandbox ne peut pas lancer Flutter) : que `ml-service` tourne bien et que `ML_SERVICE_URL` est correctement configuré côté gateway, sinon le repli silencieux masquera une vraie panne — pense à observer les logs au premier lancement après ce changement.

## 1. Écrans entièrement absents (priorité haute)

### Journal personnel (patient)
Le backend expose déjà `/journal` (CRUD complet, ownership strict, `JournalEntry` dans user-service), mais aucun écran Flutter ne l'utilise. À créer : liste des entrées (avec date/humeur/texte si ces champs existent côté entité — à vérifier) + écran d'ajout/édition, branché sur le service déjà existant côté backend.

### Appel vidéo / visio (patient + psychologue)
Le backend simule déjà une session complète (`SessionServiceImpl` : `POST /sessions/start`, `POST /sessions/{id}/end`, jeton `SIM-AGORA-<uuid>`), mais aucune référence à `/sessions` n'existe dans `lib/`. À créer : un écran "Rejoindre la consultation" accessible depuis un rendez-vous `CONFIRMED`, des deux côtés (patient et psychologue), branché sur ces endpoints existants.

## 2. Contenu à compléter sur des écrans déjà codés

### Tableau de bord psychologue — carte Revenus
`PsychologistHomeTab` l'omet volontairement (décision prise quand `payment-service` n'existait pas encore). Le paiement est branché côté frontend depuis (`features/payment/`), donc ce calcul est maintenant faisable (ex. somme des paiements `COMPLETED` du mois via `GET /payments`).

### Statistiques psychologue
`PsychologistStatsTab` ne calcule que des compteurs par statut de rendez-vous + note moyenne. La maquette montre en plus : graphique de revenus sur 6 mois, taux de présence, répartition vidéo/audio/présentiel. La répartition par type de séance est faisable côté client (`ConsultationType` est déjà un champ de `Appointment`) ; le taux de présence nécessiterait de définir ce que "présence" signifie (aucune notion de présence n'est trackée actuellement) ; le graphique de revenus dépend du point précédent (paiements).

## 3. Écarts maquette/backend à trancher (la maquette invente des choses qui n'existent pas)

### Config admin
`AdminConfigTab` réel = placeholder honnête (infos du compte connecté + déconnexion), car aucun service n'expose de réglages globaux (pas de commission, tarif minimum, langue par défaut, modération). Ma maquette invente ces réglages.
Deux options : (a) construire un vrai modèle de configuration plateforme côté backend (nouvelle entité/endpoint `/admin/config`), ou (b) revoir la maquette pour qu'elle reste un placeholder honnête comme l'écran actuel.

### Accueil patient
La maquette (et l'accueil mocké) reprennent la maquette v2 d'origine : sélecteur d'humeur, accès rapide au journal, bandeau de recommandation IA. Le volet recommandation IA est réglé (voir section 0, corrigé le 22/06/2026) ; restent le sélecteur d'humeur et l'accès rapide au journal, sans endpoint dédié — soit construire le backend pour l'humeur (le journal, lui, a déjà un backend, voir section 1), soit ajuster la maquette.

## 4. Règles métier documentées mais non appliquées dans le code

Trouvées en comparant le PDF d'architecture (qui marque ces fonctionnalités "Développé") au code réel — indépendant des maquettes, mais à connaître pour la soutenance :

- **Notes cliniques (psychologue)** : n'existent pas du tout (le journal privé du patient n'est pas équivalent).
- **Avis/notation patient → psychologue** : `PsychologistProfile.rating` est un simple nombre modifiable, sans entité Review ni flux de notation après consultation, ni anonymat.
- **Validation psychologue non bloquante** : `profileVerified`/`verifiedOnly` existe mais n'empêche pas un psychologue non vérifié de recevoir des rendez-vous.
- **Double-réservation patient** : seul le conflit de créneau côté psychologue est vérifié ; un même patient pourrait réserver deux psychologues à la même heure.
- **Chiffrement des données sensibles** : aucun chiffrement au repos trouvé, contrairement à ce que liste le document de sécurité.

## 5. Reste connu côté frontend (audit antérieur, toujours valable)

- Pas de mot de passe oublié en self-service (seul un reset *par un admin* existe).
- Pas de tests automatisés au-delà de 2 tests de fumée (`widget_test.dart`).
- Pas de notifications push (uniquement in-app via `GET /notifications/user/{id}`).

## 6. Maquettes à compléter de mon côté

Trois écrans existent déjà dans l'app sans équivalent dans les 23 maquettes produites : Modifier le profil, Paramètres, Notifications (patient). À maquetter si tu veux un ensemble complet et cohérent.

## 7. Non vérifié (limite de l'environnement, pas du code)

`./gradlew build`/`test` n'a pas pu être relancé dans ce sandbox (Java 11 seulement, pas d'accès réseau à `services.gradle.org`) — à confirmer sur ta machine, notamment pour les derniers ajouts (rôle ADMIN, Resilience4j, traçage Zipkin).
