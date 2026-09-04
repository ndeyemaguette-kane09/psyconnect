# PsyConnect — audit de sécurité

*Revue du code au 28 août 2026. Backend Spring Boot (9 services), frontend Flutter.*

Ce document sert deux usages : préparer les questions de sécurité en soutenance, et
tenir la liste des correctifs par ordre de priorité. Il distingue volontairement ce
qui est **défendable**, ce qui doit être **assumé comme limite d'un projet
académique**, et ce qui est **à corriger**.

---

## 1. Jugement d'ensemble

L'application n'est pas naïve sur la sécurité. Trois mécanismes sont au niveau de ce
qu'on attend d'un projet sérieux : le hachage des mots de passe, le contrôle de
propriété des rendez-vous et de la messagerie, et la protection de l'upload contre la
traversée de chemin.

Les faiblesses sont concentrées ailleurs, et elles ont une cause commune : **des
raccourcis de développement laissés actifs par défaut**, parce qu'aucun service
d'envoi d'e-mail n'a été implémenté et que tout tourne en local. Ce n'est pas un
défaut de conception, c'est une frontière dev/prod jamais tracée.

---

## 2. Ce qui est défendable sans réserve

**Hachage des mots de passe.** `BCryptPasswordEncoder` dans
`auth-service/config/SecurityConfig.java`, branché sur le `DaoAuthenticationProvider`.
Encodage à l'inscription, `matches()` au login, ré-encodage au reset. Aucun stockage
réversible nulle part.

**Contrôle de propriété (protection IDOR).** C'est le point fort du projet.
`appointment-service` ne fait jamais confiance à l'identifiant présent dans l'URL :
`SecurityUtils.currentAuthUserId()` lit l'`authUserId` du token, puis
`OwnershipResolver` le convertit en `patientId`/`psychologistId` métier via
user-service, et c'est **ce résultat** qui sert de référence.

```java
private void checkParticipant(Appointment appointment) {
    if (SecurityUtils.hasRole("PATIENT")) {
        Long ownPatientId = ownershipResolver.resolveOwnPatientId();
        if (ownPatientId.equals(appointment.getPatientId())) return;
    }
    if (SecurityUtils.hasRole("PSYCHOLOGIST")) {
        Long ownPsychologistId = ownershipResolver.resolveOwnPsychologistId();
        if (ownPsychologistId.equals(appointment.getPsychologistId())) return;
    }
    throw new ForbiddenOperationException("Ce rendez-vous ne vous appartient pas");
}
```

Vérifié endpoint par endpoint : `GET /appointments/{id}`, `PUT .../status`,
`PUT .../reschedule`, `DELETE`, `GET /appointments/patient/{id}`,
`GET /appointments/psychologist/{id}`, `POST /appointments`. Changer l'identifiant
dans l'URL renvoie 403. Même mécanisme dans la messagerie (`checkParticipant` sur
`listMessages`, `sendMessage`, `markConversationRead`), avec en plus l'exigence d'un
rendez-vous commun avant d'ouvrir une conversation.

**Upload du justificatif — traversée de chemin.** Triple protection, irréprochable :

```java
String generatedName = UUID.randomUUID() + extension;
Path target = root.resolve(generatedName).normalize();
if (!target.getParent().equals(root)) {
    throw new IllegalArgumentException("Nom de fichier invalide.");
}
```

Le nom fourni par le client n'est jamais réutilisé, seulement son extension. La
lecture (`load()`) ne prend que le nom stocké en base. Idem pour les pièces jointes
des signalements.

**Cloisonnement des données sensibles.** Les antécédents médicaux
(`MedicalHistoryServiceImpl.checkAccess()`) exigent une relation de soin établie ; les
notes cliniques lèvent une `ForbiddenOperationException` sur contrôle de propriété ;
le portefeuille patient passe par `findOwnedPatientProfile()`, propriétaire strict.

**Chaîne d'autorisation de user-service.** La plus fine du projet, avec un
`denyAll()` final — donc tout endpoint oublié est refusé par défaut, et non ouvert.
L'ordre des règles est correct : le justificatif du psychologue est explicitement
placé en `authenticated()` **avant** le `permitAll()` de l'annuaire.

