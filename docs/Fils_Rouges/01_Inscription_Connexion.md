# 01 — Un patient s'inscrit, se connecte, oublie son mot de passe

Trois moments, un seul service au centre : `auth-service`. C'est lui qui fabrique le jeton que tous les
autres services vérifient ensuite. Comprendre ce fil, c'est comprendre d'où vient l'identité dans tout le
reste du projet.

Vérifié dans le code le 24/09/2026.

---

## En une phrase

`auth-service` crée le compte et signe un jeton JWT ; `user-service` crée ensuite les profils ; le téléphone
garde le jeton dans le stockage sécurisé et l'envoie à chaque appel.

## Partie A — L'inscription : quatre appels, pas un

Écran : `frontend/psyconnect/lib/features/auth/screens/register_screen.dart` (ligne 144 pour le patient,
ligne 121 pour le psychologue).

Le patient remplit un seul formulaire, mais l'application enchaîne **quatre appels** :

| # | Appel | Service | Ce qui est créé |
|---|---|---|---|
| 1 | `POST /auth/register/patient` | auth-service | le compte `User` (email, mot de passe haché, pseudo, rôle) |
| 2 | `POST /auth/login` | auth-service | le jeton JWT |
| 3 | `POST /users` | user-service | le `UserProfile` (prénom, nom, téléphone, ville, pays) |
| 4 | `POST /patients` | user-service | le `PatientProfile` (langue, « ce que vous recherchez ») |

Les appels 2 à 4 sont dans `auth_provider.dart`, méthode `completePatientOnboarding` (ligne 175).

### Étape 1 — Le compte (`AuthService.register`, ligne 58)

Quatre vérifications avant d'écrire :

- l'email n'est pas déjà pris (ligne 60) ;
- le pseudo n'est pas déjà pris (ligne 64) ;
- un rôle est fourni (ligne 68) ;
- **le rôle n'est pas ADMIN** (ligne 72) : on ne peut pas s'inscrire administrateur. Le seul compte admin
  est créé au démarrage par `AdminBootstrap`.

Le rôle PATIENT n'est pas choisi par l'application : c'est le contrôleur qui l'impose
(`AuthController.java`, ligne 40, `request.setRole(Role.PATIENT)`). Même chose pour `/register/psy`.

Le mot de passe est **haché avec BCrypt** avant d'être stocké (ligne 79, `passwordEncoder.encode`). La base
ne contient jamais le mot de passe en clair.

### Étape 2 — Connexion immédiate

L'application se connecte tout de suite pour obtenir un jeton, et **le persiste avant les appels suivants**
(commentaire ligne 194 de `auth_provider.dart` : sans ça, les appels 3 et 4 partaient sans jeton et
recevaient un 403).

### Étapes 3 et 4 — Les profils dans user-service

Pourquoi deux profils ? Parce que `UserProfile` porte ce qui est commun à tous (nom, téléphone, ville), et
`PatientProfile` ou `PsychologistProfile` ce qui est propre au rôle. Un psychologue a un tarif et une
spécialité ; un patient a un solde et un mode anonyme.

Point de sécurité à savoir montrer : `PatientProfileServiceImpl.createPatientProfile` (ligne 60) **ignore
le `userProfileId` envoyé par l'application**. Il retrouve le `UserProfile` à partir de l'identité du
jeton (`callerAuthUserId`, ligne 67). Impossible de rattacher son profil patient au compte de quelqu'un
d'autre.

### Trois identifiants pour une même personne

C'est la confusion la plus fréquente, et le jury peut la tester :

| Identifiant | Où il vit | À quoi il sert |
|---|---|---|
| `authUserId` | table `users` d'auth-service | l'identité du compte, écrite dans le jeton (claim `userId`) |
| `userProfileId` | table `user_profiles` de user-service | le profil commun |
| `profileId` | table `patient_profiles` (ou `psychologist_profiles`) | l'identité métier : c'est lui qu'on met dans un rendez-vous |

Le pont entre le premier et le dernier : `GET /patients/by-auth-user/{authUserId}`.

## Partie B — La connexion

### Étape 1 — Vérifier (`AuthService.login`, ligne 106)

1. Le compte existe (ligne 108).
2. Il n'est pas désactivé par l'admin (ligne 111) : sinon `BannedAccountException`, que l'application
   affiche avec une carte dédiée et les coordonnées de l'administration.
3. Le mot de passe correspond au hachage (ligne 115, `passwordEncoder.matches`).

### Étape 2 — Signer le jeton (`JwtService.generateToken`, ligne 26)

Le jeton contient :

- le sujet : l'email ;
- le claim `role` : PATIENT, PSYCHOLOGIST ou ADMIN ;
- le claim `userId` : l'`authUserId` ;
- une date d'expiration : **24 heures** (`jwt.expiration-ms=86400000`).

Il est signé en **HS256** avec un secret partagé par tous les services. C'est ce qui permet à chaque service
de vérifier le jeton seul, sans appeler auth-service : on dit que l'authentification est **sans état**
(*stateless*).

