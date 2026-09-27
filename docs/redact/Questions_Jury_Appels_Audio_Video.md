# Questions approfondies du jury — appels audio et vidéo

Toutes les réponses ont été vérifiées dans le code le 27/09/2026 (session-service, `call_screen.dart`, `emergency_screen.dart`).
Les questions marquées ⚠️ touchent un point faible. Pour celles-là, la bonne réponse consiste à reconnaître la limite, puis à donner la solution.

---

## A. Choix d'architecture

**1. Pourquoi Jitsi plutôt que coder WebRTC vous-même ?**
Un appel fiable ne se résume pas à `getUserMedia`. Il faut aussi :
- un serveur de signalisation ;
- des serveurs STUN et TURN pour traverser les box et les pare-feu ;
- la négociation des codecs ;
- l'adaptation au débit.

J'ai commencé un video-service en WebRTC natif, puis je l'ai abandonné le 28/08/2026. Jitsi apporte tout ça, et PsyConnect se concentre sur ce qui lui est propre : qui a le droit d'entrer, dans quel salon, et quand.

**2. Concrètement, qu'est-ce que session-service fait, et qu'est-ce qu'il ne fait pas ?**
- Ce qu'il fait :
  - il vérifie que l'appelant est bien le patient ou le psy du rendez-vous ;
  - il vérifie que le rendez-vous est CONFIRMED et qu'on est dans la bonne fenêtre horaire ;
  - il crée ou retrouve la session et fabrique le nom du salon.
- Ce qu'il ne fait pas : il ne transporte aucun flux audio ou vidéo. Les flux passent entre les téléphones et le serveur Jitsi.

**3. Pourquoi `meet.ffmuc.net` et pas `meet.jit.si` ?**
`meet.jit.si` impose une salle d'attente aux utilisateurs anonymes, et on ne peut pas la désactiver depuis l'application. `meet.ffmuc.net` est une instance Jitsi publique sans cette contrainte. C'est un choix de démonstrateur : en production, il faudrait héberger notre propre instance (voir la question 9).

**4. Quelle différence technique entre un appel audio et un appel vidéo dans PsyConnect ?**
Il n'y a qu'un seul mécanisme. L'appel audio est un salon Jitsi ouvert avec la caméra coupée au départ (`startWithVideoMuted: true` quand le type n'est pas VIDEO). Le type de consultation (VIDEO / AUDIO / PHYSICAL) est choisi à la réservation et stocké dans le rendez-vous.

⚠️ Question de suite probable : « Donc en audio, on peut quand même activer la caméra ? » Réponse : oui, la barre d'outils Jitsi le permet. Je le présente comme « démarre en audio » et non comme « audio strict ». Pour l'interdire, il faudrait masquer ce bouton dans la configuration Jitsi.

**5. Le type CHAT existe dans l'énumération. Il sert à quoi ?**
Il est prévu dans le modèle de données, mais l'écran de réservation ne le propose pas : on ne peut choisir que vidéo, audio ou en cabinet. L'échange écrit passe par la messagerie. C'est une valeur réservée, pas une fonctionnalité.

---

## B. WebRTC sous le capot

**6. Comment deux téléphones derrière des box se trouvent-ils ?**
Par ICE. Chaque téléphone collecte des « candidats » (son adresse locale, et son adresse publique découverte grâce à un serveur STUN). Si aucune connexion directe ne passe, le trafic est relayé par un serveur TURN. Tout ça est géré par Jitsi.

**7. À deux participants, les flux passent-ils par le serveur ?**
Jitsi sait faire du pair-à-pair pour les appels à deux. Sinon, les flux passent par son pont vidéo (Jitsi Videobridge), qui est un SFU : il relaie les flux sans les mélanger. Je ne contrôle pas la configuration exacte de `meet.ffmuc.net`, donc je ne peux pas garantir lequel des deux modes est utilisé.

**8. Les appels sont-ils chiffrés ?**
Oui, en transit. WebRTC impose DTLS-SRTP.

