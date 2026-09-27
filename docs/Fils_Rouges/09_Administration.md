# 09 — L'administrateur valide un psy, traite un signalement, diffuse une annonce

Ce fil suit le troisième acteur du projet. L'administrateur ne soigne personne : il garantit la
**confiance** dans la plateforme (qui a le droit d'exercer), la **modération** (signalements, comptes) et
la **communication** (annonces). Ses actions sont réparties dans quatre services.

Vérifié dans le code le 24/09/2026.

---

## En une phrase

Toutes les adresses d'administration commencent par `/admin/` et sont réservées au rôle ADMIN dans chaque
service ; l'admin valide les psychologues sur justificatif, modère les signalements et les comptes, règle
la commission et diffuse des annonces.

## Comment l'admin existe

On ne peut pas s'inscrire administrateur : `AuthService.register` refuse le rôle ADMIN. Le compte est créé
au premier démarrage d'auth-service par `AdminBootstrap`, seulement s'il n'existe encore aucun admin
(identifiants par défaut `admin@psyconnect.sn`, modifiables par variables d'environnement).

Chaque service protège ses routes d'administration de la même façon :

```java
.requestMatchers("/admin/**").hasRole("ADMIN")
```

Le rôle vient du jeton. Pas d'appel à auth-service.

## Parcours A — Valider un psychologue

### Étape 1 — Le psy envoie son justificatif

À l'inscription, puis si besoin depuis « Modifier le profil » :
`POST /psychologists/{id}/license-document` → `PsychologistProfileServiceImpl.uploadLicenseDocument`
(ligne 370).

- Le profil doit appartenir à l'appelant.
- Le fichier ne doit pas être vide.
- Type accepté : **PDF, PNG ou JPEG** uniquement (`ALLOWED_CONTENT_TYPES`, ligne 28).
- Taille maximale : **20 Mo** (`spring.servlet.multipart.max-file-size`).
- Le fichier est enregistré sous un **nom aléatoire** (UUID) et non sous son nom d'origine, avec une
  protection contre les chemins du type `../../` (`FileStorageService.store`). L'ancien justificatif est
  supprimé.

### Étape 2 — En attendant, le psy est invisible

Le psy peut se connecter et compléter son profil, mais un bandeau l'avertit. Surtout, **deux barrières
côté serveur** l'empêchent d'exercer :

1. la liste publique et la recommandation demandent `verifiedOnly=true` : il n'apparaît pas ;
2. `AppointmentServiceImpl.createAppointment` refuse un rendez-vous avec un psy non vérifié (ligne 102).

La barrière qui compte est la seconde : même en appelant l'API à la main, on ne peut pas réserver.

### Étape 3 — L'admin décide

L'admin ouvre le dossier et télécharge le justificatif
(`GET /psychologists/{id}/license-document`, réservé au propriétaire et à l'admin).

- **Valider** : `PATCH /admin/psychologists/{id}/verify?verified=true` → `setProfileVerified`
  (ligne 196). Le profil devient vérifié, `rejected` repasse à faux, le psy reçoit une notification.
- **Refuser** : `PATCH /admin/psychologists/{id}/reject?rejected=true` → `setProfileRejected`
  (ligne 234). Le profil devient refusé et non vérifié, le psy est notifié, et son accueil affiche le
  refus avec l'email et le téléphone de l'administration.

Pourquoi deux champs, `profileVerified` et `rejected`, et pas un seul ? Parce qu'il y a **trois états** :
en attente, validé, refusé. Avec un seul booléen, « refuser » un profil en attente ne changeait rien :
c'était un vrai bug, corrigé le 22/06/2026.

## Parcours B — Traiter un signalement

### Étape 1 — Le patient signale

Depuis la fiche d'un psy : `POST /patients/{id}/reports` → `ReportServiceImpl.createReport` (ligne 38).

- Le patient ne peut signaler **qu'en son propre nom** (vérification du jeton).
- Motif dans une liste fermée : tarif abusif, comportement inapproprié, fausses informations, paiement
  demandé hors application, autre.
- Description et **preuve facultative** (capture, document), stockée comme le justificatif.

### Étape 2 — L'admin tranche (`reviewReport`, ligne 102)

Trois statuts : `PENDING` (en attente), `REVIEWED` (mesure prise), `DISMISSED` (non fondé). On ne peut pas
revenir à `PENDING`. L'admin peut ajouter une note.

Le psy concerné reçoit une notification, sans savoir qui l'a signalé : « Un signalement vous concernant a
été examiné… une mesure a été prise » ou « … jugé non fondé ». **Le patient reste anonyme pour le psy.**

### Étape 3 — Si besoin, désactiver le compte

`PATCH /admin/users/{id}/enabled?enabled=false` dans auth-service (`AdminServiceImpl.setUserEnabled`,
ligne 53). Deux garde-fous : on ne peut pas désactiver un admin, ni son propre compte. Un compte désactivé
ne peut plus se connecter (`BannedAccountException`).

## Parcours C — Diffuser une annonce

`POST /admin/notifications/broadcast` → `BroadcastServiceImpl.sendAsync`.

1. L'audience est vérifiée : `ALL`, `PATIENTS` ou `PSYCHOLOGISTS`.
2. Le contrôleur compte d'abord les destinataires et répond **tout de suite** à l'admin.
3. L'envoi se fait en **arrière-plan** (`@Async`) : l'annonce est d'abord enregistrée en base, donc
   visible dans l'application, puis une notification `ANNOUNCEMENT` part vers chaque destinataire, avec le
   bon rôle (patients et psys sont traités séparément, pour éviter la collision d'identifiants décrite au
   fil 08).
4. Un échec sur un destinataire est journalisé et n'arrête pas les autres.

C'est l'un des deux usages réels de l'asynchronisme dans le projet, avec l'envoi d'email du mot de passe
oublié (fil 01).

## Parcours D — Régler la commission

`PUT /admin/platform-settings/commission-rate` dans payment-service (`AdminController`, ligne 66). Le taux
doit être entre 0 et 100 %. Il est stocké dans une table à une seule ligne, `PlatformSettings`, créée
automatiquement à 20 % au premier accès. Voir le fil 04 pour son effet sur les revenus.

## Et aussi

- **Statistiques** : chaque service expose ses propres chiffres sous `/admin/stats/...` (comptes, profils,
  rendez-vous, paiements), et l'application les assemble sur le tableau de bord.
- **Support** : patients et psys peuvent écrire à l'administration ; l'admin répond, ce qui crée une
  notification `SUPPORT_REPLY`.

---

## Ce que ce fil démontre

| Notion | Où |
|---|---|
| Autorisation par rôle, répétée dans chaque service | `/admin/**` → `hasRole("ADMIN")` |
| Défense en profondeur | le psy non vérifié est bloqué à la réservation, pas seulement caché |
| Machine à états | en attente / validé / refusé ; PENDING / REVIEWED / DISMISSED |
| Téléversement de fichiers maîtrisé | type, taille, nom aléatoire, chemin contrôlé |
| Anonymat du signalant | notification sans identité |
| Asynchronisme | `@Async` de la diffusion |
| Garde-fous d'administration | pas de désactivation d'un admin ni de soi-même |

## Limites à connaître

1. **Le type de fichier est celui déclaré par le téléphone** (`getContentType()`), pas celui lu dans le
   contenu. Un fichier renommé en `.pdf` passe. Déjà dans `Audit_Securite.md`, section 3.11.
2. **Renvoyer un justificatif ne remet pas un psy refusé en attente.** Il reste dans « Refusés » jusqu'à
   ce que l'admin clique « Remettre en attente ».
3. **N'importe quel patient peut signaler n'importe quel psy**, sans rendez-vous commun. Risque de
   signalements abusifs, que l'admin doit trier.
4. **Un seul compte admin, sans journal d'audit** : on ne garde pas la trace de qui a validé ou refusé
   quoi, et quand. Choix assumé tant qu'il n'y a qu'un admin.
5. **La désactivation n'invalide pas les jetons déjà émis** (fil 01, limite 4) : le compte banni garde
   l'accès jusqu'à 24 heures.

## Questions probables du jury

**« Comment vérifiez-vous qu'un psy est vraiment psychologue ? »**
Par un contrôle humain d'un justificatif. La plateforme ne peut pas vérifier seule un diplôme ; une
perspective est de s'adosser au registre officiel via un partenariat avec le ministère de la Santé.

**« Que voit l'admin des données de santé ? »**
Rien de clinique : ni notes, ni conversations Xalaat, ni messages. Il voit les comptes, les profils, les
signalements, les paiements et les statistiques.

**« Pourquoi l'admin n'est-il pas un service à part ? »**
Parce que chaque action d'administration porte sur les données d'un service précis. Les mettre dans un
service « admin » l'obligerait à écrire dans les bases des autres, ce qui casse le principe d'une base par
service.
