# Questions possibles du jury, et réponses qui tiennent

Ce fichier regroupe en un seul endroit toutes les fiches de questions préparées
jusqu'ici, avec l'état actuel du projet (24/09/2026).

Le jury ne lit pas le code. Il juge ce que tu montres : la présentation,
l'application, le design, et la logique de tes choix. Toutes les réponses
ci-dessous se disent donc à l'oral, sans écran ni nom de classe.

**Trois règles pour toutes les questions :**

1. **Réponds d'abord en une phrase**, puis développe seulement si le jury relance.
2. **Annonce toi-même tes limites.** Une limite que tu annonces montre que tu maîtrises
   ton sujet. La même limite trouvée par le jury fait douter du reste.
3. **Si tu ne sais pas, dis-le** : « Je ne l'ai pas vérifié, je ne veux pas vous
   répondre au hasard. » C'est toujours mieux qu'une réponse inventée.

---

## 1. Le sujet et la démarche

**« Pourquoi ce sujet ? »**
Parce que l'accès aux soins de santé mentale au Sénégal est un vrai problème : peu de
psychiatres (38 en 2019 selon le ministère), des services concentrés à Dakar, et une
stigmatisation qui retient les gens de consulter. En face, presque tout le monde a un
téléphone. Le sujet réunit un besoin réel et ce que j'ai appris en systèmes répartis.

**« Quel problème PsyConnect résout-il, et pourquoi une application plutôt qu'autre chose ? »**
*(Travaillée en séance le 24/09/2026. Question d'ouverture probable, à tenir en 1 min 30.)*
Structure fixe : trois obstacles, ce que fait l'application, pourquoi une application.
« Au Sénégal, la santé mentale se heurte à trois obstacles. Le regard des autres :
consulter reste tabou, beaucoup renoncent par peur d'être vus. La rareté : peu de
spécialistes, concentrés à Dakar. La distance : pour quelqu'un à Matam ou Kédougou,
consulter veut dire voyager. PsyConnect ne prétend pas faire disparaître la
stigmatisation : il permet de consulter sans avoir à l'affronter, à distance, et en
mode anonyme si on le souhaite. Pourquoi une application ? Une ligne d'écoute ne
couvre que l'écoute, WhatsApp ne protège ni l'identité ni les données de santé, un
annuaire web s'arrête au contact. L'application réunit tout le parcours : trouver un
psychologue vérifié, réserver, payer par mobile money, consulter, puis suivre son état
avec des questionnaires validés. Pour le psychologue, c'est à la fois une vitrine et
un outil de travail. »

À éviter :
- « vulgarisé » pour dire tabou : c'est un contresens (vulgariser = rendre accessible).
- « on résout la stigmatisation » : trop fort, le jury demandera comment tu le mesures.
  Dire « on la contourne » ou « on permet de consulter malgré elle ».
- « tout le monde a un téléphone » sans nuance : le jury répondra coût de la data,
  réseau inégal, pas de smartphone partout. Le reconnaître avant lui.
- Ne comparer qu'aux cabinets : le jury pense aux vraies alternatives (ligne d'écoute,
  WhatsApp, site web).

**« En quoi PsyConnect est-il différent de ce qui existe ? »**
Aucune des dix applications étudiées ne combine les quatre éléments suivants pour le
Sénégal : la mise en relation avec des psychologues vérifiés, un paiement adapté au
contexte local, l'anonymat du patient, et un compagnon IA dont les données restent
sur place.

**« Avez-vous travaillé seule ? Comment vous êtes-vous organisée ? »**
*(À dire selon la réalité.)* Proposition : « Seule, sous la direction de M. Touré.
J'ai avancé par itérations : conception, puis un service à la fois, puis
l'application mobile, avec des tests manuels à chaque étape et une phase finale
consacrée à la vérification et à la correction. »

**« Avez-vous utilisé l'intelligence artificielle pour développer ? »**
Question de plus en plus fréquente. Réponds **selon la réalité**, sans te justifier
à l'excès. Si oui, une formulation honnête : « Oui, comme outil d'assistance, pour
écrire et relire du code. Mais les choix d'architecture sont les miens, j'ai testé
chaque fonctionnalité, et j'ai moi-même trouvé et fait corriger les défauts, par
exemple les trois failles du filtre de Xalaat. Je peux expliquer chaque partie du
système. » Ce que le jury évalue, c'est ta maîtrise. Le reste de ce fichier sert
justement à la démontrer.

**« Qu'avez-vous appris ? »**
À construire un système distribué complet, mais surtout à le remettre en question :
vérifier que la documentation correspond au code, mesurer, et corriger ce qui ne tenait
pas. Par exemple, le premier modèle d'IA était trop lent sur ma machine ; je l'ai
mesuré, puis remplacé.

**« Que feriez-vous différemment ? »**
Trois choses : écrire les tests automatisés en même temps que le code, pas après ;
sortir les mots de passe et secrets de la configuration dès le premier jour ; et
tester plus tôt l'application avec de vrais utilisateurs.

