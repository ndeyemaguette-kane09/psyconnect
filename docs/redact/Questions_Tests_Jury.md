# Tests et qualité : questions possibles du jury

Fiche de révision faite à partir du vrai contenu du dépôt au 26/09/2026.
Légende : 🟢 question simple · 🟠 question technique · 🔴 question piège

---

## 0. Les chiffres à connaître par cœur

- **Environ 130 tests automatisés** au total : ~120 en Java (Spring) et 12 en Python (recommandation).
- **6 services testés en profondeur** : rendez-vous, paiement, utilisateurs, authentification, Xalaat, recommandation.
- Pour la passerelle, Eureka et les notifications, il n'y a que le test par défaut, qui vérifie que le service démarre.
- **Application mobile : 0 test réel.** C'est une limite assumée.
- Le service le plus testé est le **paiement** (17 tests sur la logique + 5 sur l'API), parce qu'il touche à l'argent.
- Le filtre de crise de Xalaat est vérifié sur **23 phrases** : 14 phrases de détresse, 5 phrases ordinaires et 4 messages vides.
- Outils utilisés : **JUnit 5, Mockito, MockMvc, une base H2 en mémoire, pytest**.

> ⚠️ **Avant la soutenance**, lance les tests dans chaque service (`./gradlew test`) et note combien passent. Si on te demande « est-ce qu'ils passent tous ? », il faut pouvoir répondre oui avec certitude.

---

## 1. Les bases (le jury vérifie que tu connais le vocabulaire)

**🟢 Qu'est-ce qu'un test automatisé ?**
Un petit programme qui exécute une partie du code avec des données connues et vérifie que le résultat est celui attendu. On le relance à chaque modification pour s'assurer qu'on n'a rien cassé.

**🟢 Quelle différence entre un test unitaire et un test d'intégration ?**
Le test unitaire vérifie une seule classe, isolée de tout le reste : pas de base de données, pas de réseau. Le test d'intégration vérifie que plusieurs éléments fonctionnent ensemble, par exemple mon code et une vraie base de données. J'ai les deux : la majorité sont unitaires, et j'ai des tests d'intégration sur la base des rendez-vous et sur la résilience.

**🟢 Et un test de bout en bout ?**
Il simule un vrai utilisateur, de l'application jusqu'à la base. Je n'en ai pas d'automatisé : mes parcours complets, je les ai testés à la main.

**🟢 Qu'est-ce qu'un test de non-régression ?**
C'est un test qui vérifie qu'une correction ou un ajout n'a pas cassé ce qui marchait avant. Tous mes tests automatisés servent à ça dès qu'on les relance après une modification.

**🟢 C'est quoi la « pyramide des tests » ?**
C'est l'idée qu'il faut beaucoup de tests unitaires (rapides, peu coûteux), moins de tests d'intégration et très peu de tests de bout en bout (lents, fragiles). Ma répartition suit cette forme côté serveur : surtout de l'unitaire, un peu d'intégration.

**🟢 Qu'est-ce qu'une assertion ?**
C'est la vérification elle-même. Par exemple : « le statut du rendez-vous doit être EN ATTENTE », ou « cette opération doit lever une erreur ».

**🟢 Quels outils avez-vous utilisés ?**
- **JUnit 5**, le cadre de test standard en Java.
- **Mockito**, pour remplacer les dépendances par des doublures.
- **MockMvc**, pour tester les points d'entrée de l'API sans lancer de vrai serveur.
- **H2**, une base de données en mémoire pour les tests d'intégration.
- **pytest**, pour le service de recommandation en Python.

---

## 2. Ce que tes tests vérifient concrètement (question la plus probable)

**🟢 Quelles règles métier sont couvertes par vos tests ? Donnez des exemples.**
Donne trois exemples, pas plus :
1. **Paiement** : on ne peut pas payer un rendez-vous qui n'est pas confirmé, qui a été annulé ou qui est déjà payé, et on ne peut pas payer le rendez-vous d'un autre patient. Dans tous ces cas, le test vérifie aussi que le solde n'a **pas** été débité.
2. **Réservation** : impossible de réserver un créneau où le psychologue est déjà pris, ni un créneau où le patient a déjà un rendez-vous. Impossible aussi de réserver dans le passé ou avec une fin avant le début.
3. **Xalaat** : les messages de détresse sont interceptés avant d'arriver au modèle, et les messages ordinaires passent.

**🟢 Que testez-vous dans le paiement ?**
- Le cas normal : le solde est débité et le patient est notifié.
- Les refus : rendez-vous non confirmé, annulé, refusé, déjà payé, introuvable ou appartenant à un autre patient.
- Le remboursement : il crédite le bon montant, il est refusé si le rendez-vous n'est pas annulé et il est refusé si l'annulation a lieu moins de 48 heures avant la séance.

**🟠 Pourquoi vérifier que le solde n'est « pas » débité en cas d'erreur ? L'erreur ne suffit pas ?**
Non. L'erreur pourrait très bien arriver *après* le débit, et le patient aurait perdu son argent. Le test vérifie donc deux choses : l'opération est refusée, **et** aucun débit ni aucune écriture en base n'a eu lieu. C'est la vraie garantie pour l'utilisateur.

**🟠 Un patient peut-il modifier le montant qu'il paie ?**
Non, et c'est testé. L'application envoie un montant, mais le serveur l'ignore : il va chercher lui-même le tarif du psychologue et débite ce tarif. Le test envoie volontairement un montant de 1 franc, puis vérifie que c'est bien le prix de la consultation qui a été débité. Même principe que partout dans le projet : **le client déclare, le serveur vérifie**.

**🟠 Et si le tarif du psychologue est introuvable ?**
Le paiement est refusé **avant** tout débit. C'est testé.

**🟢 Que testez-vous dans la réservation ?**
Les conflits de créneau (côté psychologue et côté patient), les dates incohérentes et le cas normal, où le rendez-vous est créé avec le statut EN ATTENTE.

**🟠 Un rendez-vous annulé bloque-t-il encore le créneau ?**
Non : un rendez-vous annulé ou refusé libère le créneau. Seuls les rendez-vous en attente ou confirmés bloquent. C'est vérifié par un test d'intégration sur une vraie base.

**🔴 Deux rendez-vous qui se touchent (10 h–11 h puis 11 h–12 h), est-ce un conflit ?**
Non, et c'est testé. En revanche, un chevauchement partiel (10 h–11 h puis 10 h 30–11 h 30) est bien détecté comme un conflit. Il y a aussi un test pour le déplacement d'un rendez-vous sur son propre créneau : il ne doit pas entrer en conflit avec lui-même.

**🟢 Que testez-vous dans les questionnaires ?**
Le calcul des scores PHQ-9 et GAD-7 et le niveau associé (minimal, léger, modéré, sévère), en prenant des valeurs aux limites : score 0, score maximal (27 et 21), valeurs intermédiaires. Je vérifie aussi les refus : un nombre de réponses incorrect, une réponse hors de l'échelle 0 à 3, ou un questionnaire auquel le patient a déjà répondu.

**🟠 Pourquoi tester les scores alors que c'est une simple addition ?**
Parce qu'une erreur de seuil ferait classer une dépression sévère en « modérée », et le psychologue prendrait une mauvaise décision. C'est la partie la plus sensible cliniquement : une erreur y est silencieuse, personne ne la verrait à l'écran.

**🟢 Que testez-vous dans le suivi psychologue–patient ?**
Qu'un psychologue ne peut pas ajouter un patient à son suivi sans avoir eu au moins un rendez-vous accepté avec lui. Sans cette règle, n'importe quel psychologue pourrait s'attribuer le dossier de n'importe quel patient.

**🟢 Et dans le journal du patient ?**
Un patient peut créer, lire, modifier et supprimer ses propres entrées, mais jamais celles d'un autre. Chaque tentative sur l'entrée d'un autre patient est refusée, et le test vérifie qu'aucune modification n'a été enregistrée.

**🟢 Et dans la messagerie ?**
On ne peut ouvrir une conversation qu'avec quelqu'un avec qui on a eu un rendez-vous. On ne peut ni lire ni envoyer de messages dans une conversation dont on n'est pas participant. Et « marquer comme lu » ne marque que les messages de l'autre personne.

**🟢 Et dans l'authentification ?**
- À l'inscription : un e-mail ou un pseudo déjà utilisé est refusé, et on ne peut pas s'inscrire en tant qu'administrateur.
- À la connexion : un mauvais mot de passe, un compte désactivé ou un compte inexistant sont refusés.

**🟠 Et côté administrateur ?**
Un administrateur ne peut ni désactiver, ni supprimer, ni réinitialiser le mot de passe d'un autre administrateur, et il ne peut pas se désactiver ou se supprimer lui-même. Sinon, on pourrait se retrouver avec une plateforme sans aucun administrateur.

**🔴 Un de vos tests s'appelle « le psychologue non approuvé reçoit quand même un jeton ». Ce n'est pas une faille ?**
Non, c'est voulu. Le psychologue en attente peut se connecter pour voir où en est sa demande : l'application lui affiche un bandeau « en attente de validation » et désactive ses fonctions. La vraie protection est côté serveur : au moment d'une réservation, le service des rendez-vous vérifie que le psychologue est bien validé. Le test documente ce choix pour qu'on ne le « corrige » pas par erreur.

**🟢 Que testez-vous dans la recommandation (Python) ?**
- Les accents et les majuscules sont normalisés (« Dépression » équivaut à « depression »).
- Le calcul de similarité donne 1 pour deux textes identiques et 0 pour un texte vide.
- Les psychologues indisponibles sont exclus.
- Un psychologue pertinent passe devant un psychologue mieux noté mais hors sujet.
- Sans description du patient, on classe par note.
- Le bonus de même ville départage deux profils identiques.
- Un patient sans ville ne pénalise personne.

---

## 3. Questions techniques sur la méthode

**🟠 Qu'est-ce qu'un « mock » et pourquoi en utiliser ?**
C'est une doublure : un faux objet qui remplace une dépendance réelle (la base, un autre service) et renvoie ce que je lui dis de renvoyer. Ça me permet de tester **une seule règle** sans lancer toute l'architecture, et de provoquer facilement des situations rares, par exemple « le service de paiement ne répond pas ».

**🟠 Comment testez-vous un service qui dépend d'un autre microservice ?**
En remplaçant l'appel réseau par un mock. Par exemple, pour le suivi patient, je simule la réponse du service des rendez-vous (« oui, il y a eu un rendez-vous accepté » ou « non ») et je vérifie la décision prise.

**🟠 Vos tests ont besoin de savoir qui est connecté. Comment faites-vous sans jeton ?**
Avant chaque test, je place directement dans le contexte de sécurité de Spring un utilisateur fictif avec son rôle (patient, psychologue). Après chaque test, je le nettoie pour que les tests ne s'influencent pas entre eux.

**🟠 Qu'est-ce que MockMvc ?**
Un outil qui envoie de fausses requêtes HTTP à mes contrôleurs sans démarrer de vrai serveur. Il me permet de vérifier les codes de réponse : 201 à la création, 400 si un champ obligatoire manque, 204 à la suppression.

**🟠 Quelle différence entre vos tests de service et vos tests de contrôleur ?**
Le test de contrôleur vérifie la « porte d'entrée » : format de la requête, validation des champs, code HTTP. Le test de service vérifie les règles métier : qui a le droit, dans quel état, avec quel montant.

**🟠 Qu'est-ce que H2 et pourquoi l'utiliser ?**
Une base de données qui vit en mémoire le temps du test puis disparaît. Elle démarre en une fraction de seconde, n'a pas besoin d'installation et repart de zéro à chaque fois. Je l'ai configurée en mode compatible PostgreSQL.

**🟠 Comment nommez-vous vos tests ?**
Chaque nom dit trois choses : ce qu'on appelle, dans quelle situation et ce qu'on attend. Par exemple : « paiement d'un rendez-vous déjà payé : erreur, et pas de double débit ». Un test qui échoue dit donc tout de suite ce qui est cassé.

**🟠 Qu'est-ce qu'un test paramétré ? Vous en avez ?**
C'est un seul test exécuté automatiquement avec une liste de valeurs. Je l'utilise pour Xalaat : une vingtaine de phrases passent dans le même test, ce qui permet d'ajouter une nouvelle formulation de détresse en une ligne.

**🟠 Pourquoi tester les cas d'erreur plus que le cas qui marche ?**
Parce que le cas qui marche, on le voit en utilisant l'application. Les cas d'erreur (payer deux fois, accéder aux données d'un autre), on ne les essaie presque jamais à la main, et ce sont eux qui causent des pertes d'argent ou des fuites de données.

**🟠 Qu'est-ce que les « valeurs aux limites » ?**
Tester juste aux frontières, là où les erreurs se cachent : score 0, score maximal, 8 réponses au lieu de 9, une réponse égale à 4 alors que le maximum est 3, deux créneaux qui se touchent exactement.

---

## 4. Résilience (ton argument fort)

**🟠 Qu'est-ce que vos tests de résilience vérifient ?**
Ce qui se passe quand un autre service tombe. Deux comportements différents, choisis selon l'enjeu :
- **Service de notifications en panne** : on réessaie trois fois, puis on abandonne en silence. Le rendez-vous est créé quand même, car une notification perdue n'est pas grave.
- **Service des utilisateurs en panne** : on réessaie, puis l'opération est **refusée** (erreur 503). Sans ce service, on ne sait pas qui est l'utilisateur, et laisser passer serait une faille.

Formule : « Je tombe en marche ou je tombe fermé selon l'enjeu. »

**🟠 Qu'est-ce qu'un disjoncteur (circuit breaker) et comment l'avez-vous testé ?**
Comme un disjoncteur électrique : après plusieurs échecs, il « s'ouvre » et on arrête d'appeler le service en panne pendant un moment, au lieu de le surcharger et de faire attendre l'utilisateur. Le test provoque quatre échecs, vérifie que le disjoncteur est ouvert, puis vérifie que l'appel suivant n'atteint même plus le service.

**🔴 Vos tests de résilience attendent-ils vraiment plusieurs secondes ?**
Non. Pour les tests, j'ai gardé les mêmes réglages qu'en production mais avec des délais raccourcis (10 millisecondes entre deux essais), pour que les tests restent rapides. Le comportement vérifié est le même, seul le temps change.

**🔴 Si l'utilisateur n'existe pas, est-ce que vous réessayez trois fois ?**
Non. Les erreurs « introuvable » et « accès interdit » sont exclues des nouvelles tentatives, et elles ne comptent pas pour ouvrir le disjoncteur. Réessayer ne changerait rien : ce n'est pas une panne, c'est une vraie réponse.

---

## 5. Xalaat

**🟢 Comment avez-vous testé le filtre de crise ?**
À la main d'abord, puis avec un test automatisé sur 23 phrases : des formulations de détresse qui doivent être interceptées, des phrases ordinaires qui doivent passer, et des messages vides.

**🟠 Ce test vous a-t-il servi à quelque chose ?**
Oui, il m'a fait trouver trois défauts réels :
1. L'apostrophe du clavier iPhone (’) est différente de l'apostrophe classique ('), ce qui empêchait la détection.
2. « J'ai envie de vivre » déclenchait l'alerte.
3. « Je veux en finir » n'était pas reconnu.

C'est l'exemple même d'un test qui a de la valeur.

**🔴 Pourquoi tester des phrases qui ne sont PAS dangereuses ?**
Parce qu'un filtre qui bloque tout est aussi un échec : l'utilisateur qui dit « je ne veux pas mourir » ou « je suis stressé par mes examens » ne doit pas recevoir un message d'urgence. Je teste les deux sens : ne rien laisser passer de grave, et ne pas crier au loup.

**🔴 23 phrases, c'est suffisant pour un sujet aussi grave ?**
Non, et je ne prétends pas le contraire. Le filtre repose sur des mots-clés : il ne comprend pas le sens, il ne couvre que le français et une personne peut formuler sa détresse autrement. C'est un **filet de sécurité**, pas un diagnostic : Xalaat ne remplace pas un professionnel. L'amélioration serait d'élargir la liste avec des psychologues et d'ajouter le wolof.

**🔴 Pourquoi ne pas tester la réponse du modèle de langage lui-même ?**
Parce que sa réponse change à chaque fois : on ne peut pas écrire « la réponse doit être exactement X ». C'est pour ça que j'ai placé la sécurité **avant** le modèle, dans un filtre dont le comportement est fixe et testable.

---

## 6. Les questions vicieuses (celles des profs qui cherchent la faille)

**🔴 Pourquoi l'application mobile n'a-t-elle aucun test ?**
« C'est une limite que j'assume. J'ai priorisé : les règles critiques (argent, droits d'accès, données de santé, détection de crise) sont toutes côté serveur, et c'est là que j'ai mis les tests. Même si quelqu'un contourne l'application, le serveur refuse. L'interface, je l'ai testée par l'usage. Les tests d'interface Flutter seraient la prochaine étape. »

**🔴 Quel est votre taux de couverture de code ?**
« Je ne l'ai pas mesuré avec un outil. Je n'ai pas cherché un pourcentage : j'ai ciblé les règles à risque. Une couverture de 80 % peut laisser passer le seul bug qui compte, alors que mes tests visent précisément les cas qui coûtent cher. Mesurer la couverture serait facile à ajouter. »
Ne donne **jamais** de chiffre inventé.

**🔴 Avez-vous fait du TDD (développement piloté par les tests) ?**
« Non. J'ai écrit les tests après le code, et une partie à la fin, lors de la phase de vérification. Si c'était à refaire, je les écrirais en même temps que le code. »
Sois honnête, ça passe mieux.

**🔴 Vos tests utilisent des mocks. Ils prouvent donc que votre code marche avec des faux, pas avec les vrais services ?**
« C'est juste, et c'est volontaire : le test unitaire vérifie **ma règle** en isolant le reste. Pour la communication réelle entre services, j'ai des tests d'intégration sur la résilience et sur la base, et j'ai validé les parcours complets à la main. Un test de bout en bout automatisé manque, je le reconnais. »

**🔴 Vous testez avec H2 alors qu'en production c'est PostgreSQL. Ce n'est pas un test faussé ?**
« Il y a un écart, oui. H2 est configuré en mode compatible PostgreSQL et mes requêtes sont standard, mais ce n'est pas identique à 100 %. La solution propre serait de lancer un vrai PostgreSQL dans un conteneur Docker pendant les tests (Testcontainers). C'est une amélioration identifiée. »

**🔴 Les tests sont-ils lancés automatiquement à chaque modification ?**
« Non, je les lance à la main. Il n'y a pas d'intégration continue. L'étape suivante serait une chaîne qui lance tous les tests à chaque envoi de code et bloque si un test échoue. »

**🔴 Pourquoi certains services, comme la passerelle ou Eureka, n'ont-ils qu'un test de démarrage ?**
« Parce qu'ils ne contiennent pas de logique métier : la passerelle ne fait que router, Eureka ne fait qu'annuaire. Il n'y a pas de règle à vérifier. Ce qu'ils font est vérifié quand les parcours fonctionnent. »

**🔴 Vos tests passent-ils tous ?**
Réponds seulement si tu l'as vérifié juste avant. Sinon : « À ma dernière exécution, oui. »

**🔴 Est-ce que c'est l'IA qui a écrit vos tests ?**
« Je me suis servie de l'IA comme assistante, y compris pour écrire du code de test. Mais c'est moi qui ai décidé *quoi* tester, et ce sont mes tests manuels qui ont révélé les défauts, comme ceux du filtre de Xalaat. Je peux vous expliquer ce que vérifie chacun d'eux. »
Ensuite, donne un exemple concret, comme le double débit ou le montant ignoré.

**🔴 Un test qui passe prouve-t-il que le code est correct ?**
« Non. Un test prouve seulement que le code se comporte comme prévu *dans les cas que j'ai imaginés*. Il ne prouve pas l'absence de bug. C'est pour ça que j'ai combiné tests automatisés, tests manuels et revue de sécurité. »

**🔴 Avez-vous fait des tests de charge ou de performance ?**
« Non. La seule mesure de performance que j'ai faite concerne Xalaat : le modèle mettait environ trois minutes à répondre, ce qui m'a fait augmenter le délai d'attente et changer de modèle. Des tests de charge seraient nécessaires avant une mise en production. »

**🔴 Avez-vous fait des tests de sécurité ou d'intrusion ?**
Ne prétends pas avoir fait un test d'intrusion. « J'ai fait une revue de sécurité service par service et des essais manuels, comme accéder aux données d'un utilisateur avec la connexion d'un autre. Et une partie de mes tests automatisés sont des tests de droits d'accès : payer le rendez-vous d'un autre, lire le journal d'un autre, écrire dans une conversation dont on ne fait pas partie. Tous sont refusés. »

**🔴 Avez-vous testé avec de vrais utilisateurs ?**
« Pas encore. Les profils de démonstration ont été créés à la main. Un test avec des patients et des psychologues serait l'étape suivante, surtout pour évaluer la qualité des recommandations. »

**🔴 Deux patients réservent le même créneau à la même milliseconde. Vos tests le couvrent ?**
« Non. Mes tests vérifient la détection des conflits, mais pas deux requêtes exactement simultanées. Dans ce cas rare, les deux vérifications peuvent passer avant l'enregistrement. La vraie protection serait une contrainte d'unicité ou un verrou dans la base. C'est une limite connue. »

**🔴 Comment savez-vous que vos tests testent vraiment quelque chose ? Un test qui ne vérifie rien passe toujours.**
« Chaque test se termine par une vérification précise : une erreur attendue, un statut, un montant débité. Pour Xalaat, j'ai vu des tests échouer avant de corriger le filtre : c'est la preuve qu'ils détectent un vrai défaut. »

**🔴 Quelle est la différence entre une erreur 400, 403, 404 et 503 dans vos tests ?**
- **400** : la requête est mal formée, par exemple un champ obligatoire manquant.
- **403** : la requête est comprise mais interdite, par exemple les données d'un autre.
- **404** : la ressource n'existe pas.
- **503** : un service dont on dépend est indisponible.

**🔴 Si vous deviez ne garder qu'un seul test, lequel ?**
« Le test qui vérifie qu'un rendez-vous déjà payé ne peut pas être débité une deuxième fois. C'est l'argent du patient : une erreur là-dessus détruit la confiance dans la plateforme. »
Autre choix défendable : le filtre de crise de Xalaat, pour l'enjeu humain.

---

## 7. Réponse type en 30 secondes (à apprendre)

> « J'ai environ 130 tests automatisés côté serveur, concentrés là où une erreur coûte cher : l'argent, avec le paiement et le remboursement ; les droits d'accès, pour que personne n'accède aux données d'un autre ; les scores cliniques PHQ-9 et GAD-7 ; la détection de crise de Xalaat ; et la résilience quand un service tombe. Ces tests m'ont fait trouver de vrais défauts. Mes limites : l'application mobile n'a pas de tests automatisés, je n'ai pas de chaîne d'intégration continue ni de test de bout en bout. Ce serait la suite. »
