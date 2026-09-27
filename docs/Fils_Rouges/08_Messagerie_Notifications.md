# 08 — Un message part, une notification arrive

Deux mécanismes de communication, souvent confondus :

- la **messagerie** : patient et psy s'écrivent (dans `appointment-service`) ;
- les **notifications** : la plateforme prévient quelqu'un qu'il s'est passé quelque chose (dans
  `notification-service`).

Vérifié dans le code le 24/09/2026.

---

## En une phrase

Un message n'est possible qu'entre un patient et un psy qui ont eu au moins un rendez-vous ; il est stocké
dans appointment-service et récupéré par l'application toutes les 6 secondes. Les notifications sont
créées par les autres services et rangées par profil ET par rôle.

## Partie A — La messagerie

### Étape 1 — Ouvrir une conversation (`MessagingServiceImpl.startOrGetConversation`, ligne 85)

`POST /messages/conversations` avec l'identifiant de l'autre personne.

1. **Qui suis-je ?** Le serveur déduit mon identité du jeton : si je suis patient, je suis le patient de la
   conversation, et l'autre est le psy ; si je suis psy, c'est l'inverse. L'application ne peut pas se
   faire passer pour quelqu'un d'autre.
2. **Avons-nous un rendez-vous en commun ?** (`existsByPatientIdAndPsychologistId`, ligne 103). Sinon :
   « Impossible de démarrer une conversation sans rendez-vous en commun ». Un patient ne peut pas écrire à
   un psy qu'il n'a jamais consulté.
3. **Une seule conversation par couple** : si elle existe, on la renvoie ; sinon, on la crée
   (« get-or-create », comme les sessions vidéo du fil 05).

### Étape 2 — Envoyer un message (`sendMessage`, ligne 137)

- `checkParticipant` : l'appelant doit être le patient ou le psy de cette conversation.
- L'expéditeur est l'`authUserId` **tiré du jeton** (`SecurityUtils.currentAuthUserId()`), pas un champ
  de la requête.
- La conversation garde la date du dernier message, pour trier la liste.

### Étape 3 — Recevoir : le polling

Il n'y a pas de connexion permanente. L'écran de discussion **redemande les messages toutes les 6
secondes** (`chat_screen.dart`, ligne 48, `Timer.periodic`). Le badge des messages non lus sur la barre
de navigation est rafraîchi toutes les 10 secondes (`patient_shell.dart`, ligne 61).

### Étape 4 — Marquer comme lu (`markConversationRead`)

`PATCH /messages/conversations/{id}/read` : tous les messages **reçus** (expéditeur différent de moi) et
non lus reçoivent une date de lecture.

## Partie B — Les notifications

### Qui les crée

Aucun écran ne crée de notification. Ce sont les services qui appellent `POST /notifications` après un
événement :

| Type | Créée par | Exemple |
|---|---|---|
| `APPOINTMENT` | appointment-service | nouvelle demande, confirmation, annulation |
| `REMINDER` | appointment-service (tâche planifiée) | rendez-vous dans 10 minutes |
| `PAYMENT` | payment-service, user-service | paiement confirmé, recharge |
| `SESSION` | session-service | séance terminée |
| `QUESTIONNAIRE`, `QUESTIONNAIRE_RESULT` | appointment-service | questionnaire reçu, résultats |
| `SYSTEM` | user-service | profil validé ou refusé, signalement traité |
| `ANNOUNCEMENT` | user-service (diffusion admin) | annonce à tous |
| `SUPPORT_REPLY` | user-service | réponse de l'admin au support |

Neuf types au total (`NotificationType.java`).

L'appel passe par un `NotificationClient` protégé par Resilience4j : **si notification-service est en
panne, l'action principale réussit quand même**. La notification est perdue, pas le rendez-vous.

### Le piège des identifiants : pourquoi un rôle

Un patient et un psy peuvent avoir **le même numéro de profil** : les tables `patient_profiles` et
`psychologist_profiles` ont chacune leur compteur. Sans précaution, le psy n° 3 verrait les notifications
du patient n° 3.

La solution : chaque notification porte `userId` **et** `userRole`. La lecture
(`NotificationServiceImpl`, lignes 76-100) filtre sur les deux, et `checkOwnership` (ligne 46) vérifie
que le rôle et l'identifiant de l'appelant correspondent avant de marquer une notification comme lue.

### Côté application

L'accueil interroge `GET /notifications/user/{id}` pour afficher le badge de la cloche et la liste.

---

## Ce que ce fil démontre

| Notion | Où |
|---|---|
| Règle métier comme contrôle d'accès | rendez-vous en commun obligatoire pour écrire |
| Identité tirée du jeton | expéditeur, rôle dans la conversation |
| Idempotence | « get-or-create » de la conversation |
| Polling | 6 s pour les messages, 10 s pour le badge |
| Service dédié aux notifications | notification-service, alimenté par tous les autres |
| Clé composite pour éviter une collision | `userId` + `userRole` |
| Tolérance aux pannes | notifications best effort |

## Limites et failles à connaître

1. **`POST /notifications` est ouvert sans authentification** (`SecurityConfig` de notification-service,
   ligne 42, `permitAll`). N'importe qui capable d'atteindre la passerelle peut créer une fausse
   notification chez n'importe quel utilisateur, par exemple un faux message de l'administration. Déjà
   dans `Audit_Securite.md`, section 3.6, et **toujours pas corrigé**. Correctif : exiger un jeton, ou
   une clé réservée aux services internes.
2. **Le polling est coûteux** : chaque téléphone ouvert sur une discussion fait 10 requêtes par minute,
   même sans nouveau message. À grande échelle, on passerait à des WebSockets ou à des notifications push
   (Firebase Cloud Messaging).
3. **Pas de notification push** : si l'application est fermée, rien n'arrive sur le téléphone. Les
   notifications ne sont visibles qu'en ouvrant l'application.
4. **Pas de notification quand un message arrive** : la messagerie n'appelle pas notification-service ;
   seul le badge des non-lus le signale.
5. **Les messages ne sont pas chiffrés de bout en bout.** Ils sont stockés en clair dans la base
   d'appointment-service, et circulent en HTTP en développement (`Audit_Securite.md`, section 3.5).

## Questions probables du jury

**« C'est du temps réel ? »**
Non, c'est du quasi-temps réel par polling : un message apparaît au plus 6 secondes après son envoi.
C'est suffisant pour une messagerie entre séances, qui n'est pas un chat d'urgence. Le vrai temps réel
passerait par WebSocket.

**« Pourquoi un service à part pour les notifications ? »**
Parce que tous les services en ont besoin. Plutôt que chacun gère sa propre table et sa propre lecture, un
seul service les centralise, et l'application n'a qu'un endroit à interroger.

**« Un psy peut-il écrire à un patient qu'il n'a jamais vu ? »**
Non : il faut au moins un rendez-vous en commun, quel que soit son statut.