**Stockage du jeton côté client.** `flutter_secure_storage` (Keychain / Keystore), et
non `SharedPreferences`. `ApiClient` n'imprime jamais le token.

**Absence de journalisation des données de santé.** Aucun log dans
`ClinicalNoteServiceImpl`, `QuestionnaireServiceImpl`, `MedicalHistoryServiceImpl`,
`JournalEntryServiceImpl`. Le service IA le documente explicitement :

> *« Ce service ne stocke RIEN : pas de base de données, pas de log du contenu des
> conversations »*

**Code de réinitialisation.** Généré avec `java.security.SecureRandom` (et non
`java.util.Random`), expiration à 15 minutes, usage unique, invalidation des codes
précédents à chaque nouvelle demande. La réponse de `forgot-password` est générique
pour ne pas révéler l'existence d'un compte — l'intention anti-énumération est là.

---

## 3. Les failles réelles, par ordre de gravité

### 3.1 Le code de réinitialisation est renvoyé dans la réponse HTTP

**Gravité : critique.** C'est une prise de contrôle de n'importe quel compte à partir
du seul e-mail.

```java
@Value("${app.password-reset.expose-code-in-response:true}")
private boolean exposeCodeInResponse;
...
return new ForgotPasswordResponse(generic, exposeCodeInResponse ? code : null);
```

Le défaut est `true` à deux niveaux — le fallback du `@Value`, et
`application.properties` (`PASSWORD_RESET_EXPOSE_CODE:true`) — et
**`docker-compose.yml` ne surcharge pas la variable**. Dans la pile telle qu'elle est
livrée, le code sort donc dans le champ `devCode`.

Effet de bord : la réponse générique anti-énumération est neutralisée, puisque
`devCode != null` signifie que le compte existe.

**Cause réelle :** aucun envoi d'e-mail n'est implémenté (pas de
`spring-boot-starter-mail`, pas de configuration SMTP). Le `devCode` est la seule
façon de faire fonctionner la réinitialisation en démonstration.

### 3.2 Aucune limitation du nombre de tentatives

**Gravité : élevée.** `resetPasswordWithCode()` n'a ni compteur, ni verrouillage, ni
délai ; l'entité `PasswordResetCode` n'a pas de champ `attempts`. Un code à
6 chiffres, c'est 10⁶ possibilités, brut-forçables pendant les 15 minutes de validité.

Aucun rate-limiting non plus sur `/auth/login` (pas de verrouillage de compte) ni sur
`/auth/forgot-password` (spam de codes possible).

### 3.3 Le code de réinitialisation est écrit en clair dans les logs

**Gravité : élevée.** `auth-service/service/AuthService.java` :

```java
LOGGER.info("Code de réinitialisation pour {} (userId={}) : {} (valable {} min)",
        user.getEmail(), user.getId(), code, CODE_VALIDITY_MINUTES);
```

Niveau INFO, donc toujours actif. L'accès aux logs devient un accès à tous les comptes.

### 3.4 Secret JWT unique, en dur, versionné

**Gravité : élevée.**
`myVerySecretKeyForPsyConnectApplicationJWT2026SecurityKey` figure en clair dans
`docker-compose.yml` (7 services) **et** comme valeur par défaut dans chaque
`application.properties`. Le fichier est suivi par git.

Une seule clé symétrique partagée par tous les services, sans rotation ni audience :
qui la connaît peut **forger un jeton `role=ADMIN` accepté partout**.

Le `.gitignore` prévoit bien une section « Secrets / config locale » (`.env`,
`application-local.properties`) — mais elle est inopérante, puisque les secrets ne
sont pas dans ces fichiers-là. Même remarque pour le mot de passe PostgreSQL
(`postgres`) et le mot de passe admin par défaut (`Admin@2026`).

### 3.5 Tout circule en HTTP, en clair

**Gravité : élevée en production, acceptable en local.**

- `api_constants.dart` : `defaultValue: 'http://MacBook-Pro-de-ndeye.local:8080'`
- `AndroidManifest.xml` : `android:usesCleartextTraffic="true"` — actif y compris en
  release, et aucun `network_security_config.xml` dans le dépôt
