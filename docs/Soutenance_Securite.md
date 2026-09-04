# Soutenance — préparation sécurité

*Fiche de préparation. À relire la veille.*

---

## 1. La posture

**Ne jamais dire « mon application est sécurisée ».** C'est la seule réponse qui te
fera perdre des points à coup sûr, parce qu'elle est indéfendable et qu'elle invite le
jury à trouver le contre-exemple.

La formule qui marche : *« Voici les trois mécanismes que j'ai implémentés, et voici
les trois limites que j'assume. »* Un jury de master n'attend pas une application
inattaquable — il attend quelqu'un capable de dire où sont ses propres faiblesses.

Corollaire : **cite tes limites avant qu'on ne les trouve.** Une limite que tu
annonces est une preuve de maîtrise. La même limite découverte par le jury devient un
doute sur tout le reste de ton travail.

---

## 2. Le slide à ajouter

Un seul, en deux colonnes. À placer après l'architecture, avant la démonstration.

**Titre : « Sécurité — implémenté / assumé »**

| Implémenté | Assumé comme limite |
|---|---|
| BCrypt pour les mots de passe | Transport HTTP (déploiement local) |
| Validation du JWT dans **chaque** microservice | Secret JWT unique, non externalisé |
| Contrôle de propriété systématique (`OwnershipResolver`) | Code de réinitialisation renvoyé en réponse (pas de SMTP intégré) |
| Pseudonymisation du patient côté psychologue | Pas de limitation du nombre de tentatives |
| `denyAll()` par défaut sur user-service | |
| Protection contre la traversée de chemin à l'upload | |

Une phrase sous le tableau :

> *« Ces limites sont documentées dans un audit joint en annexe ; leur levée constitue
> le passage en production. »*

---

## 3. La réponse d'ouverture — 90 secondes

À apprendre presque par cœur. C'est ce que tu dis dès qu'on aborde le sujet.

> La sécurité repose sur trois piliers.
>
> **D'abord l'authentification.** Les mots de passe sont hachés en BCrypt, jamais
> stockés en clair. Le jeton JWT est délivré par l'auth-service et **validé
> indépendamment par chaque microservice**, pas seulement au point d'entrée. C'est un
> choix d'architecture : un service reste protégé même si on l'appelle directement,
> sans passer par la gateway.
>
> **Ensuite l'autorisation.** C'est là que j'ai mis le plus d'efforts, parce que la
> faille la plus courante sur ce type d'application, c'est l'IDOR — accéder aux données
> d'un autre utilisateur en changeant un identifiant dans l'URL. Mon code ne fait
> **jamais** confiance à l'identifiant de l'URL : un `OwnershipResolver` reconstruit
> l'identité métier à partir du token, et c'est celle-là qui sert de référence. Je peux
> vous le démontrer en trente secondes si vous le souhaitez.
>
> **Enfin la confidentialité.** Le mode anonyme remplace l'identité affichée au
> psychologue par un pseudonyme. Au sens du RGPD et de la loi sénégalaise 2008-12, il
> s'agit d'une **pseudonymisation** et non d'une anonymisation — la donnée reste une
> donnée à caractère personnel, ce qui est nécessaire au suivi thérapeutique et à la
> traçabilité.

Cette dernière précision vaut cher : elle montre que tu connais la différence
juridique, et la plupart des candidats ne la font pas.

---

## 4. La démonstration qui vaut dix slides

**Trente secondes, avec Postman. Prépare-la et propose-la toi-même.**

1. Connecte-toi avec le patient A → récupère son token.
2. `GET /appointments/patient/{id_du_patient_B}` avec le token de A.
3. Montre le **403 Forbidden** et le message « Ce rendez-vous ne vous appartient pas ».

Puis, dans la foulée :

4. `GET /appointments/{id}` sur un rendez-vous de B, toujours avec le token de A → 403.

C'est irréfutable, c'est rapide, et ça déplace la discussion : le jury ne te demande
plus si tu as pensé à la sécurité, il constate que oui.

**Prépare la requête à l'avance dans ta collection Postman**, avec les deux tokens déjà
en variables. Ne cherche pas des identifiants en direct devant le jury.

---

## 5. Les questions probables et leurs réponses

### « Est-ce que votre application est sécurisée ? »

Piège. Ne réponds jamais oui.

> Elle implémente les protections essentielles au niveau applicatif — hachage,
> autorisation, contrôle de propriété. Elle n'est pas déployable en production en
> l'état : il manque le chiffrement du transport et l'externalisation des secrets, qui
> relèvent de l'infrastructure. J'ai documenté précisément cette frontière.

### « Pourquoi pas de HTTPS ? »

> Le déploiement est local, sur une seule machine, pour la démonstration. En
> production, la terminaison TLS se ferait au niveau d'un reverse proxy devant la
> gateway, avec un certificat Let's Encrypt, et je retirerais
> `usesCleartextTraffic="true"` du manifeste Android. C'est une ligne de configuration,
> pas une reprise du code — mon client Flutter passe déjà par une constante unique,
> `ApiConstants.baseUrl`, injectable au build.

