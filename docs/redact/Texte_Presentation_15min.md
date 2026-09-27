# Texte de présentation : soutenance en 15 minutes

Ce texte n'est pas à apprendre par cœur. Il sert à te mettre dans le bain :
lis-le à voix haute deux ou trois fois pour trouver ton rythme, puis présente
avec tes propres mots en t'appuyant sur les slides. Les phrases en **gras** sont
celles qu'il vaut la peine de garder telles quelles.

**Budget :** environ 12 minutes de parole et 3 minutes de vidéo. À un débit
calme (environ 130 mots par minute), le texte fait la bonne longueur. Si tu
dépasses, raccourcis la slide 5 (l'existant) et la slide 12 (sécurité), jamais
Xalaat ni les limites.

---

## Slide 1 : Titre (30 s)

Mesdames et messieurs les membres du jury, bonjour.

Je m'appelle Ndeye Maguette Kane. Je vais vous présenter mon mémoire de Master 2
en Systèmes d'Information Répartis : **PsyConnect, une plateforme mobile pour
l'accès aux soins de santé mentale au Sénégal**, réalisée sous la direction de
M. Bassirou Touré.

## Slide 2 : Plan (20 s)

Je commencerai par le contexte et la problématique, puis les solutions
existantes. Je présenterai ensuite la conception et la réalisation, avec une
courte démonstration. Je m'arrêterai sur deux points techniques que je trouve
importants, avant de terminer par les limites et les perspectives.

## Slide 3 : Contexte (1 min)

**Au Sénégal, le problème n'est pas le soin, c'est l'accès au soin.**

Le plan stratégique du ministère de la Santé recense 38 psychiatres pour tout le
pays. Les services sont concentrés à Dakar. Et ce même plan note qu'il n'existe
pas de numéro vert dédié aux urgences psychiatriques.

À cela s'ajoute la stigmatisation. Consulter un psychologue reste une démarche
difficile, qu'on hésite à faire, et parfois qu'on cache.

En face, presque tout le monde a un téléphone. C'est de ce décalage qu'est parti
le projet.

## Slide 4 : Problématique (50 s)

D'où ma question : **comment faciliter l'accès à des psychologues vérifiés,
outiller les praticiens, et offrir un suivi continu, sécurisé et confidentiel,
dans le contexte sénégalais ?**

Les difficultés ne sont pas les mêmes pour chacun. Le patient ne sait pas à qui
s'adresser, prend rendez-vous par téléphone et appréhende la première séance. Le
psychologue manque de visibilité et gère son agenda et ses paiements à la main.
Et personne ne vérifie facilement qu'un praticien est bien qualifié.

## Slide 5 : Solutions existantes (1 min)

J'ai étudié dix applications avant d'écrire une ligne de code. Elles se
rangent en trois familles.

Les grandes plateformes, comme BetterHelp, sont complètes mais inaccessibles
ici : abonnement en dollars, aucun paiement local. Les solutions africaines,
comme Consultel, connaissent le terrain mais font de la médecine générale, pas
de la santé mentale. Et les compagnons IA, comme Wysa, n'offrent aucune mise en
relation avec un professionnel.

**Aucune ne réunit ces dimensions pour le Sénégal. C'est la place de PsyConnect.**

## Slide 6 : La solution (1 min)

PsyConnect, c'est une seule application qui s'adapte à trois rôles.

Le patient trouve un psychologue vérifié, avec des recommandations adaptées à
son besoin. Il réserve un créneau, paie depuis son solde et consulte en vidéo ou en audio.
Il dispose aussi d'un journal, des questionnaires PHQ-9 et GAD-7, du compagnon
Xalaat, et peut utiliser un pseudonyme.

Le psychologue n'est visible qu'après validation de son justificatif. Il gère
ses disponibilités, son agenda, ses notes cliniques privées et ses revenus.

L'administrateur valide les praticiens, traite les signalements et diffuse des
annonces.

## Slide 7 : Conception (50 s)

Le système a été modélisé en UML avant et pendant le développement : onze
diagrammes au total. Trois diagrammes de cas d'utilisation, un par acteur ; deux
diagrammes de classes ; quatre diagrammes de séquence pour les flux principaux ;
et deux diagrammes d'activités pour la réservation et l'annulation.

Ces diagrammes ont été vérifiés par rapport au code : **ils décrivent ce qui
existe, pas ce qui était prévu.**

## Slide 8 : Architecture (1 min 30)

Techniquement, PsyConnect repose sur une architecture microservices. L'application
Flutter parle à une passerelle unique, qui trouve les services grâce à un
annuaire, Eureka. Derrière, huit services : sept en Java avec Spring Boot, et
un en Python, pour la recommandation. Chaque service qui stocke des données a sa
propre base PostgreSQL.

Pourquoi ce choix ? Trois raisons concrètes.

D'abord, il m'a permis d'utiliser **deux langages** : Python pour la
recommandation, Java pour le reste.

Ensuite, **une panne reste locale.** Si le compagnon IA ralentit ou tombe, les
rendez-vous et les paiements continuent de fonctionner.

Enfin, je l'ai vérifié en cours de projet : j'ai extrait le paiement dans un
service dédié sans toucher au reste du système.

Ce choix a un coût, et je l'assume : plus de services à lancer, et un débogage
plus difficile, que j'ai compensé avec du traçage distribué, Zipkin.

## Slide 9 : Résilience (1 min)

C'est le premier point technique sur lequel je voulais insister.

Quand un service ne répond pas, le système ne réagit pas partout de la même
façon. **J'ai choisi de tomber en marche ou de tomber fermé selon l'enjeu.**

Si le service de notifications est en panne, le rendez-vous est quand même
créé : une notification perdue est tolérable.

Si le service qui vérifie l'identité est en panne, l'opération est refusée. Sans
savoir qui fait la demande, laisser passer serait une faille.

Et si le remboursement échoue lors d'une annulation, l'annulation aboutit, et
l'échec est journalisé pour qu'un remboursement manuel soit fait.

Les cas des notifications et de l'identité sont couverts par des tests
automatisés.

## Slide 10 : Démonstration (15 s + 3 min de vidéo)

Je vous propose maintenant de voir l'application en fonctionnement, à travers le
parcours d'un patient : il cherche un psychologue, réserve, le psychologue
confirme, le patient paie, puis la consultation vidéo commence.

*[Lancer la vidéo. Pendant qu'elle tourne, tu peux commenter brièvement chaque
étape, ou la laisser parler d'elle-même.]*

## Slide 11 : Xalaat (1 min 30)

Le deuxième point, c'est Xalaat, notre compagnon IA. Xalaat signifie « pensée,
réflexion » en wolof.

**Son rôle est d'aider le patient à préparer sa première consultation** :
comprendre comment elle se déroule, mettre des mots sur ce qu'il ressent. Il ne
pose jamais de diagnostic et ne remplace pas le psychologue.

Le modèle de langage tourne en local, avec Ollama : aucune conversation ne part
chez un fournisseur extérieur, et rien n'est enregistré, ni sur le serveur ni
sur le téléphone.

Mais mettre une IA face à quelqu'un qui va mal pose une vraie question : que se
passe-t-il si la personne exprime des idées suicidaires ? Un modèle de langage
est probabiliste. Il peut dériver si on insiste. **Sur ce sujet, « ça marche la
plupart du temps » n'est pas acceptable.**

J'ai donc placé un filtre déterministe avant le modèle. Si le message contient
une formulation de détresse, le modèle n'est pas appelé. La réponse est un
message fixe, avec le SAMU et le numéro vert du ministère.

Ce filtre a ses limites. Il reconnaît des formulations en français, pas le wolof
ni l'argot. C'est un filet de sécurité, pas un diagnostic. Il est couvert par un
test automatisé, qui m'a d'ailleurs permis de trouver et de corriger trois
défauts.

## Slide 12 : Sécurité et confidentialité (40 s)

Comme il s'agit de données de santé, la sécurité a été pensée à chaque niveau.
Chaque service vérifie lui-même le jeton d'authentification. Le serveur vérifie
qu'un patient n'accède qu'à ses propres données. Les mots de passe sont hachés.
Le mode anonyme remplace le nom du patient par un pseudo côté psychologue. Et les notes cliniques
ne sont visibles que par leur auteur.

## Slide 13 : Limites et perspectives (1 min)

Je tiens à être claire sur les limites.

Le paiement mobile est simulé : les API de Wave et d'Orange Money nécessitent un
contrat commercial. Le déploiement est local, sans chiffrement des échanges. Le
filtre de Xalaat ne couvre que le français. Et l'application mobile n'a pas de
tests automatisés.

Chacune de ces limites ouvre une perspective : intégrer les vrais opérateurs de
paiement, passer en production, ajouter le wolof dans l'interface et dans Xalaat,
et, à plus long terme, construire une permanence d'écoute avec les psychologues
partenaires.

## Slide 14 : Conclusion (30 s)

Pour conclure, **PsyConnect réunit dans une seule application, pensée pour le
Sénégal, la mise en relation avec des psychologues vérifiés, la réservation, le
paiement, la consultation à distance et un compagnon IA encadré.**

Ce projet m'a appris à construire un système distribué complet, et surtout à le
remettre en question.

Je vous remercie de votre attention, et je suis prête à répondre à vos
questions.

---

## Avant de répéter

- Chronomètre-toi au moins trois fois, dont une devant quelqu'un.
- Si tu bloques, reviens à l'idée de la slide, pas à la phrase exacte.
- Les deux moments à ne pas précipiter : « tomber en marche ou tomber fermé »
  (slide 9) et « ça marche la plupart du temps n'est pas acceptable » (slide 11).
  Marque une courte pause juste avant.