- Aucun `https` nulle part ; tous les ports de `docker-compose.yml` sont en HTTP nu

Le jeton d'authentification transite donc en clair. Côté iOS le réglage est plus
sain : `NSAllowsLocalNetworking` seul, pas de `NSAllowsArbitraryLoads`.

### 3.6 `POST /notifications` est ouvert sans authentification

**Gravité : moyenne.** `notification-service/config/SecurityConfig.java` :

```java
.requestMatchers(HttpMethod.POST, "/notifications").permitAll()
.anyRequest().authenticated()
```

Le commentaire justifie l'ouverture par *« la route reste protégée côté gateway »*.
**C'est faux** : l'api-gateway n'a aucune sécurité (voir §4). N'importe qui peut donc
fabriquer une notification adressée à n'importe quel `userId`.

### 3.7 Tout psychologue peut lire le profil de tout patient

**Gravité : moyenne.** `PatientProfileServiceImpl.getPatientProfile()` :

```java
if (!isOwner && !callerIsPsychologist && !callerIsAdmin) {
    throw new ForbiddenOperationException("Ce profil patient ne vous appartient pas");
}
```

Le rôle `PSYCHOLOGIST` suffit — **aucune relation de soin n'est exigée**. Un
psychologue peut énumérer les identifiants et lire les fiches de patients qui ne sont
pas les siens. Le mode anonyme masque le nom, mais pas le reste.

Deux conséquences dérivées :

- `emergencyContactName` et `emergencyContactPhone` ne sont **pas** pseudonymisés et
  restent visibles (`patients_tab.dart`) — le pseudonyme protège le nom, pas le
  contact d'urgence, qui porte souvent le patronyme familial ;
- `GET /recommendations/{patient_id}` du ml-service hérite exactement de ce contrôle.

Le contraste est net avec `MedicalHistoryServiceImpl`, qui exige lui une relation
établie : le bon modèle existe déjà dans le projet, il n'est simplement pas appliqué ici.

### 3.8 Fuite de métadonnée de santé

**Gravité : faible à moyenne.** `GET /appointments/exists/between?psychologistId=&patientId=`
n'a aucun contrôle de rôle — le commentaire dit *« la protection est faite en amont »*.
Tout utilisateur authentifié peut donc apprendre s'il existe une relation de soin entre
un psychologue et un patient donnés. Métadonnée sensible dans ce domaine précis, et
énumérable.

### 3.9 Session d'urgence : trois contrôles absents

**Gravité : moyenne.** La fonctionnalité d'appel d'urgence est inachevée côté
praticien (voir §5), mais ses endpoints sont bien exposés — et ils sont ouverts.

**`POST /sessions/emergency` ne vérifie rien.** `SessionServiceImpl.startEmergencySession()`
ne contrôle ni le rôle de l'appelant, ni que le `patientId` transmis correspond
bien à lui. Le `SecurityConfig` de session-service se limite à
`anyRequest().authenticated()`. N'importe quel compte authentifié peut donc créer
une session d'urgence au nom de n'importe quel patient, contre n'importe quel
psychologue.

**`GET /sessions/{id}` court-circuite le contrôle de participation** pour les
sessions d'urgence :

```java
// pas de vérification de participation pour les sessions urgence
if (!Boolean.TRUE.equals(session.getEmergencyMode())) {
    AppointmentDto appt = appointmentClient.getAppointment(session.getAppointmentId());
    checkParticipant(appt);
}
return mapToResponse(session);
```

Les identifiants étant auto-incrémentés, tout compte authentifié peut les énumérer
et récupérer le `meetingToken` — c'est-à-dire le nom de la salle Jitsi — de
n'importe quelle consultation d'urgence.

**`setEmergencyAvailability` n'a aucun contrôle de propriété** (le commentaire du
code l'assume). Un psychologue connaissant l'identifiant d'un confrère peut activer
ou couper son mode urgence.

