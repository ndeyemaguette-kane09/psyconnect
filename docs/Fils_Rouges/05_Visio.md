# 05 — Le patient et le psy se retrouvent en visio

Ce fil suit une séance en ligne : de l'appui sur « Rejoindre » jusqu'à la clôture automatique de la
session. Le service central est `session-service` ; la vidéo elle-même est assurée par Jitsi Meet.

Vérifié dans le code le 24/09/2026.

---

## En une phrase

session-service crée **un seul** salon Jitsi par rendez-vous, même si le patient et le psy cliquent au
même instant, et le téléphone ouvre ce salon avec le SDK Jitsi ; la vidéo ne passe jamais par nos serveurs.

## Qui fait quoi

| Élément | Rôle |
|---|---|
| Application Flutter (`features/call/screens/call_screen.dart`) | demande la session, ouvre la visio avec le SDK `jitsi_meet_flutter_sdk` |
| session-service (port 8089) | vérifie les droits et l'horaire, crée ou retrouve la session, fournit le nom du salon |
| Serveur Jitsi public `meet.ffmuc.net` | transporte l'audio et la vidéo (WebRTC) |
| appointment-service | fournit le rendez-vous, passe à `COMPLETED` à la fin |

PsyConnect ne transporte **aucun flux vidéo**. Il ne gère que le « qui a le droit d'entrer dans quel
salon, et quand ».

## Étape 1 — Le bouton n'apparaît qu'au bon moment

`appointments_tab.dart` (ligne 446, patient) et `agenda_tab.dart` (ligne 201, psy) : le bouton
« Rejoindre » n'est actif que si le rendez-vous est `CONFIRMED` et que l'heure est comprise entre
**10 minutes avant le début et 30 minutes après la fin**.

## Étape 2 — Demander la session

`call_screen.dart`, ligne 119 : `_sessionService.startSession(appointmentId)`, soit
`POST /sessions/start`.

## Étape 3 — session-service vérifie et crée (`SessionServiceImpl.startSession`, ligne 74)

1. **Récupère le rendez-vous** auprès d'appointment-service.
2. **Vérifie que l'appelant y participe** (`checkParticipant`) : patient de ce rendez-vous ou psy de ce
   rendez-vous, identité résolue depuis le jeton.
3. **Entre dans une zone verrouillée** (`synchronized (sessionStartLock)`, ligne 78).
4. **Cherche une session déjà ouverte** pour ce rendez-vous (ligne 88). Si elle existe, il la renvoie :
   c'est ce qui fait que les deux participants arrivent dans le même salon.
