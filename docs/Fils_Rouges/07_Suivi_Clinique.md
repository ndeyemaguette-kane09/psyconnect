# 07 — Le psy suit un patient : lien de suivi, notes cliniques, antécédents

Ce fil suit ce que le psychologue fait **entre** les séances : marquer un patient comme suivi, écrire des
notes que lui seul peut lire, consulter et compléter les antécédents médicaux. Tout se passe dans
`user-service`.

Vérifié dans le code le 24/09/2026.

---

## En une phrase

Le bouton « Marquer comme suivi » crée un lien psy–patient en base ; ce lien ouvre au psy les notes
cliniques et les antécédents de ce patient, et les notes restent visibles de leur seul auteur.

## Étape 1 — Créer le lien de suivi

Fiche patient côté psy → `POST /psychologists/{psyId}/followed-patients/{patientId}`
→ `PsyPatientLinkServiceImpl.addFollowedPatient` (ligne 32).

1. **L'appelant est bien le psy `psyId`** (`ensureCallerOwnsPsychologistProfile`) : un psy ne peut gérer
   que sa propre liste, et un admin non plus.
2. Le patient existe.
3. **Un rendez-vous accepté existe** entre ce psy et ce patient (statut `CONFIRMED` ou `COMPLETED`).
   user-service le demande à appointment-service (`AppointmentClient.hasAcceptedAppointmentBetween`).
   Sinon : « Vous ne pouvez suivre un patient qu'après avoir accepté un rendez-vous avec lui ». Si
   appointment-service ne répond pas, le repli renvoie « non » : le lien est refusé (on tombe fermé).
   Ajouté le 25/09/2026, voir limite 1.
4. Le lien est créé s'il n'existe pas déjà. Une **contrainte d'unicité** en base empêche les doublons, et
   l'opération est **idempotente** : l'appeler deux fois ne change rien.

Retirer le lien (`DELETE`) est idempotent aussi : pas d'erreur si le lien n'existait pas.

Historique utile à raconter : avant, l'accès aux notes dépendait d'un appel à appointment-service
(« ce psy a-t-il eu un rendez-vous avec ce patient ? »). Si appointment-service tombait, les notes
devenaient inaccessibles. Le lien est maintenant **stocké localement** dans user-service : moins de
dépendance, moins de pannes en cascade.

## Étape 2 — Les notes cliniques

`/patients/{id}/clinical-notes` (lecture, création), `/clinical-notes/{noteId}` (modification,
suppression) → `ClinicalNoteServiceImpl`.

Deux verrous successifs :

1. **Être psychologue** : le profil psy est retrouvé depuis le jeton (`currentPsychologistProfile`).
2. **Suivre ce patient** : `ensureFollowsPatient` (ligne 118) refuse avec « Ce patient ne fait pas partie
   de vos patients suivis ».

Et une règle qui fait la valeur de la fonctionnalité : **chaque psy ne voit que ses propres notes**. La
lecture filtre par patient ET par auteur
(`findByPatientProfileIdAndPsychologistProfileIdOrderByCreatedAtDesc`), et la modification ou la
suppression passent par `findOwnNote` (identifiant de la note ET identifiant du psy).

Conséquence : si un patient change de psychologue, le nouveau ne lit pas les notes de l'ancien. Le patient
ne les voit pas non plus, ni l'administrateur. C'est le fonctionnement du secret des notes personnelles du
praticien.

## Étape 3 — Les antécédents médicaux

`GET` et `PUT /patients/{id}/medical-history` → `MedicalHistoryServiceImpl`.

Quatre champs structurés : allergies, maladies chroniques, traitements en cours, antécédents
psychiatriques.

Qui peut lire et modifier (`checkAccess`, ligne 86) :

- **le patient lui-même** ;
- **un psychologue qui le suit** (lien de l'étape 1).

Chaque modification enregistre **qui** l'a faite (`lastUpdatedByRole` : PATIENT ou PSYCHOLOGIST) et
quand. Le patient voit donc si son psy a complété sa fiche.

Ne pas confondre avec le champ `medicalHistory` du profil patient : celui-là est en fait la case « Ce que
vous recherchez » de l'inscription, utilisée par la recommandation (fil 02).

---

## Ce que ce fil démontre

| Notion | Où |
|---|---|
| Contrôle d'accès en deux niveaux (rôle, puis relation) | `ensureFollowsPatient` |
| Données visibles de leur seul auteur | filtre par `psychologistProfileId` |
| Idempotence | ajout et retrait du lien |
| Réduire les dépendances entre services | lien stocké localement plutôt qu'un appel à appointment-service |
| Traçabilité des modifications | `lastUpdatedByRole`, `updatedAt` |

## Limites à connaître

1. ~~**Le lien de suivi n'exige aucun rendez-vous.**~~ **Corrigé le 25/09/2026.** Avant, n'importe quel
   psychologue pouvait marquer n'importe quel patient comme suivi et lire ses **antécédents médicaux**.
   Désormais, le lien n'est créé qu'après un rendez-vous accepté (`CONFIRMED` ou `COMPLETED`). Le
   contrôle a lieu à la création du lien seulement : la lecture reste locale à user-service, sans appel
   à appointment-service. Restes connus : les liens créés avant la correction sont conservés, et le
   patient ne donne pas d'accord explicite. Test : `PsyPatientLinkServiceImplTest`.
2. **Tout psychologue peut lire le profil de tout patient** (`GET /patients/{id}`), avec le mode anonyme
   appliqué. Déjà dans `Audit_Securite.md`, section 3.7.
3. **Les notes ne sont pas chiffrées en base.** Elles sont protégées par les contrôles d'accès de
   l'application, pas par le chiffrement. Un accès direct à la base PostgreSQL les lirait en clair.
4. Pas de journal des consultations : on sait qui a modifié les antécédents en dernier, pas qui les a lus.

## Questions probables du jury

**« Le patient peut-il lire les notes de son psy ? »**
Non, par choix : ce sont des notes de travail du praticien, comme dans un cabinet. Ce que le patient
partage avec son psy passe par les antécédents, la messagerie et les questionnaires.

**« Un admin peut-il lire les notes ? »**
Non. L'admin modère la plateforme ; il n'a aucun accès au contenu clinique.

**« Pourquoi le lien est-il manuel ? »**
Parce qu'un rendez-vous ne dit pas si la prise en charge continue. Le psy décide qui il suit. La limite 1
montre qu'il faudrait quand même encadrer ce choix.