⚠️ Mais si le flux passe par le pont Jitsi, ce chiffrement est de proche en proche : le pont peut techniquement voir les flux. Ce n'est pas du chiffrement de bout en bout. Jitsi propose un mode E2EE, qui n'est pas activé ici. Pour une consultation psychologique, c'est la vraie limite : c'est la raison pour laquelle je propose d'héberger notre propre instance.

---

## C. Sécurité et confidentialité

**9. ⚠️ Quelqu'un d'autre peut-il entrer dans le salon ?**
Le salon n'a pas de mot de passe. Sa protection, c'est son nom, `psyconnect-{idRdv}-{8 caractères aléatoires}`, qui est :
- fabriqué par le serveur ;
- remis uniquement aux deux participants, après contrôle du jeton ;
- difficile à deviner.

C'est de l'obscurité, pas un contrôle d'accès. La vraie solution est une instance Jitsi à nous, configurée pour exiger un jeton JWT signé par session-service à chaque entrée dans un salon.

**10. Les séances sont-elles enregistrées ?**
Non. L'enregistrement, la diffusion en direct, l'invitation de participants et le chat Jitsi sont désactivés dans l'application (`recording.enabled`, `live-streaming.enabled`, `invite.enabled`, `chat.enabled` à false). La base ne garde que des métadonnées : début, fin, durée et statut.

**11. Et l'anonymat du patient dans l'appel ?**
Le nom affiché dans la visio est le pseudo du patient, pas son nom réel. Le psy voit donc le même pseudo que dans le reste de l'application.

**12. Vous utilisez un serveur public tiers pour des données de santé. Est-ce acceptable ?**
Pour un démonstrateur, oui. Pour une mise en production, non. Aucun flux ne transite par nos serveurs, mais un serveur que nous ne maîtrisons pas relaie des séances de soin. En production, il faudrait héberger Jitsi, idéalement au Sénégal, conformément à la loi sénégalaise sur les données personnelles (loi n° 2008-12, contrôlée par la CDP).

---

## D. Concurrence et cycle de vie de la session

**13. Comment garantissez-vous que les deux participants arrivent dans le même salon ?**
Deux mécanismes se complètent :
- c'est le serveur qui fabrique le nom du salon, pas le téléphone ;
- la séquence « chercher une session ouverte, sinon en créer une » est dans un bloc `synchronized`, donc le second participant qui arrive récupère la session créée par le premier.

**14. Racontez le bug de concurrence.**
Avant, les deux étapes n'étaient pas atomiques. Quand le patient et le psy cliquaient à quelques millisecondes d'écart, chacun ne trouvait aucune session et en créait une. Résultat : deux salons, chaque participant seul dans le sien. J'ai repéré le bug en test réel et je l'ai corrigé le 02/09/2026 avec le verrou.

**15. ⚠️ Ce verrou tient-il si on lance trois instances de session-service ?**
Non. `synchronized` ne protège qu'une JVM. Il faudrait :
- une contrainte d'unicité en base sur (rendez-vous, session en cours) : la seconde insertion échoue, et on relit alors la session existante ;
- ou un verrou distribué, par exemple avec Redis.

Remarque à connaître : `meetingToken` est déjà unique en base, mais ça ne suffit pas, puisque les deux créations produisent deux noms différents.

**16. Si le réseau coupe en pleine séance ?**
Raccrocher ou perdre le réseau ne ferme pas la session. L'application revient à l'écran d'avant-appel, et « Rejoindre » renvoie le même salon, car la recherche d'une session ouverte a lieu avant les contrôles d'horaire.

**17. Alors qui ferme la session ?**
Deux voies :
- `SessionExpiryScheduler` passe toutes les 5 minutes et clôt les sessions dont le rendez-vous est terminé depuis plus de 30 minutes ;
- la fermeture explicite, `PUT /sessions/{id}/end`, passe la session et le rendez-vous en COMPLETED, puis notifie le patient.

⚠️ Seul le patient est notifié à la fin, jamais le psy. Cette limite est écrite dans le mémoire (§5.3).

