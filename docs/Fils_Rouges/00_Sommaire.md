# Les fils rouges de PsyConnect — sommaire

Un fil rouge suit **une action réelle** à travers le vrai code : quel écran, quel service, quelle
vérification, quelle ligne. Réviser par fils rouges, c'est réviser l'architecture sans l'apprendre par
cœur : elle se retrouve dans chaque trajet.

Tous les fichiers de ce dossier ont été vérifiés contre le code le 24/09/2026.

---

## Les fichiers, dans l'ordre du parcours d'un patient

| # | Fichier | Ce qu'il trace | Services traversés |
|---|---|---|---|
| 01 | `01_Inscription_Connexion.md` | inscription en 4 appels, jeton JWT, mot de passe oublié | auth, user |
| 02 | `02_Recommandation.md` | classement des psys par TF-IDF, cosinus, note et ville | ml-service, user |
| 03 | `03_Reservation.md` | la demande de rendez-vous et ses 5 vérifications | passerelle, Eureka, appointment |
| 04 | `04_Paiement_Remboursement.md` | recharge, paiement, compensation, commission, règle des 48 h | payment, user, appointment |
| 05 | `05_Visio.md` | un seul salon Jitsi par rendez-vous, verrou, clôture automatique | session, appointment |
| 06 | `06_Questionnaires.md` | PHQ-9 et GAD-7, score, sévérité, filet de la question 9 | appointment |
| 07 | `07_Suivi_Clinique.md` | lien de suivi, notes privées, antécédents | user |
| 08 | `08_Messagerie_Notifications.md` | messages par polling, notifications par profil et rôle | appointment, notification |
| 09 | `09_Administration.md` | validation des psys, signalements, annonces, commission | auth, user, payment |
| 10 | `10_Xalaat.md` | le compagnon IA, son garde-fou et ses limites | ai-companion |
| 11 | `11_Fil_Rouge_Ethique.md` | la ligne de conduite face à la détresse | ai-companion, appointment |

**Ordre de révision conseillé** si le temps manque : 03 (il montre toute l'architecture), 10 (ta
contribution originale), 04 (le passage le plus technique), puis 01 et 02.

## La carte du système

| Composant | Port | Langage | Base de données | Rôle en une ligne |
|---|---|---|---|---|
| api-gateway | 8080 | Java | — | point d'entrée unique, route sans lire le jeton |
| eureka-server | 8761 | Java | — | annuaire : qui est où |
| auth-service | 8081 | Java | `psyconnect_auth` | comptes, mots de passe, jetons |
| user-service | 8082 | Java | `psyconnect_user` | profils, solde, suivi clinique, admin des psys |
| appointment-service | 8083 | Java | `psyconnect_appointment` | rendez-vous, messagerie, questionnaires, rappels |
| payment-service | 8085 | Java | `psyconnect_payment` | paiements, commission, revenus |
| notification-service | 8086 | Java | `psyconnect_notification` | notifications de tous les services |
| ai-companion-service | 8087 | Java | aucune | Xalaat, garde-fou, modèle local |
| session-service | 8089 | Java | `psyconnect_session` | sessions vidéo Jitsi |
| ml-service | 8000 | Python | aucune | recommandation |
| PostgreSQL | 5432 | — | les 6 bases | un seul conteneur, une base par service |
| Zipkin | 9411 | — | — | traçage des requêtes entre services |
| Mailpit | 8025 | — | — | faux serveur de messagerie de développement |

Démarrage : `docker compose up -d` à la racine. Ollama (le modèle de Xalaat) tourne à part, sur la machine.

## Trois idées qui reviennent dans tous les fils

1. **Le client déclare, le serveur prouve.** L'application envoie des identifiants, mais chaque service
   retrouve l'identité réelle à partir du jeton et compare (`OwnershipResolver`). C'est le cœur de la
   sécurité du projet.
2. **Chaque service se protège seul.** La passerelle ne vérifie pas le jeton ; chaque service a son filtre
   JWT. Un service atteint directement n'est jamais sans protection.
3. **Une panne secondaire ne bloque pas l'essentiel.** Une notification perdue n'annule ni un rendez-vous
   ni un paiement (Resilience4j, méthodes de repli).

## Failles trouvées en écrivant ces fils

À connaître avant le jury, et à présenter comme le résultat de ta propre relecture. Les quatre premières
ne figurent pas dans `Audit_Securite.md`.

| Gravité | Faille | Fil | Correctif en une phrase |
|---|---|---|---|
| ~~Haute~~ **corrigée le 24/09** | le montant du paiement venait de l'application et n'était pas comparé au tarif | 04 | payment-service relit maintenant `consultationPrice` dans user-service |
| ~~Haute~~ **corrigée le 24/09** | `POST /payments/appointment/{id}/refund` appelable directement, sans règle des 48 h | 04 | payment-service vérifie maintenant patient, statut `CANCELLED` et 48 h |
| ~~Moyenne~~ **corrigée le 25/09** | n'importe quel psy pouvait se déclarer « suivant » un patient et lire ses antécédents | 07 | le lien exige maintenant un rendez-vous accepté |
| Moyenne | `POST /users` accepte l'`authUserId` envoyé par l'application | 01 | le prendre dans le jeton, comme `POST /patients` |
| Moyenne | `POST /notifications` ouvert sans authentification (audit 3.6, toujours ouvert) | 08 | exiger un jeton ou une clé interne |
| Basse | la connexion révèle si un email est inscrit | 01 | un message unique « Identifiants incorrects » |
| Basse | la commission est recalculée sur le passé si l'admin change le taux | 04 | enregistrer le taux dans chaque paiement |
| Basse | la notification au psy ne signale pas une réponse à risque à la question 9 | 06 | tester la question 9 côté serveur |

Les deux failles hautes ont été corrigées le 24/09/2026 (détail dans le fil 04), et celle du lien de
suivi le 25/09/2026 (fil 07). Les autres sont laissées
en l'état, assumées comme limites : le projet est en phase de maîtrise, pas d'ajout.

## Autres documents utiles

- `docs/Comprendre_PsyConnect.md` : les explications de fond, le glossaire, le vocabulaire à ne pas
  confondre.
- `docs/Audit_Securite.md` : l'audit de sécurité complet et les corrections déjà faites.
- `docs/redact/Questions_Reponses_Jury.md` : toutes les questions possibles du jury et leurs réponses.