---

## 2. Conception et UML

**« Pourquoi trois diagrammes de cas d'utilisation au lieu d'un seul ? »**
Pour la lisibilité. Chaque acteur a entre 15 et 20 cas d'utilisation ; tout mettre sur
un seul schéma le rendrait illisible. Et ça correspond à l'application : trois
interfaces selon le rôle connecté.

**« Quelle différence entre « include » et « extend » ? »**
« Include » : le sous-cas est **toujours** exécuté (l'administrateur consulte toujours
le justificatif avant de valider un psychologue). « Extend » : le sous-cas n'est
exécuté **que sous une condition** (l'annulation entraîne un remboursement seulement si
elle a lieu 48 heures ou plus avant le rendez-vous).

**« Pourquoi un diagramme de séquence ET un diagramme d'activités pour la
réservation ? »**
Ce sont deux vues différentes. La séquence montre qui parle à qui, et dans quel ordre.
L'activité montre la logique métier : les décisions (le créneau est-il libre ? le
psychologue confirme-t-il ? le solde suffit-il ?) et les chemins d'échec.

**« Dans vos diagrammes de classes, que signifient les traits pleins et les traits
pointillés ? »**
Trait plein : un vrai lien en base entre deux données du même service. Pointillé : un
lien entre deux services. Chaque service a sa propre base, donc la base ne peut pas
garantir ce lien ; c'est l'application qui le vérifie au moment de l'appel.

**« Comment savez-vous que vos diagrammes correspondent à ce qui a été réalisé ? »**
Ils ont été vérifiés un par un par rapport à l'application finale. Cette vérification a
d'ailleurs corrigé le schéma d'architecture : une relation qui n'existait plus a été
retirée, et plusieurs relations réelles qui manquaient ont été ajoutées.

**« Pourquoi l'administrateur peut-il désactiver ET supprimer un compte ? »**
Désactiver est réversible (suspension pendant l'examen d'un signalement, par exemple).
Supprimer est définitif. Ce sont deux besoins de modération différents.

---

## 3. Architecture

**« Pourquoi des microservices plutôt qu'une seule application ? »**
Trois raisons concrètes :
1. **Deux langages** : la recommandation est en Python, le reste en Java. Une seule
   application ne l'aurait pas permis.
2. **Une panne reste locale** : si le compagnon IA tombe, les rendez-vous et les
   paiements continuent.
3. **Je l'ai vérifié en cours de projet** : j'ai sorti le paiement dans un service à
   part sans toucher au reste.

**À ne jamais dire :** « c'est plus sécurisé » (plus de services, c'est plus de portes
d'entrée) ou « c'est plus scalable » (sans le démontrer, le jury te demandera des
chiffres).

**« Quel est le coût de ce choix ? »**
Plus de services à lancer, un débogage plus difficile (j'ai ajouté le traçage
distribué pour suivre une requête d'un service à l'autre), et la cohérence des données
entre services, qu'il faut gérer soi-même. Pour un projet de cette taille, une seule
application bien découpée aurait été plus rapide à livrer.

**« À quoi servent la passerelle, Eureka et Zipkin ? »**
- La passerelle est la porte d'entrée unique de l'application mobile.
- Eureka est l'annuaire : il sait où se trouve chaque service.
- Zipkin trace le parcours d'une requête à travers les services, pour trouver où ça
  bloque.

**« Pourquoi la passerelle ne vérifie-t-elle pas elle-même l'authentification ? »**
Choix volontaire : chaque service vérifie lui-même le jeton. Ainsi, un service reste
protégé même si quelqu'un l'atteint sans passer par la passerelle. Le coût est une
petite duplication de code.

**« Une seule instance PostgreSQL : vous n'avez donc pas vraiment fait des microservices ? »**
*(Travaillée en séance le 24/09/2026. Question piège : ne pas se défendre, distinguer.)*
Réponse en une phrase : « Le principe porte sur la base de données, pas sur le serveur :
j'ai six bases séparées, une par service, hébergées sur un même serveur PostgreSQL. »
Puis développer :
- **Séparation logique respectée** : authentification, utilisateurs, rendez-vous,
  paiement, notifications et séances ont chacun leur base. Aucun service ne lit la base
  d'un autre, aucune jointure entre bases : quand le service des rendez-vous a besoin
  d'une information sur un utilisateur, il la demande au service utilisateurs par son API.
- **Séparation physique non faite, par choix** : dix services plus six serveurs de
  base ne tiennent pas sur une machine de développement. C'est un choix de
  démonstration, pas d'architecture.
- **Migration sans toucher au code** : chaque service lit l'adresse de sa base dans une
  variable de configuration. En production, on change l'adresse, pas le code.
- **Limite à annoncer soi-même** : tous les services se connectent avec le même compte
  administrateur PostgreSQL. Techniquement, un service compromis pourrait donc lire les
  autres bases. La séparation est garantie par la conception, pas imposée par la base.
  Correctif : un compte par service, avec des droits sur sa seule base.
