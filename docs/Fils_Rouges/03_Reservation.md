# 03 — Un patient réserve un rendez-vous

Le trajet complet d'une seule action, du bouton dans l'application jusqu'à la base de données et la
notification. Chaque étape indique le fichier et la ligne dans le code réel du projet.

Vérifié dans le code le 24/09/2026. Le paiement qui suit la confirmation est dans le fil 04.

Savoir raconter ce trajet, c'est tenir l'architecture : il traverse l'application Flutter, la passerelle,
la découverte de services, l'authentification par jeton, la logique métier, la persistance et un appel
inter-services.

---

## Étape 1 — L'application prépare la demande

`frontend/psyconnect/lib/features/patient/screens/booking_screen.dart:131`

Le patient a choisi une date, un créneau et un type de consultation. Avant tout appel réseau, l'écran
récupère son identifiant de profil :

```dart
final patientId = context.read<AuthProvider>().session?.profileId;
```

Attention à la distinction, elle revient souvent : `profileId` est l'identifiant du **PatientProfile**
(côté user-service), pas l'identifiant du compte d'authentification (`authUserId`, côté auth-service).
Deux identités différentes pour la même personne, dans deux bases différentes.

L'écran construit ensuite l'intervalle horaire et appelle le service (ligne 153).

## Étape 2 — La couche service traduit en requête HTTP

`frontend/psyconnect/lib/features/patient/services/appointment_service.dart:15`

```dart
final json = await _api.post(ApiConstants.appointments, body: request.toJson());
return Appointment.fromJson(json as Map<String, dynamic>);
```

Aucune logique ici : cette couche ne fait que traduire un objet Dart en JSON et retraduire la réponse.
C'est ce qui permet de changer d'écran sans toucher au réseau, et inversement.

## Étape 3 — Le client HTTP attache le jeton

`frontend/psyconnect/lib/core/network/api_client.dart:31`

```dart
final token = await TokenStorage.readToken();
if (token != null) headers['Authorization'] = 'Bearer $token';
```

Le jeton est lu depuis `flutter_secure_storage` (trousseau iOS / Keystore Android), **pas** depuis la
mémoire de l'application. C'est la cause d'un bug corrigé pendant le développement : un appel authentifié
lancé avant que la session soit persistée partait sans en-tête et recevait un 403.

L'URL de base vient de `api_constants.dart:11`, injectée à la compilation par
`--dart-define=API_BASE_URL=...`. Sur téléphone physique, l'oublier fait pointer l'application vers
elle-même.

## Étape 4 — La passerelle route, sans lire le jeton

`backend/api-gateway/src/main/resources/application.properties:21`

```properties
spring.cloud.gateway.routes[2].id=appointment-service
spring.cloud.gateway.routes[2].uri=lb://APPOINTMENT-SERVICE
spring.cloud.gateway.routes[2].predicates[0]=Path=/appointments/**
```

Deux choses à savoir dire ici.

**`lb://` signifie *load balanced*.** La passerelle ne connaît pas l'adresse d'`appointment-service` :
elle demande à Eureka quelles instances sont enregistrées sous ce nom, puis en choisit une. C'est la
raison d'être du serveur Eureka. Si le service tombe et redémarre sur un autre port, rien à reconfigurer.

**La passerelle ne valide pas le jeton.** Le module `api-gateway` ne contient que deux fichiers Java :
la classe de démarrage et un test. C'est un routeur pur ; l'en-tête `Authorization` est transmis tel quel.
Voir la justification de ce choix en section 4 de l'audit de sécurité.

## Étape 5 — Le service vérifie le jeton lui-même

`backend/appointment-service/src/main/java/com/example/appointmentservice/security/JwtAuthenticationFilter.java`

Chaque microservice porte son propre filtre : il lit l'en-tête `Authorization`, valide la signature avec
le secret partagé, et place l'identité et le rôle dans le `SecurityContext` de Spring Security.

Conséquence architecturale à assumer : la logique est dupliquée dans chaque service, mais **aucun service
n'est nu**. Un attaquant qui atteindrait `appointment-service` directement, en contournant la passerelle,
se heurterait quand même au filtre.

## Étape 6 — Le cœur : cinq vérifications avant d'écrire

`backend/appointment-service/.../service/impl/AppointmentServiceImpl.java:84`

**1. Le rôle** (ligne 88) — seul un patient peut réserver.

**2. La propriété — c'est le point le plus important de tout le trajet** (lignes 94 à 100) :