5. Sinon, il contrôle le statut (`CONFIRMED`, sinon « paiement requis ») et la fenêtre horaire (même règle
   des 10 minutes avant et 30 minutes après que dans l'application).
6. **Crée la session** avec un nom de salon unique : `psyconnect-{idRdv}-{8 caractères aléatoires}`
   (ligne 114), statut `IN_PROGRESS`.

## Le bug corrigé qui fait une bonne histoire de soutenance

Avant le verrou, le code faisait déjà « chercher, puis créer si absent ». Mais les deux étapes n'étaient
pas **atomiques**. Quand le patient et le psy cliquaient à quelques millisecondes d'écart :

```
Patient : cherche → rien          Psy : cherche → rien
Patient : crée le salon A         Psy : crée le salon B
```

Chacun se retrouvait seul dans son salon. C'est une **situation de concurrence** (*race condition*),
repérée en test réel, et corrigée le 02/09/2026 par le bloc `synchronized` : une seule requête à la fois
peut chercher et créer.

Limite assumée, écrite dans le commentaire du code (lignes 40-48) : le verrou ne protège qu'**une
instance** de session-service. Avec plusieurs instances derrière la passerelle, il faudrait un verrou en
base (contrainte d'unicité sur « rendez-vous + session en cours ») ou un verrou distribué.

## Étape 4 — Ouvrir la visio

`call_screen.dart`, ligne 150 : le SDK Jitsi ouvre le salon sur `https://meet.ffmuc.net`.

Pourquoi ce serveur et pas `meet.jit.si` ? Le serveur officiel impose une salle d'attente aux utilisateurs
anonymes, impossible à désactiver depuis l'application. `meet.ffmuc.net` est un serveur Jitsi public sans
cette contrainte. Le nom affiché dans la visio est le **pseudo** de l'utilisateur, pas son nom réel.

## Étape 5 — Raccrocher ne ferme pas la séance

Si un participant raccroche (ou perd le réseau), l'application revient à l'écran d'avant-appel **sans
fermer la session** (`_onConferenceTerminated`). Il peut rejoindre à nouveau : l'étape 3 point 4 lui
renverra le même salon.

## Étape 6 — La clôture automatique

Puisque le téléphone ne ferme plus la session, un job planifié s'en charge :
`SessionExpiryScheduler` (toutes les 5 minutes, ligne 59). Il passe en `COMPLETED` les sessions dont le
rendez-vous est terminé depuis plus de 30 minutes.

La fermeture explicite existe aussi : `PUT /sessions/{id}/end` → `endSession` (ligne 146). Elle passe la
session en `COMPLETED`, demande à appointment-service de passer le rendez-vous en `COMPLETED`, et notifie
le patient.

## La variante : l'appel d'urgence

`POST /sessions/emergency` → `startEmergencySession` (ligne 128). Pas de rendez-vous : un salon
`psyconnect-sos-{idPatient}-{aléatoire}` est créé immédiatement avec un psychologue marqué disponible pour
l'urgence. C'est un **démonstrateur**, présenté comme tel dans le mémoire.

---

## Ce que ce fil démontre

| Notion | Où |
|---|---|
| Situation de concurrence et exclusion mutuelle | `synchronized (sessionStartLock)` |
| Opération idempotente (« get-or-create ») | chercher la session ouverte avant d'en créer une |
| Règle alignée client et serveur | fenêtre 10 min / 30 min des deux côtés |
| Tâche planifiée | `SessionExpiryScheduler` |
| Appels inter-services | session-service → appointment-service, notification-service |
| Déléguer ce qu'on ne sait pas bien faire | vidéo confiée à Jitsi |

## Limites et failles à connaître

1. **Verrou mono-instance** (voir plus haut).
2. **Seul le patient est notifié en fin de séance**, jamais le psychologue (lignes 165 et 184). Déjà cité
   dans les limites du mémoire.
3. **Le salon Jitsi n'est pas protégé par mot de passe.** Quiconque connaît le nom du salon peut entrer.
   Le suffixe aléatoire le rend difficile à deviner, mais ce n'est pas un contrôle d'accès. Une
   instance Jitsi à nous, avec des jetons JWT Jitsi, fermerait ce point.
4. **Serveur public tiers** : la disponibilité et la confidentialité dépendent de `meet.ffmuc.net`. Les
   flux WebRTC sont chiffrés en transit, mais le serveur relais n'est pas sous notre contrôle.
5. **L'appel d'urgence n'a presque aucun contrôle** : l'identifiant du patient vient de la requête, et
   `getSessionById` ne vérifie pas la participation pour les sessions d'urgence. Déjà listé dans
   `Audit_Securite.md`, section 3.9.

## Questions probables du jury

**« Pourquoi Jitsi et pas WebRTC codé vous-même ? »**
Un appel vidéo fiable demande un serveur de signalisation, des serveurs STUN et TURN pour traverser les
box et les pare-feu, et la gestion des codecs. Un microservice WebRTC natif a été commencé puis abandonné
le 28/08/2026 : Jitsi fournit tout cela, et le projet se concentre sur ce qui lui est propre, les droits
et les horaires.

**« Comment garantissez-vous que les deux participants arrivent dans le même salon ? »**
Le serveur fabrique le nom du salon, pas le téléphone. Et la création est en exclusion mutuelle : le
second qui arrive récupère la session créée par le premier.

**« Et à grande échelle ? »**
Le `synchronized` ne suffit plus avec plusieurs instances. La solution la plus simple est une contrainte
d'unicité en base : la seconde insertion échoue, on relit alors la session existante.