- **Coût assumé** : le serveur PostgreSQL est un point de panne unique. S'il tombe, tous
  les services qui ont une base tombent avec lui.

À éviter : « un seul système de gestion qui englobe toutes les bases » (flou, dire
« un seul serveur, six bases ») ; affirmer que chaque service « ne peut accéder » qu'à
sa base (faux, voir le compte partagé : dire qu'il « n'accède » qu'à la sienne).

**« Pourquoi la visio avec Jitsi plutôt que développée vous-même ? »**
Un appel vidéo fiable demande des serveurs de relais, la traversée des box et la
gestion des formats vidéo. J'ai commencé un service vidéo maison, puis je l'ai
abandonné : Jitsi fournit tout cela, et j'ai concentré mon travail sur ce qui est
propre à PsyConnect, c'est-à-dire qui peut rejoindre quel appel, et à quel moment.

---

## 4. Résilience

**« Que se passe-t-il quand un service tombe ? »**
Ça dépend de l'enjeu. **J'ai choisi de tomber en marche ou de tomber fermé selon ce que
coûte l'échec :**
- les notifications tombent : le rendez-vous est quand même créé ;
- le service qui vérifie l'identité tombe : l'opération est refusée, parce que laisser
  passer quelqu'un qu'on ne peut pas identifier serait une faille ;
- le remboursement échoue : l'annulation aboutit quand même, et un remboursement
  manuel est signalé.

**« Comment fonctionne ce mécanisme ? »**
Chaque appel entre services est retenté trois fois. Si un service échoue trop souvent,
un « disjoncteur » coupe les appels vers lui pendant quelques secondes : on arrête de
solliciter un service à terre, et l'utilisateur n'attend pas pour rien. Ce comportement
est vérifié par des tests automatisés.

---

## 5. Réservation, paiement et visio

**« Que vérifie le système avant d'encaisser un paiement ? »**
Cinq conditions : le rendez-vous appartient bien au patient, il est confirmé par le
psychologue, il n'est ni annulé ni refusé, il n'est pas déjà payé, et le solde suffit.
Une seule manque, le paiement est refusé.

**« Pourquoi un solde interne plutôt qu'un paiement direct ? »**
Avec un paiement direct, le remboursement n'était pas visible. Avec un solde, le patient
recharge une fois, paie ses séances en interne, et un remboursement le recrédite
immédiatement. Ça sépare aussi deux problèmes : payer une séance, et parler à
l'opérateur mobile.

**« Le paiement est-il réel ? »**
Non, et je le dis clairement : la recharge par Wave ou Orange Money est simulée. Une
intégration réelle suppose un contrat commercial avec les opérateurs. Le circuit est
prêt à la recevoir.

**« Le patient paie, puis le service des rendez-vous plante avant d'enregistrer la réservation. Il a perdu son argent ? »**
*(Travaillée en séance le 25/09/2026. Question piège : la prémisse est fausse, il faut la corriger calmement.)*
Réponse en une phrase : « Ce scénario ne peut pas arriver dans PsyConnect, parce que le
paiement vient après la réservation, pas avant. »
Puis développer :
- **L'ordre protège** : le rendez-vous est d'abord créé, puis accepté par le
  psychologue. On ne paie qu'un rendez-vous déjà confirmé, donc déjà enregistré.
- **Si le service des rendez-vous est en panne au moment de payer** : le service de
  paiement commence par lui demander le rendez-vous. Pas de réponse, pas de paiement :
  le patient reçoit « service indisponible, réessayez plus tard », et aucun franc n'a
  bougé. Le système tombe fermé.
- **Le vrai point sensible est ailleurs** : entre le débit du solde (base des
  utilisateurs) et l'enregistrement du paiement (base des paiements). Deux bases, donc
  pas de transaction commune. Si l'enregistrement échoue après le débit, le service de
  paiement recrédite automatiquement le solde : c'est une compensation.
- **Limite à annoncer soi-même** : si le recrédit échoue lui aussi, l'erreur est
  seulement journalisée et l'argent reste débité. Une vraie Saga aurait une file de
  reprise qui réessaie jusqu'à réussir.

À éviter :
- Accepter la prémisse du jury sans la vérifier.
- « Il est notifié » : faux. Le patient voit un message d'erreur dans l'application,
  mais aucune notification n'est envoyée lors d'une compensation.
- Dire que c'est le service des rendez-vous qui rend l'argent : c'est le service de
  paiement qui recrédite, via le service des utilisateurs qui détient le solde.

**« Si le solde est débité mais que le paiement n'est pas enregistré ? »**
Le solde et les paiements sont dans deux services différents, donc je ne peux pas tout
annuler d'un coup. Le système fait alors l'opération inverse : il recrédite
automatiquement le patient. C'est de la cohérence par compensation. Je l'ai mis en
place après avoir vu le cas se produire en test.

**« Pourquoi pas une transaction distribuée ? »**
Elle bloquerait les deux services pendant l'opération et suppose que toutes les bases
la supportent. En microservices, on préfère compenser. Pour des scénarios plus longs,
on passerait à un modèle appelé « Saga ».

**« Deux patients réservent le même créneau au même moment ? »**
Le système vérifie le conflit avant d'enregistrer, mais les deux vérifications
pourraient passer en même temps. C'est une limite connue ; une contrainte d'unicité en
base fermerait complètement ce risque.

**« Quelle règle pour l'annulation ? »**
Seul le patient concerné peut annuler. À 48 heures ou plus du rendez-vous, il est
remboursé sur son solde ; en dessous, l'annulation reste possible mais sans
remboursement.

**« Comment le patient et le psychologue se retrouvent-ils dans le même appel ? »**
C'est le serveur qui crée la salle, pas le téléphone. J'avais un vrai bug : quand les
deux rejoignaient presque en même temps, chacun se retrouvait seul dans sa propre
salle. Je l'ai corrigé en empêchant la création simultanée de deux salles pour le même
rendez-vous.

**« Le bouton « Rejoindre » est-il toujours actif ? »**
Non, seulement de 10 minutes avant la séance jusqu'à 30 minutes après la fin, pour
éviter les appels hors séance. Un rappel est envoyé 10 minutes avant.

---

## 6. Recommandation

**« Que fait votre service de recommandation ? Est-ce du machine learning ? »**
Trois temps : ce que ça fait, ce que ce n'est pas, pourquoi c'est un choix.
« C'est un service de recommandation par filtrage de contenu. Il compare le besoin que le
patient a écrit dans son profil avec le profil de chaque psychologue validé, grâce à
TF-IDF et à la similarité cosinus. Il combine ensuite trois critères (la ressemblance des
textes, la note du psychologue et la même ville) pour obtenir un score entre 0 et 1, et
renvoie les cinq meilleurs. Ce n'est pas du machine learning au sens strict : il n'y a
pas de modèle entraîné. C'est un choix : une plateforme qui démarre n'a aucun historique
pour entraîner un modèle, alors que cette méthode fonctionne dès le premier patient. »
**À éviter :** dire « notre service de machine learning » en début de phrase, puis se
contredire.

*(Travaillée en séance le 25/09/2026.)* Ce qui a tenu : l'honnêteté (« pas
d'apprentissage, pas encore ») et l'argument du démarrage sans données. Ce qui a manqué :
- **Oublier la note du psychologue**, qui pèse 25 % du score. Les trois critères sont :
  ressemblance des textes (60 %), note (25 %), même ville (15 %).
- **Mettre la ville dans TF-IDF** : faux. TF-IDF ne compare que des textes (besoin et
  langue du patient ; spécialité, biographie et langues du psy). La ville est un bonus à
  part, sinon « Dakar » aurait pesé autant que « anxiété ».
- **« Des correspondances »** : trop vague. Dire « une similarité cosinus entre deux
  vecteurs de mots pondérés ».
- **« L'apprentissage viendra plus tard »** sans dire comment : préciser quelles données
  (réservations, séances terminées, avis) et quelle méthode (filtrage collaboratif, ou
  apprendre les poids 0,6 / 0,25 / 0,15 au lieu de les fixer à la main).
- Prononcer **TF-IDF** (Term Frequency – Inverse Document Frequency), pas « TF-TDF ».

**« Si ce n'est pas du machine learning, pourquoi l'appeler "ml-service" ? »**
Reconnaître d'abord : « Vous avez raison, le nom est imprécis. » Puis : TF-IDF et le
cosinus font partie des outils du traitement du langage étudiés en cours de machine
learning, et ce service est l'endroit où un vrai modèle entraîné pourra remplacer le
calcul actuel quand la plateforme aura un historique, sans rien changer au reste de
l'application. « Si c'était à refaire, je l'appellerais "service de recommandation". »

**« Comment le classement est-il calculé ? »**
Trois critères : la ressemblance entre le besoin du patient et le profil du psychologue
(60 %), la note du psychologue (25 %), et le fait d'être dans la même ville (15 %). La
ville pèse peu, parce que la visio rend la distance secondaire.

**« D'où viennent ces pourcentages ? »**
Ce sont des choix de conception raisonnés, pas des valeurs apprises ni mesurées. Le besoin
du patient pèse le plus (60 %) parce que c'est le cœur de la recommandation ; la note sert
à départager les psychologues pertinents (25 %) ; la ville pèse le moins (15 %) parce que
la visio rend la distance secondaire, et c'est un bonus, jamais un filtre. Les trois font
100 %, donc le score reste entre 0 et 1. Ils sont réglables sans modifier le code. Limite :
ils n'ont pas été validés sur de vrais usages ; avec un historique, on les ajusterait sur
les réservations réellement faites.

**« Expliquez simplement comment marche TF-IDF. »**
Commencer par l'idée, pas par la formule : « Un mot compte d'autant plus qu'il est
fréquent dans un texte, et rare dans les autres. TF mesure la fréquence : si un
psychologue écrit plusieurs fois "anxiété", c'est probablement sa spécialité. IDF mesure
la rareté : si tous les psychologues écrivent "psychologue" ou "accompagnement", ces
mots ne distinguent personne, donc leur poids devient presque nul, alors que
"traumatisme", présent chez un ou deux seulement, pèse lourd. On multiplie les deux, et
chaque texte devient une liste de nombres qu'on peut comparer. »
Si le jury demande « concrètement ? » : un tableau avec une ligne par texte, une colonne
par mot du vocabulaire, et dans chaque case le poids du mot (exemple complet dans
`Exemple_TF_IDF.md`).
**À éviter :** citer l'option « smooth » de scikit-learn. Ne jamais citer un détail qu'on
ne peut pas expliquer tranquillement.

*(Travaillée en séance le 25/09/2026, avec la relance « pourquoi pas juste compter les
mots en commun ? ».)* La définition était juste, mais récitée comme un cours, sans
exemple, et la relance n'a pas reçu de réponse. Ce qu'il faut ajouter :
- **Répondre à la relance** : compter les mots en commun met tous les mots au même
  niveau. « Français » partagé avec le patient rapporterait autant que « anxiété »,
  alors que presque tous les psys parlent français : ce mot ne distingue personne.
  TF-IDF donne peu de poids aux mots courants et beaucoup aux mots rares. Et le cosinus
  corrige la longueur : un psy qui écrit une longue biographie n'est pas avantagé juste
  parce qu'il a plus de mots.
- **Donner un exemple PsyConnect** : patient qui cherche « anxiété liée au travail ».
  « Français » apparaît chez presque tout le monde, poids faible. « Anxiété » et
  « travail » sont plus rares, poids fort : ce sont eux qui font remonter le bon psy.
- **Dire ce qu'est « la collection »** : l'ensemble des textes comparés, c'est-à-dire
  les profils des psychologues disponibles et le besoin du patient.
- **Précision sur TF** : dans le code, ce n'est pas le nombre brut d'apparitions mais
  ce nombre divisé par le nombre de mots du texte (une proportion).

**« Une fois les textes transformés en nombres, comment trouvez-vous le psychologue le
plus proche ? »**
Par la similarité cosinus. L'image d'abord : « Chaque texte est une flèche. Si deux
flèches pointent dans la même direction, les textes parlent de la même chose. Le cosinus
mesure cet angle : 1 si elles sont alignées, 0 si elles n'ont rien en commun. » Puis la
formule si on la demande : cosinus = (A · B) ÷ (‖A‖ × ‖B‖). Le produit scalaire A · B
ne compte que les mots communs aux deux textes ; ‖A‖ et ‖B‖ sont les longueurs des
flèches.

**« Pourquoi diviser par les longueurs ? »**
Pour ne garder que la direction, c'est-à-dire le sujet. Sans cette division, un
psychologue avec une longue présentation serait avantagé simplement parce qu'il écrit
plus de mots.

**« Un cosinus peut-il être négatif ? »**
En général oui, jusqu'à −1. Ici non : les poids TF-IDF ne sont jamais négatifs, donc le
résultat reste entre 0 et 1.

**« Si le patient écrit "angoisse" et le psychologue "anxiété" ? »**
Ils ne seront pas rapprochés : TF-IDF compare des mots, pas du sens. Même « anxiété » et
« anxieux » sont deux mots différents pour lui. C'est la principale limite de la méthode ;
des listes de synonymes, ou des plongements de mots (embeddings) qui représentent le
sens, la corrigeraient.

**« Dans votre exemple, un thérapeute de couple passe devant un spécialiste de l'anxiété.
C'est normal ? »**
Ne pas défendre le résultat en bloc : c'est un piège. Répondre « en partie ». « C'est
cohérent avec les poids que j'ai choisis, mais ça révèle deux limites. D'abord, le
spécialiste écrit "anxieux" et le patient "anxiété" : pour TF-IDF ce sont deux mots
différents, donc sa pertinence est sous-estimée. Ensuite, c'est surtout le bonus de la
ville qui fait la différence, alors que je le voulais secondaire à cause de la visio. Il
y a aussi un argument en faveur de ce classement : ce spécialiste ne parle pas français,
et le patient si. Mais mon calcul ne le sait pas vraiment, puisque la langue n'est qu'un
mot parmi d'autres. L'amélioration logique serait de traiter la langue comme un filtre,
et d'ajuster les poids avec de vrais usages. »

**« Quelles sont ses limites ? »**
Il compare des mots, pas des idées : « angoisse » ne rapproche pas d'« anxiété ». Et il
n'a jamais été évalué sur de vrais utilisateurs. Évolution possible : quand il y aura un
historique, passer au filtrage collaboratif (« les patients comme vous ont choisi… »).

**« Si le service de recommandation tombe ? »**
L'application affiche quand même une liste : les psychologues validés, triés par note.

**« Un psychologue non validé peut-il être recommandé ? »**
Non. Seuls les psychologues validés par l'administrateur et disponibles sont classés.

---

## 7. Questionnaires PHQ-9 et GAD-7

**« Pourquoi ces deux questionnaires ? »**
Ce sont des échelles cliniques validées et très utilisées : le PHQ-9 pour la dépression,
le GAD-7 pour l'anxiété. Le psychologue les envoie, le patient répond, le score et le
niveau de sévérité sont calculés automatiquement.

**« Un questionnaire, ce n'est pas un diagnostic ? »**
Non. C'est un outil de repérage que le psychologue interprète. L'application ne pose
aucun diagnostic.

**« Que se passe-t-il si un patient signale des idées suicidaires ? »**
La question 9 du PHQ-9 porte sur ce sujet. Un score total peut être faible alors que
cette réponse est inquiétante. L'application la traite donc à part : dès que la
réponse est élevée, le patient voit tout de suite une carte de soutien avec un accès à
l'aide immédiate, et le psychologue voit le questionnaire signalé en rouge, « à traiter
en priorité ».

**« Pourquoi seulement deux questionnaires ? »**
Choix de temps : j'ai préféré bien traiter la question 9 que multiplier les échelles.
Leur ajout n'est pas encore automatique, c'est une limite. Le prochain utile serait
l'échelle d'Édimbourg (dépression après l'accouchement), vu l'enjeu de santé maternelle
au Sénégal.

---

## 8. Xalaat, le compagnon IA

**« À quoi sert Xalaat ? »**
À aider le patient à **préparer sa première consultation** : comprendre comment elle se
déroule, mettre des mots sur ce qu'il ressent. Il ne pose jamais de diagnostic et ne
remplace pas le psychologue.

**« Pourquoi un nom wolof ? »**
« Xalaat » veut dire « pensée, réflexion ». Un nom familier crée moins de distance
qu'un « assistant IA ».

**« Pourquoi pas ChatGPT, qui serait meilleur ? »**
Parce que ce sont des confidences sur la santé mentale. Les envoyer à une entreprise
étrangère pose un problème de confidentialité. Le modèle tourne en local : il est moins
performant, mais rien ne sort de l'infrastructure.

**« Que se passe-t-il si quelqu'un exprime des idées suicidaires ? »**
Un filtre analyse le message **avant** l'IA. S'il reconnaît une formulation de détresse,
l'IA n'est pas appelée : le patient reçoit un message fixe, écrit à l'avance, avec le
SAMU (1515), le numéro vert du ministère de la Santé (800 00 50 50), la police (17) et
les pompiers (18).

**« Pourquoi ne pas simplement demander à l'IA d'être prudente ? »**
Une IA de ce type est **probabiliste** : elle ne répond pas toujours la même chose, et
elle peut dériver si on insiste. Sur ce sujet, « ça marche la plupart du temps » n'est
pas acceptable. Le filtre, lui, est **déterministe** : même message, même réponse,
toujours.

**« Des mots-clés, c'est rudimentaire, non ? »**
Oui, et c'est voulu : la simplicité garantit le comportement. Un système « intelligent »
serait plus fin, mais il redeviendrait probabiliste, donc faillible sur le cas exact
qu'on veut protéger. Et les consignes données à l'IA lui demandent quand même
d'orienter vers une aide professionnelle : deux barrières plutôt qu'une.

**« Et si la personne écrit en wolof ? »**
Le filtre ne le détectera pas : c'est une limite connue et la première évolution
prévue. Ces expressions devraient être construites avec des locuteurs et des
professionnels, pas inventées.

**« Comment l'avez-vous testé ? »**
À la main, avec des messages de détresse, puis avec un test automatisé sur une
vingtaine de phrases. Ce test m'a permis de trouver et de corriger trois défauts : le
clavier de l'iPhone écrit une apostrophe différente qui empêchait la détection, une
phrase positive (« j'ai envie de vivre ») déclenchait l'alerte, et « je veux en finir »
n'était pas reconnu.

**« Les conversations sont-elles enregistrées ? »**
Non : ni sur le serveur, ni sur le téléphone. La conversation disparaît à la fermeture
de l'écran. Ni le psychologue ni l'administrateur ne peuvent la lire, puisqu'il n'y a
rien à lire.

**« Vous engagez votre responsabilité si quelqu'un se fait du mal ? »**
Rester calme : Xalaat ne se présente jamais comme un soignant, il le rappelle, et face à
une formulation de détresse il renvoie systématiquement vers les urgences. Avant un vrai
déploiement, le texte devrait être validé par des professionnels de santé mentale.

**À ne jamais dire :** « Xalaat détecte les personnes à risque ». **À dire :** « Xalaat
intercepte certaines formulations explicites. »

---

## 9. Sécurité et données de santé

**« Votre application est-elle sécurisée ? »**
Piège : ne réponds jamais simplement « oui ». Réponse : « Elle met en place les
protections essentielles : mots de passe hachés, contrôle d'accès dans chaque service,
vérification que chacun n'accède qu'à ses propres données. Elle n'est pas prête pour la
production en l'état : il manque le chiffrement des échanges et la mise à l'abri des
secrets. Je connais précisément cette frontière. »

**« Comment empêchez-vous un patient de voir les données d'un autre ? »**
Le serveur ne croit jamais l'identifiant envoyé par le téléphone : il le compare à
l'identité contenue dans le jeton de connexion. S'ils diffèrent, la demande est refusée.
C'est la faille la plus courante sur ce type d'application, je l'ai traitée
systématiquement.

**« Comment les mots de passe sont-ils protégés ? »**
Ils sont hachés avec BCrypt, un algorithme volontairement lent et « salé » : même deux
mots de passe identiques donnent deux empreintes différentes. Le code de
réinitialisation envoyé par e-mail est lui aussi haché, avec un nombre limité de
tentatives.

**« Et si quelqu'un vole un jeton de connexion ? »**
Il peut agir au nom de l'utilisateur jusqu'à expiration, 24 heures au plus. Je n'ai pas
mis en place de révocation : c'est une limite assumée. Les solutions classiques sont
des jetons plus courts avec renouvellement, ou une liste de jetons révoqués.

**« Pourquoi pas de HTTPS ? »**
La démonstration tourne en local. En production, le chiffrement se configure devant la
passerelle, sans modifier les services, et l'application mobile n'a qu'une adresse à
changer.

**« Comment fonctionne le mode anonyme ? »**
Le patient peut choisir un pseudonyme : le psychologue voit ce pseudonyme, pas son
identité civile. Juridiquement, c'est une **pseudonymisation**, pas une anonymisation :
la donnée reste liée à une personne, ce qui est nécessaire au suivi et à la
traçabilité. La loi sénégalaise sur les données personnelles (loi n° 2008-12) fait la
même distinction.

**« Qui peut lire les notes cliniques ? »**
Seulement le psychologue qui les a écrites. Ni le patient (ce sont des notes de travail,
comme dans un cabinet), ni l'administrateur.

**« Un psychologue peut-il voir un patient qui n'est pas le sien ? »**
Réponds honnêtement : les notes cliniques restent protégées, chaque psychologue ne voit
que les siennes. Mais la fiche de base d'un patient est visible par tout psychologue, et
le lien de suivi n'exige pas encore de rendez-vous commun. Je l'ai identifié ; la
correction consiste à exiger une relation de soin établie.

**« Qui peut lire les antécédents médicaux ? Qu'est-ce qui empêche un psy de lire ceux
d'un patient qu'il ne suit pas ? »**
*(Travaillée en séance le 25/09/2026. Réponse donnée fausse sur deux points : attention.)*
Réponse en une phrase : « Le patient lui-même, et un psychologue qui l'a marqué comme
suivi. Le serveur vérifie ce lien à chaque lecture. »
Puis développer, en deux verrous :
1. **Le rôle** : il faut être psychologue (ou le patient lui-même). L'administrateur n'y
   a pas accès.
2. **La relation** : le psy doit avoir ce patient dans sa liste de suivi. Sinon, refus :
   « Ce patient ne fait pas partie de vos patients suivis ».
Et chaque modification enregistre qui l'a faite (patient ou psy) et quand.
Puis raconter la faille comme une démarche (**corrigée le 25/09/2026**) : « En relisant
mon code, j'ai trouvé que le lien de suivi, créé par le psy lui-même, n'exigeait aucun
rendez-vous : un psychologue malveillant aurait pu se déclarer suivant et lire les
antécédents. Je l'ai corrigé : le lien n'est accepté que si un rendez-vous a été accepté
entre eux. Ce qui reste perfectible, c'est l'accord explicite du patient. »
Détail si on creuse : le contrôle se fait à la création du lien, pas à chaque lecture,
pour ne pas rendre les antécédents dépendants d'un autre service. Si le service des
rendez-vous est en panne, le lien est refusé : on tombe fermé.

À ne surtout pas dire (c'est faux, et le jury peut le vérifier en démo) :
- ~~« Il faut un rendez-vous pour que le psy commence le suivi »~~ : c'est désormais
  vrai (depuis le 25/09/2026), il faut un rendez-vous accepté.
- « Un psy qui ne suit pas le patient n'a même pas accès à son profil » : non, tout
  psychologue peut lire la fiche de base d'un patient (avec le mode anonyme appliqué).
  Ce qui est protégé, ce sont les antécédents et les notes cliniques.

*(Reposée en séance le 25/09/2026, deuxième fois.)* Le principe du lien de suivi était
bien dit, mais **la faille a encore été oubliée**, et le rôle de qui crée le lien (le psy
lui-même, d'un clic) n'a pas été mentionné. Présenté ainsi, le jury entend « c'est
sécurisé », puis découvre en démo qu'un clic suffit. À réviser en priorité.

**« Les données sont-elles chiffrées dans la base ? »**
Non. Elles sont protégées par les contrôles d'accès de l'application. Le chiffrement de
la base serait un prérequis de production. Ne pas inventer au-delà.

**« Comment savez-vous qu'un psychologue est vraiment psychologue ? »**
L'administrateur examine un justificatif avant de le rendre visible. Tant qu'il n'est pas
validé, il ne peut recevoir aucun rendez-vous. La plateforme ne peut pas vérifier seule
un diplôme : un partenariat avec le ministère permettrait de s'appuyer sur le registre
officiel.

**« Comment avez-vous testé la sécurité ? »**
Ne prétends pas avoir fait un test d'intrusion. Réponse : « Par une revue
systématique, service par service, et par des essais manuels : tenter d'accéder aux
données d'un utilisateur avec la connexion d'un autre. »

---

## 10. Design et expérience utilisateur

**« Pourquoi une seule application pour trois rôles ? »**
Un seul code à maintenir. L'application affiche automatiquement l'interface du rôle
connecté : patient, psychologue ou administrateur.

**« Pourquoi le bouton d'urgence est-il le premier élément de l'accueil patient ? »**
Parce que c'est l'action qui ne doit jamais demander de chercher. Une personne en
détresse n'a pas le temps de parcourir des menus.

**« Comment avez-vous pensé l'interface ? »**
Sobre et rassurante : des couleurs calmes, peu d'effets, une hiérarchie claire. Pour une
personne qui va mal, l'interface ne doit pas être une source de stress. La navigation
tient en quatre onglets, avec la recherche de psychologue au centre.

**« Pourquoi un pseudonyme et pas un compte totalement anonyme ? »**
Le suivi, les paiements et la sécurité exigent de savoir qui est qui côté serveur. Le
pseudonyme protège le patient là où c'est utile, c'est-à-dire face au psychologue.

**« L'application est-elle en wolof ? »**
Pas encore : elle est en français. Le wolof, dans l'interface et dans Xalaat, est la
perspective prioritaire.

**« Avez-vous testé l'application avec de vrais utilisateurs ? »**
Non, pas encore : les profils de démonstration ont été créés à la main. Un test avec des
patients et des psychologues serait l'étape suivante, notamment pour évaluer les
recommandations.

---

## 11. Tests et qualité

**« Comment avez-vous testé l'application ? »**
Trois niveaux : des tests automatisés sur la partie serveur (résilience, filtre de
Xalaat), des tests manuels de chaque service avant de le brancher à l'application, et
des tests d'usage sur l'application elle-même.

**« Pourquoi pas de tests automatisés sur l'application mobile ? »**
Limite assumée : j'ai concentré les tests automatisés là où se trouvent les règles
critiques, côté serveur. Les tests de l'interface seraient la prochaine étape.

**« Un bug dont vous êtes fière de la résolution ? »**
Le bug des appels vidéo : chacun se retrouvait seul dans sa salle. Ou le temps d'attente
de Xalaat : l'application abandonnait au bout de 15 secondes alors que le modèle mettait
trois minutes à répondre. Je l'ai mesuré, j'ai donné plus de temps à Xalaat et j'ai
changé de modèle.

---

## 12. Limites et perspectives

**« Quelles sont les principales limites ? »**
Paiement simulé ; déploiement local, sans chiffrement des échanges ; filtre de Xalaat
limité au français ; application mobile sans tests automatisés ; jetons de connexion non
révocables avant 24 heures.

**« Quelle serait la suite ? »**
Dans l'ordre : brancher les vrais opérateurs de paiement ; passer en production (cloud,
chiffrement, secrets protégés) ; ajouter le wolof ; et, à plus long terme, construire
avec les psychologues partenaires une permanence d'écoute, qui n'existe pas encore au
Sénégal pour la santé mentale.

**« Votre projet est-il viable économiquement ? »**
La plateforme prélève une commission sur chaque séance (20 % par défaut, réglable par
l'administrateur). Le coût des séances reste un frein : un partenariat avec le ministère
pourrait permettre de subventionner des consultations pour les plus vulnérables.

---

## 13. Vocabulaire à maîtriser

- **Microservice** : petite application indépendante qui gère un domaine (paiement,
  rendez-vous…).
- **Passerelle (API Gateway)** : porte d'entrée unique vers les services.
- **Jeton JWT** : « badge » numérique signé, remis à la connexion et présenté à chaque
  demande.
- **Hachage** : transformation à sens unique (on ne peut pas retrouver le mot de passe).
  À ne pas confondre avec le **chiffrement**, qui est réversible avec une clé.
- **Pseudonymisation / anonymisation** : la première peut être inversée par la
  plateforme, la seconde non.
- **Déterministe / probabiliste** : même entrée, même sortie toujours / pas forcément.
- **Compensation** : faire l'opération inverse quand on ne peut pas annuler.
- **Disjoncteur (circuit breaker)** : coupe temporairement les appels vers un service en
  panne.
- **Filtrage de contenu / collaboratif** : recommander selon le profil / selon le
  comportement des autres utilisateurs.
- **Démarrage à froid** : absence d'historique au lancement d'une plateforme.