**La salle Jitsi n'a pas de second verrou.** Serveur public communautaire
(`meet.ffmuc.net`), `lobby.enabled: false` et `meeting-password.enabled: false` : le
nom de salle est le seul élément d'authentification, et il est distribué par
l'endpoint ci-dessus. Le token vaut `psyconnect-sos-{patientId}-{8 hex}` — 32 bits
d'aléa derrière un préfixe constant et un identifiant séquentiel.

**Correctifs :** contrôler le rôle et la propriété du `patientId` à la création ;
appliquer `checkParticipant` aux sessions d'urgence en comparant
`emergencyPatientId` / `emergencyPsychologistId` à l'appelant ; ajouter le contrôle
de propriété sur la bascule de disponibilité. Les trois sont locaux et courts.

### 3.10 Politique de mot de passe minimale

**Gravité : faible.** `RegisterRequest` : `@NotBlank` + `@Size(min = 6)`. Aucun
`@Pattern`, aucun maximum, aucune exigence de composition. Pas de vérification contre
une liste de mots de passe compromis, pas d'historique.

### 3.11 Validation du type de fichier fondée sur la déclaration du client

**Gravité : faible.** La liste blanche existe
(`application/pdf`, `image/png`, `image/jpeg`) mais s'appuie sur
`file.getContentType()`, c'est-à-dire l'en-tête `Content-Type` de la partie multipart —
falsifiable trivialement. Pas de contrôle des octets magiques. L'extension du nom
client est conservée telle quelle (un `.php` ou `.svg` finit sur disque), sans liste
blanche. Impact limité : le dossier n'est pas servi statiquement, la lecture passe par
un contrôleur. Aucune limite de taille applicative — seulement
`spring.servlet.multipart.max-file-size=20MB`. Fichiers non chiffrés au repos.

### 3.12 Surfaces d'administration exposées

**Gravité : faible en local.**

- **eureka-server** n'a pas Spring Security : dashboard, registre des instances et
  `/actuator/health` ouverts sur `:8761`.
- **api-gateway** non plus : `/actuator/health` ouvert sur `:8080`.
- **ml-service** (FastAPI) expose `/docs`, `/redoc` et `/openapi.json` sans
  authentification, et `docker-compose.yml` publie le port `8000:8000`.

Les autres services sont couverts par `anyRequest().authenticated()`, donc leur
actuator exige un jeton — y compris là où `show-details=always` est activé
(appointment, payment, session). Aucun Swagger côté Java.

### 3.13 Adresses e-mail dans les logs applicatifs

**Gravité : faible, mais sensible au regard du RGPD.**
`payment-service/security/JwtAuthenticationFilter.java` logue en INFO à chaque
requête : `LOGGER.info("[payment-JWT] JWT valide pour {} | role={} | uri={}", username, role, uri)`
où `username` est l'e-mail. Des adresses d'utilisateurs d'une application de santé
mentale circulent donc dans les logs. Deux services laissent en outre le niveau DEBUG
activé en dur (`payment-service`, `user-service`).

Le filtre prend soin, lui, de ne jamais logger le jeton en entier — c'est bien fait.

---

## 4. Un choix d'architecture à assumer, pas une faille

**L'api-gateway ne fait aucune authentification.** Elle n'a ni `SecurityConfig`, ni
même la dépendance `spring-boot-starter-security` dans son `build.gradle` : elle route,
point. Toute la sécurité repose sur chaque microservice en aval, qui valide le JWT
lui-même avec le secret partagé.

**Ce choix est défendable** : il évite un point de confiance unique et garantit qu'un
service reste protégé même si on l'appelle directement, sans passer par la gateway.
C'est le modèle « zero trust interne ».

**Mais il faut être cohérent avec.** Deux commentaires du code affirment le contraire
(« la route reste protégée côté gateway » dans notification-service, « la protection
est faite en amont » dans appointment-service) et fondent une ouverture sur cette
croyance. Ce sont ces deux endroits qu'il faut corriger — pas l'architecture.

---

## 5. Périmètre assumé comme inachevé : l'appel d'urgence