Cette dernière phrase est importante : elle montre que ton code est **prêt** pour le
changement.

### « Que se passe-t-il si quelqu'un vole le jeton d'un utilisateur ? »

Réponse honnête, ne surjoue pas :

> Il peut agir en son nom pendant la durée de validité du jeton, soit 24 heures. Je
> n'ai pas implémenté de mécanisme de révocation ni de refresh token — c'est une
> limite que j'assume. Une liste noire de jetons révoqués côté auth-service, ou des
> jetons de courte durée avec un refresh, seraient les deux réponses possibles.

### « Comment protégez-vous les données de santé ? »

> Par cloisonnement plutôt que par chiffrement. Les antécédents médicaux exigent une
> relation de soin établie entre le psychologue et le patient — pas seulement le rôle
> de psychologue. Les notes cliniques sont soumises à un contrôle de propriété. Et le
> service d'accompagnement par IA ne stocke ni ne journalise le contenu des
> conversations, c'est documenté dans sa configuration.

Si on insiste sur le chiffrement au repos : dis que la base n'est pas chiffrée, que ce
serait un prérequis de production (chiffrement au niveau du volume ou de la colonne),
et n'invente pas.

### « Un psychologue peut-il voir les données d'un patient qui n'est pas le sien ? »

**C'est LA question sur laquelle tu peux être prise en défaut.** Réponse honnête :

> Pour les données sensibles, non : les antécédents médicaux et les notes cliniques
> vérifient l'existence d'une relation de soin. Pour la fiche patient de base, oui — le
> contrôle exige le rôle de psychologue mais pas la relation. Je l'ai identifié dans
> mon audit ; le correctif consiste à appliquer à `getPatientProfile` le même contrôle
> que celui qui existe déjà dans `MedicalHistoryServiceImpl`.

Répondre ça calmement, avec le nom de la classe et le correctif, vaut mieux que
n'importe quelle esquive.

### « Comment avez-vous testé la sécurité ? »

Ne prétends pas avoir fait un test d'intrusion.

> J'ai fait une revue de code systématique, service par service, dont le résultat est
> l'audit en annexe. Je n'ai pas conduit de test d'intrusion : ça supposerait un
> environnement dédié et des outils comme OWASP ZAP, ce qui sortait du périmètre. En
> revanche j'ai vérifié manuellement les contrôles d'accès avec Postman, en tentant
> d'accéder aux données d'un utilisateur avec le jeton d'un autre.

### « Qu'est-ce que vous feriez différemment ? »

Question cadeau. Prépare trois éléments, dans cet ordre :

1. Externaliser les secrets dès le début, dans un `.env` non versionné — c'est gratuit
   au démarrage du projet et coûteux à rattraper.
2. Intégrer un envoi d'e-mail dès la première version : c'est l'absence de SMTP qui a
   entraîné le renvoi du code de réinitialisation dans la réponse HTTP.
3. Écrire les tests de sécurité en même temps que les contrôles, pas après.

---

## 6. Les trois choses à ne pas faire

**Ne pas improviser.** Si on te pose une question dont tu n'as pas la réponse, dis-le :
*« Je ne l'ai pas vérifié, il faudrait que je regarde le code. »* Une hésitation
honnête coûte bien moins qu'une affirmation fausse — sur la sécurité, un jury
technique repère immédiatement l'approximation, et il doutera ensuite de tout le reste.

**Ne pas minimiser une faille qu'on te montre.** Si un membre du jury trouve quelque
chose que tu n'avais pas vu, la seule bonne réponse est : *« Vous avez raison, je ne
l'avais pas identifiée. »* Puis, si tu le peux, propose le correctif. Ne discute pas
la gravité.

**Ne pas mettre de code de sécurité sur un slide.** Un extrait de `SecurityConfig`
projeté au mur invite chacun à chercher la ligne qui manque, pendant que tu parles.
Décris le mécanisme, garde le code pour la démonstration Postman.

---

## 7. À faire avant le jour J

- [ ] Appliquer les cinq correctifs d'une heure (voir `Audit_Securite.md`, §6)
- [ ] Vérifier `git ls-files backend/video-service` et retirer le dossier s'il est encore suivi
- [ ] Préparer la requête Postman de démonstration IDOR, avec deux tokens en variables
- [ ] Ajouter le slide « implémenté / assumé »
- [ ] Joindre `Audit_Securite.md` en annexe du mémoire
- [ ] Relire la réponse d'ouverture (§3) à voix haute, deux fois

---

## 8. Le cadrage à garder en tête

Ce qu'un jury de M2 évalue, ce n'est pas le nombre de failles. C'est :

**Est-ce que l'étudiante connaît les menaces de son domaine ?** Ton travail sur l'IDOR
répond oui, sans ambiguïté. C'est la faille la plus courante et la plus grave sur une
application manipulant des dossiers de santé, et tu l'as traitée avec un mécanisme
systématique et non au cas par cas.

**Est-ce qu'elle sait où elle en est ?** L'audit répond oui.

**Est-ce qu'elle sait ce qu'il faudrait faire ensuite ?** Le plan de correction répond
oui.

Trois oui. C'est ça qu'on note.