```java
Long ownPatientId = ownershipResolver.resolveOwnPatientId();
if (!ownPatientId.equals(request.getPatientId())) {
    throw new ForbiddenOperationException(
            "Vous ne pouvez réserver un rendez-vous que pour vous-même");
}
```

L'application envoie un `patientId` dans le corps de la requête, **et le serveur ne lui fait pas
confiance**. Il résout l'identité réelle à partir du jeton, puis compare. Sans cette vérification,
n'importe qui pourrait réserver au nom de n'importe qui en modifiant un champ JSON.

`OwnershipResolver.resolveOwnPatientId()` (`service/OwnershipResolver.java:43`) appelle user-service sur
`/patients/by-auth-user/{authUserId}` — c'est ici que le pont est fait entre l'identité
d'authentification et l'identité métier.

**3. Le psychologue est approuvé** (ligne 102) — un praticien non validé par l'administration ne peut pas
recevoir de rendez-vous.

**4. La cohérence temporelle** (lignes 109 à 129) — fin après le début, et pas de réservation dans le passé.

**5. Le double conflit de créneau** (lignes 131 à 163) — le psychologue n'a pas déjà un rendez-vous qui
chevauche, **et le patient non plus**. Deux requêtes distinctes ; seuls les statuts `PENDING` et
`CONFIRMED` comptent, un rendez-vous annulé libère le créneau.

## Étape 7 — Écriture, puis notification

Le rendez-vous est créé avec le statut **`PENDING`** (`AppointmentStatus.PENDING`), pas `CONFIRMED` : le
paiement n'intervient qu'après confirmation du psychologue. C'est une décision produit, pas une limite
technique.

Puis deux notifications partent (lignes 197 à 213), l'une vers le patient, l'autre vers le psychologue :

```java
notifyPatient(savedAppointment.getId(), request.getPatientId(),
        "Demande de rendez-vous envoyée", ...);
notifyPsychologist(savedAppointment.getId(), request.getPsychologistId(),
        "Nouvelle demande de rendez-vous", ...);
```

Chacune appelle `notificationClient.send(..., "APPOINTMENT", "PATIENT")` ou `"PSYCHOLOGIST"` : un appel
HTTP synchrone vers notification-service. Point à souligner : **si notification-service est indisponible,
le rendez-vous existe quand même**. Dans appointment-service, `NotificationClient.send` porte `@Retry` et
`@CircuitBreaker` (Resilience4j) avec une méthode de repli qui se contente de journaliser. La réservation
ne dépend pas de la notification.

## Étape 8 — Le retour

Le contrôleur (`controller/AppointmentController.java:30`) renvoie **201 Created** avec le rendez-vous.
`Appointment.fromJson` le reconstruit côté Dart, l'écran affiche la confirmation et revient à la fiche
du psychologue.

---

## Ce que ce seul trajet démontre

| Notion | Où elle apparaît |
|---|---|
| Séparation écran / service / réseau | étapes 1 à 3 |
| Stockage sécurisé d'un secret côté client | étape 3 |
| Passerelle et routage | étape 4 |
| Découverte de services (Eureka) | étape 4, `lb://` |
| Authentification par jeton, sans état | étape 5 |
| Autorisation fondée sur l'identité prouvée | étape 6, point 2 |
| Communication inter-services | étapes 6 et 7 |
| Tolérance à la panne (Resilience4j) | étape 7 |
| Règles métier et intégrité des données | étape 6, points 3 à 5 |

## Les questions probables, et leur réponse

**« Pourquoi envoyer le `patientId` si le serveur ne le croit pas ? »**
Il sert de déclaration d'intention et rend l'API lisible ; la vérification garantit qu'il correspond au
porteur du jeton. On pourrait le déduire entièrement du jeton — ce serait plus strict et c'est une
évolution possible.

**« Pourquoi la passerelle ne valide-t-elle pas le jeton ? »**
Choix assumé : chaque service reste protégé même s'il est atteint directement. Le coût est la duplication
du filtre. L'alternative — valider uniquement à la passerelle — crée un point de confiance unique et laisse
les services nus sur le réseau interne.

**« Que se passe-t-il si user-service tombe pendant une réservation ? »**
`OwnershipResolver` ne peut plus résoudre l'identité : la réservation échoue, avec repli et disjoncteur.
C'est volontaire — sans identité vérifiée, on n'écrit pas.

**« Deux patients réservent le même créneau en même temps ? »**
La vérification de conflit précède l'écriture mais n'est pas atomique : une transaction sérialisable ou une
contrainte d'unicité en base fermerait complètement la fenêtre. Limite connue, à citer en perspective.