### Étape 3 — Retrouver ses profils

La réponse de connexion ne contient que l'`authUserId`. L'application appelle donc user-service pour
retrouver `userProfileId` et `profileId` (`auth_provider.dart`, méthode `login`, ligne 127), puis stocke
le tout dans `flutter_secure_storage` (trousseau iOS, Keystore Android).

## Partie C — Le mot de passe oublié

### Étape 1 — Demander un code (`AuthService.forgotPassword`, ligne 150)

- **Limitation de fréquence** : 3 demandes maximum par email et par fenêtre de 15 minutes
  (`ResetRequestThrottle`, lignes 16-17).
- **Réponse identique que le compte existe ou non** (ligne 152) : « Si un compte existe avec cet email, un
  code vient d'être envoyé. » Un attaquant ne peut pas savoir quels emails sont inscrits.
- Les anciens codes non utilisés sont invalidés (lignes 168-171).
- Le code à 6 chiffres est tiré avec `SecureRandom` (ligne 173) et **stocké haché** (ligne 177), comme un
  mot de passe. Il expire au bout de 15 minutes.
- L'email part en **asynchrone** (`PasswordResetMailer.sendResetCode`, annoté `@Async`) : la réponse HTTP
  n'attend pas le serveur de messagerie.

En développement, l'email arrive dans **Mailpit**, un faux serveur de messagerie qui intercepte tout
(interface sur le port 8025). Aucun fournisseur réel n'est branché.

### Étape 2 — Utiliser le code (`resetPasswordWithCode`, ligne 194)

- Code expiré → refus (ligne 205).
- **5 tentatives maximum** (ligne 209) : au-delà, le code est grillé. Sans cette limite, 1 million de
  combinaisons se testent en quelques minutes.
- Comparaison avec le hachage (ligne 215).
- Nouveau mot de passe haché, code marqué utilisé.
- Tous les refus renvoient le même message, « Code invalide ou expiré » : on ne dit pas pourquoi.

C'est le flux le plus sécurisé du projet, parce qu'il a été corrigé après ton propre audit
(`Audit_Securite.md`, section 7).

---

## Ce que ce fil démontre

| Notion | Où |
|---|---|
| Hachage des secrets (BCrypt) | mots de passe et codes de réinitialisation |
| Jeton signé, sans état | `JwtService.generateToken` |
| Séparation identité / profil métier | `authUserId` vs `profileId` |
| Le serveur ne croit pas le client | `createPatientProfile` ignore `userProfileId` |
| Anti-énumération de comptes | réponse générique de `forgotPassword` |
| Anti-force brute | 5 tentatives, 3 demandes par 15 min |
| Asynchronisme | `@Async` sur l'envoi d'email |

## Limites et failles à connaître

1. **La connexion, elle, révèle si un email existe.** `login` répond « Aucun compte ne correspond à cet
   email » ou « Mot de passe incorrect » (lignes 109 et 121). C'est incohérent avec la réponse générique du
   mot de passe oublié. Correctif simple : un message unique, « Identifiants incorrects ».
2. **Pas de limite de tentatives sur la connexion.** Le mot de passe oublié en a une, pas le login.
3. **`POST /users` fait confiance à l'`authUserId` envoyé par l'application**
   (`UserProfileServiceImpl.createProfile`, ligne 33). Contrairement à `POST /patients`, il ne le compare
   pas au jeton. Un utilisateur connecté pourrait créer un `UserProfile` au nom d'un autre compte.
4. **Le jeton n'est pas révocable.** Une fois émis, il reste valable 24 heures, même si l'admin désactive
   le compte entre-temps (le filtre des services ne relit pas la base).
5. **Un seul secret JWT pour tous les services, écrit en clair dans `docker-compose.yml`.** Acceptable en
   développement, pas en production.
6. L'inscription est en **quatre appels non atomiques** : si l'appel 4 échoue, le compte existe sans profil
   patient. L'application le gère en affichant l'erreur et en laissant relancer.

## Questions probables du jury

**« Pourquoi deux services pour l'identité ? »**
auth-service ne sait qu'une chose : qui est qui, et avec quel rôle. Tout le reste (profils, solde, notes)
est dans user-service. Si demain on remplace l'authentification par un fournisseur externe, user-service ne
bouge pas.

**« Comment les autres services savent-ils qui appelle, sans interroger auth-service ? »**
Ils vérifient la signature du jeton avec le secret partagé, puis lisent les claims `role` et `userId`.
Aucun appel réseau.

**« Pourquoi BCrypt et pas SHA-256 ? »**
BCrypt est volontairement lent et ajoute un sel aléatoire : deux mots de passe identiques donnent deux
hachages différents, et tester des milliards de combinaisons devient très coûteux. SHA-256 est rapide, ce
qui est un défaut pour un mot de passe.

**« Que se passe-t-il si on vole un jeton ? »**
Il est utilisable jusqu'à son expiration, 24 heures au plus. C'est la limite des jetons sans état ; la
parade classique est une durée courte avec un jeton de rafraîchissement, ou une liste de révocation.