**18. Pourquoi la même fenêtre de 10 minutes avant et 30 minutes après côté application et côté serveur ?**
- Côté application, c'est du confort : le bouton n'apparaît qu'au bon moment.
- Côté serveur, c'est la vraie règle : une requête forgée hors créneau est refusée.

Au début, les deux règles n'étaient pas alignées : l'application proposait « Rejoindre » alors que le serveur refusait. Je les ai alignées depuis.

**19. Que se passe-t-il si session-service n'arrive pas à joindre appointment-service ?**
L'appel passe par un `AppointmentClient` protégé par Resilience4j :
- 3 tentatives espacées d'environ 300 ms ;
- un disjoncteur qui s'ouvre au-delà de 50 % d'échecs sur les 10 derniers appels.

Les erreurs métier (rendez-vous introuvable, accès interdit) sont exclues des nouvelles tentatives : réessayer ne changerait rien.

---

## E. L'appel d'urgence (le point le plus sensible)

**20. ⚠️ Comment le psychologue est-il prévenu d'un appel d'urgence ?**
C'est la limite la plus importante, et je la reconnais. Le patient choisit un psy qui s'est déclaré disponible pour l'urgence, et un salon `psyconnect-sos-…` est créé. Mais le psy ne reçoit aucune notification, et son application n'a aucun écran pour rejoindre ce salon. En l'état, le patient se retrouve seul dans le salon. C'est pour ça que je présente ce module comme un démonstrateur.

Ce qu'il faut ajouter :
1. une notification push au psy choisi (FCM) ;
2. un écran d'appel entrant, avec Accepter / Refuser ;
3. un délai au bout duquel on bascule vers un autre psy disponible, puis vers les numéros d'urgence (SAMU 1515).

**21. ⚠️ L'appel d'urgence est-il sécurisé ?**
Moins que les appels sur rendez-vous :
- l'identifiant du patient vient du corps de la requête, au lieu d'être déduit du jeton ;
- `getSessionById` ne vérifie pas la participation pour une session d'urgence.

C'est listé dans l'audit de sécurité. La correction consiste à déduire le patient du JWT, comme partout ailleurs, et à appliquer le même contrôle de participation.

**22. Quelle est la responsabilité éthique si un patient en crise tombe dans le vide ?**
C'est justement pour ça que le garde-fou de Xalaat renvoie vers le SAMU et les numéros d'urgence, pas vers PsyConnect. Une permanence réelle demande :
- des psys d'astreinte, avec un planning ;
- un accord institutionnel (§5.4.4) ;
- toujours un repli vers les services d'urgence publics.

---

## F. Contexte sénégalais et passage à l'échelle

**23. Vos appels tiennent-ils en 3G, hors de Dakar ?**
Je ne l'ai pas mesuré en conditions réelles, et je le dis. Jitsi adapte la résolution au débit disponible, et l'audio (codec Opus) consomme peu : quelques dizaines de kbit/s. C'est d'ailleurs un argument pour l'option audio. Un test terrain et, si besoin, un serveur TURN dédié (coturn) sont dans les perspectives (§5.4.1).

**24. Et le coût en data pour le patient ?**
Une visio consomme beaucoup plus qu'un appel audio. C'est une vraie barrière au Sénégal, et c'est pour ça que l'audio est proposé comme type de consultation à part entière dès la réservation.

**25. Comment passeriez-vous à 1 000 séances simultanées ?**
- session-service est léger : il ne gère que des métadonnées. On le duplique, en remplaçant le verrou par une contrainte d'unicité en base (voir la question 15).
- Le vrai coût est côté média. Avec notre propre Jitsi, on ajoute des ponts vidéo (Videobridge) et des serveurs TURN, de préférence sur Kubernetes (§5.4.2).

---

## G. Tests

**26. Comment avez-vous testé les appels ?**
En conditions réelles, sur deux appareils (un compte patient et un compte psy), et c'est comme ça que j'ai trouvé le bug des deux salons. En revanche, il n'y a pas de test automatisé de session-service ni de l'écran d'appel Flutter. Un test naturel à ajouter : lancer deux `startSession` en parallèle sur le même rendez-vous, et vérifier qu'une seule session est créée.