Le parcours d'aide immédiate est **fonctionnel côté patient et absent côté
praticien**. Ce qui marche : le psychologue déclare sa disponibilité, le filtrage
backend s'applique (`profileVerified` ET `availableForEmergency`), la session est
créée en base, la salle Jitsi s'ouvre.

Ce qui n'existe pas : `startEmergencySession` n'envoie **aucune notification** au
psychologue (le `notificationClient` est injecté mais jamais appelé sur ce chemin) ;
aucun endpoint ne permet à un psychologue de retrouver ses sessions
(`SessionRepository` n'expose que des requêtes par `appointmentId`, or une session
d'urgence a `appointmentId = null`) ; et aucun écran côté praticien ne permet de
rejoindre un appel hors rendez-vous.

**C'est un choix de périmètre assumé**, inscrit dans les perspectives. Formulation
retenue pour la soutenance : *« le parcours patient est fonctionnel jusqu'à
l'ouverture de la salle ; la réception côté praticien — notification et accès à la
session — fait partie des perspectives. »*

La levée tient en trois pièces : une notification de type `SESSION` à la création,
un `GET /sessions/psychologist/{id}/active`, et un bandeau d'appel entrant sur
l'accueil du praticien.

## 6. Code mort à retirer avant la soutenance

`backend/video-service/` **n'existe plus sur le disque** et n'est pas dans
`docker-compose.yml` — il subsiste dans l'historique git. Or son
`SignalingHandler`/`WebSocketConfig` contient :

```java
registry.addHandler(signalingHandler, "/signal/*").setAllowedOrigins("*");
```

Aucune vérification de jeton, aucune vérification que l'appelant est participant, et
le `roomId` **est l'`appointmentId`** — donc n'importe qui pouvait rejoindre le
signaling d'une séance. La visioconférence semble avoir été reprise par le SDK Jitsi
(mentionné dans `ios/Runner/Info.plist`).

Vérifier avec `git ls-files backend/video-service` et, si le dossier est encore suivi,
le retirer. Un jury qui parcourt le dépôt tombera dessus et posera la question.

---

## 7. Plan de correction

### À faire avant la soutenance — moins d'une heure

| # | Correctif | Fichier |
|---|---|---|
| 1 | Déclarer explicitement `PASSWORD_RESET_EXPOSE_CODE: "true"` dans `docker-compose.yml`, avec un commentaire `# DÉMONSTRATION UNIQUEMENT — false dès qu'un envoi SMTP existe` | `docker-compose.yml` |
| 2 | Passer le log du code de réinitialisation de `INFO` à `DEBUG`, ou n'y écrire que l'identifiant utilisateur | `auth-service/service/AuthService.java` |
| 3 | Corriger les deux commentaires qui prétendent que la gateway protège les routes | `notification-service/config/SecurityConfig.java`, `appointment-service/.../AppointmentServiceImpl.java` |
| 4 | Retirer `backend/video-service` du suivi git s'il y est encore | dépôt |
| 5 | Baisser les niveaux `DEBUG` laissés en dur | `payment-service`, `user-service` — `application.properties` |

Déclarer explicitement le drapeau plutôt que le désactiver est un choix assumé : la
réinitialisation doit rester démontrable puisqu'aucun SMTP n'existe. L'important est
de montrer que la frontière dev/prod est **identifiée et nommée**, pas cachée.

### Correctifs de fond, si le temps le permet

| # | Correctif | Effort |
|---|---|---|
| 6 | Exiger une relation de soin dans `getPatientProfile()`, sur le modèle de `MedicalHistoryServiceImpl.checkAccess()` | moyen |
| 7 | Pseudonymiser `emergencyContactName` / `emergencyContactPhone` dans le même bloc conditionnel que `firstName` | faible |
| 8 | Ajouter un champ `attempts` à `PasswordResetCode` et invalider le code au bout de 5 essais | faible |
| 9 | Retirer `permitAll()` sur `POST /notifications` et faire circuler le jeton entre services | moyen |
| 10 | Sortir le secret JWT et le mot de passe de base vers un `.env` non versionné (le `.gitignore` le prévoit déjà) | faible |
| 11 | Ajouter un contrôle de rôle sur `GET /appointments/exists/between` | faible |
| 13 | Contrôler rôle et propriété sur `POST /sessions/emergency` | faible |
| 14 | Appliquer `checkParticipant` aux sessions d'urgence dans `GET /sessions/{id}` | faible |
| 15 | Contrôle de propriété sur `setEmergencyAvailability` | faible |
| 12 | Renforcer la politique de mot de passe (`@Size(min = 10)` + `@Pattern`) | faible |

### Hors périmètre d'un projet académique local

HTTPS et certificats, chiffrement des fichiers au repos, antivirus sur les uploads,
rotation des clés, WAF. À citer comme prérequis d'une mise en production, pas à
implémenter.

---

## 8. Formulation pour la soutenance

Si la question vient, la réponse honnête et la plus solide est celle-ci :

> La sécurité applicative repose sur trois piliers implémentés et testés : BCrypt pour
> les mots de passe, une validation du JWT dans chaque microservice plutôt qu'au seul
> point d'entrée, et un contrôle de propriété systématique qui ne fait jamais confiance
> aux identifiants passés dans l'URL — c'est l'`OwnershipResolver`, qui reconstruit
> l'identité métier à partir du token.
>
> Les limites que j'assume sont celles d'un déploiement local : le transport est en
> HTTP, le secret JWT est unique et versionné, et la réinitialisation de mot de passe
> renvoie son code dans la réponse parce qu'aucun service d'envoi d'e-mail n'a été
> intégré. Ces trois points sont documentés et le passage en production consiste
> précisément à les lever.

C'est mieux que de prétendre que tout est couvert : un jury teste surtout la capacité
à **identifier** ses propres faiblesses.

---

## Annexe — méthode

Revue statique du code, sans exécution ni test d'intrusion. Sources lues :
`SecurityConfig` des 7 services Spring, `AuthService`, `AppointmentServiceImpl`,
`MessagingServiceImpl`, `PatientProfileServiceImpl`, `FileStorageService`,
`EvidenceStorageService`, `JwtAuthenticationFilter` de payment-service, les 9
`application.properties`, les 9 `build.gradle`, `docker-compose.yml`, `.gitignore`,
`ml-service/app/main.py`, ainsi que `api_constants.dart`, `api_client.dart`,
`token_storage.dart`, `AndroidManifest.xml` et `Info.plist`.

Certains fichiers Java ont été lus depuis l'index git, légèrement antérieur au disque
(une passe de suppression de commentaires a eu lieu le 28/08 après le dernier
`git add`). Les conclusions portant sur `AuthService.java` et sur les `SecurityConfig`
de user-service et appointment-service méritent une relecture directe si des
modifications de logique ont eu lieu depuis.

---

## 7. Corrections apportées le 04/09/2026 — flux « mot de passe oublié »

Cette section ferme les points **3.1**, **3.2** et **3.3** de l'audit, et documente ce qui reste ouvert
sur ce flux.

### 7.1 Point 3.1 — le code n'est plus renvoyé dans la réponse HTTP : **corrigé**

Le champ `devCode` n'a pas été désactivé, il a été **supprimé** de `ForgotPasswordResponse`, ainsi que la
propriété `app.password-reset.expose-code-in-response` qui le pilotait et la variable d'environnement
`PASSWORD_RESET_EXPOSE_CODE`. Le drapeau valait `true` par défaut : le désactiver aurait laissé un
interrupteur qu'un déploiement distrait pouvait rallumer. Un champ qui n'existe plus ne se rallume pas.

Côté Flutter, le `devCode` disparaît de la même façon : `AuthService.forgotPassword` ne lit plus le champ,
`AuthProvider.forgotPassword` renvoie désormais un booléen, et l'encart jaune « mode démo » qui affichait
le code à l'écran est retiré de `ResetPasswordScreen`.

### 7.2 Point 3.2 — limitation des tentatives : **corrigé**

Deux verrous complémentaires.

**Sur la vérification du code** : la table `password_reset_codes` gagne une colonne `attempts`. Chaque code
soumis qui ne correspond pas l'incrémente ; au cinquième échec le code est marqué comme utilisé, donc mort.

L'ordre de grandeur, utile à citer : un code à six chiffres représente un million de combinaisons. Sans
limite, sur la fenêtre de validité de quinze minutes, un script tentant cinquante codes par seconde en
essaie quarante-cinq mille, soit **environ 4,5 % de chances de réussite par code**, répétable à volonté.
Avec cinq essais maximum, la probabilité tombe à **1 sur 200 000**.

S'y ajoute un effet du hachage (voir 7.4) : la vérification passe par BCrypt, volontairement lent
(de l'ordre de 100 ms), ce qui plafonne mécaniquement le débit d'une attaque même sans compteur.

**Sur la demande de code** : nouveau composant `ResetRequestThrottle`, trois demandes maximum par adresse
sur quinze minutes glissantes. Sans lui, on pouvait inonder la boîte mail d'un utilisateur, et exploiter
l'écart de temps de réponse entre une adresse connue et une adresse inconnue pour contourner la réponse
générique. La réponse renvoyée en cas de dépassement reste strictement identique.

Limite assumée : ce compteur est en mémoire, donc propre à une instance. Avec plusieurs répliques
d'`auth-service` il faudrait le déporter dans Redis. À l'échelle du projet, c'est une perspective, pas un
défaut.

### 7.3 Point 3.3 — le code n'est plus écrit dans les logs : **corrigé**

La ligne de journal ne contient plus ni le code ni l'adresse e-mail, seulement l'identifiant utilisateur et
la durée de validité. C'était une fuite distincte de 3.1, qui lui aurait survécu : toute personne ayant
accès aux journaux du conteneur pouvait réinitialiser n'importe quel compte.

### 7.4 Amélioration non listée dans l'audit : le code est désormais haché

Le code était stocké en clair. Un accès en lecture à la base — sauvegarde, capture, injection SQL ailleurs
dans le système — permettait de réinitialiser n'importe quel compte pendant la fenêtre de validité. Il est
maintenant haché avec le même `PasswordEncoder` que les mots de passe, et la colonne renommée `code_hash`
pour que l'intention soit lisible dans le schéma.

### 7.5 Envoi réel de l'e-mail

`auth-service` embarque `spring-boot-starter-mail` et envoie le code via un composant dédié
`PasswordResetMailer`, en `@Async` : l'échec ou la lenteur du serveur SMTP ne bloque ni ne casse la
réponse HTTP, le code étant déjà enregistré.

**L'envoi part d'`auth-service`, pas de `notification-service`.** Décision assumée : le code de
réinitialisation est un secret, le faire transiter par un service supplémentaire multiplierait la surface
de fuite et les modes de panne ; et `notification-service` adresse des identifiants de profil patient ou
psychologue, alors qu'il s'agit ici d'écrire à une adresse e-mail brute, pour un utilisateur qui peut ne
pas avoir de profil métier.

Deux précautions dans le message lui-même : **le code est dans le corps, jamais dans l'objet** — un objet
s'affiche sur un écran verrouillé — et le message rappelle la durée de validité, l'usage unique, et la
conduite à tenir si la demande n'émane pas du destinataire.

La configuration SMTP est entièrement pilotée par variables d'environnement. Par défaut elle pointe vers
**Mailpit**, serveur de capture ajouté au `docker-compose.yml`, dont l'interface web est exposée sur le
port 8025 : aucun identifiant à stocker, aucune dépendance réseau, et une démonstration reproductible.
Basculer vers un envoi réel ne demande aucune modification de code.

### 7.6 Ce qui reste ouvert sur ce flux

**Les jetons JWT émis avant la réinitialisation restent valides** jusqu'à leur expiration. Les jetons étant
sans état et sans liste de révocation, changer le mot de passe ne ferme pas les sessions déjà ouvertes : un
attaquant disposant d'un jeton valide le conserve. C'est la limite la plus sérieuse subsistant sur ce
parcours, et elle mérite d'être citée en perspective plutôt que découverte par le jury.

**Le transport reste en HTTP** (point 3.5 de l'audit, inchangé) : le code circule en clair entre
l'application et la passerelle.
