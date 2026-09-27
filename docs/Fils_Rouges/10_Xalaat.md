# 10 — Xalaat : maîtriser le compagnon IA pour la soutenance

Fiche de révision sur le service `ai-companion-service` et son écran Flutter.
Tout ce qui suit a été relu dans le code réel le 24/09/2026. Le garde-fou a
été corrigé le même jour (partie 6) et il est maintenant couvert par un test
automatisé.

Complète `Comprendre_PsyConnect.md` (sections 1 à 3) : ici on descend d'un
cran, jusqu'au trajet exact d'un message, et on prépare les questions qui
fâchent.

---

## 0. Si tu ne retiens que ça

**En une phrase :** Xalaat est un compagnon de préparation à la première
consultation, servi par un petit modèle de langage open source qui tourne en
local, protégé par un filtre déterministe qui intercepte les messages de crise
avant qu'ils n'atteignent le modèle, et qui ne conserve rien.

**Les quatre idées porteuses :**

1. **Préparer, pas soigner.** Aucun diagnostic, aucun conseil médical, aucune
   substitution au psychologue.
2. **Local.** Le modèle tourne sur la machine du projet via Ollama. Aucune
   donnée ne part chez un tiers.
3. **Sans mémoire serveur.** Pas de base, pas de journal du contenu. C'est le
   téléphone qui garde la conversation, en mémoire vive, le temps de l'écran.
4. **Le garde-fou passe avant le modèle.** Sur le chemin de crise, la réponse
   est un texte fixe. Zéro hasard.

**Les deux mots à placer :** *déterministe* et *avant l'appel au modèle*.

---

## 1. Le besoin

Quand on n'a jamais consulté, le plus dur n'est pas de réserver : c'est de
savoir quoi dire une fois en face du psychologue. Beaucoup renoncent à ce
moment-là, d'autant plus au Sénégal où consulter reste stigmatisé.

Xalaat (wolof : « pensée, réflexion ») aide le patient à :

- comprendre comment se passe une première séance ;
- se rassurer s'il appréhende ;
- mettre des mots sur ce qu'il ressent et sur ce qu'il veut aborder ;
- faire un exercice simple de respiration ;
- passer à l'action : réserver.

Le compagnon se place **en amont** du soin, jamais à sa place. C'est ce
positionnement qui rend l'usage d'un LLM acceptable dans une application de
santé mentale.

Point d'entrée : bannière « Parler à Xalaat » sur l'accueil patient. Le service
accepte techniquement tout utilisateur connecté (patient, psy, admin), mais
seul l'accueil patient y mène.

---

## 2. Où il se place dans l'architecture

```
 Téléphone (Flutter)
   XalaatScreen ── garde _messages et _history en mémoire vive
        │
        │ POST /companion/chat   { message, history[] }   + jeton JWT
        ▼
 api-gateway ── route /companion/** → lb://AI-COMPANION-SERVICE
        │           (demande l'adresse à Eureka)
        ▼
 ai-companion-service (Spring Boot, port 8087)
   JwtAuthenticationFilter ── jeton valide ? sinon 401/403
   CompanionController     ── valide le corps (@Valid)
   CompanionService
     1. RiskDetectionService.isRisky(message) ?
          oui → texte fixe + flagged:true   (le modèle n'est PAS appelé)
          non ↓
     2. ChatClient (Spring AI) : prompt système + historique + message
        │
        ▼
 Ollama (sur la machine hôte, port 11434) ── modèle qwen2.5:3b
```

Pas de base de données. Pas de Feign vers les autres services. C'est le seul
microservice du projet **sans état** au sens strict : il ne se souvient de rien
entre deux requêtes.

En Docker, le service est dans un conteneur mais Ollama tourne **nativement sur
le Mac** pour profiter de l'accélération Metal (GPU intégré de la puce M1). Le
conteneur le joint via `host.docker.internal:11434`.

### Les fichiers, et le rôle de chacun

**Backend** (`backend/ai-companion-service`) — 12 classes Java, c'est court :

| Fichier | Rôle |
|---|---|
| `CompanionController` | Un seul point d'entrée : `POST /companion/chat`. Ne journalise jamais le contenu. |
| `CompanionService` | L'orchestrateur : garde-fou d'abord, modèle ensuite. |
| `RiskDetectionService` | Le garde-fou : 33 motifs, normalisation, vrai/faux. |
| `CompanionPrompts` | Deux textes fixes : le prompt système et le message de secours. |
| `ChatClientConfig` | Construit le `ChatClient` Spring AI avec le prompt système par défaut. |
| `ChatRequest` / `ChatTurn` / `ChatResponse` | Le contrat JSON. `message` ≤ 4000 caractères, `role` limité à `user` ou `assistant`. |
| `SecurityConfig`, `JwtAuthenticationFilter`, `JwtService` | Même mécanisme JWT que les autres services : il faut être authentifié, aucun rôle précis exigé. |
| `application.properties` | Modèle, température, URL Ollama, Zipkin. |

**Flutter** (`frontend/psyconnect/lib/features/companion`) :

| Fichier | Rôle |
|---|---|
| `xalaat_screen.dart` | L'écran de discussion. Tient deux listes en mémoire : ce qui s'affiche (`_messages`) et ce qu'on renvoie au serveur (`_history`). Bulle dorée « Aide immédiate » si `flagged`. |
| `companion_service.dart` | Fait l'appel HTTP avec un délai d'attente dédié de 90 s. |
| `companion_models.dart` | `CompanionTurn` et `CompanionReply`, le miroir du contrat backend. |

---

## 3. Le trajet d'un message, pas à pas

Exemple : le patient écrit « J'ai peur de ne pas savoir quoi dire ».

1. **Écran.** `_send()` copie l'historique actuel (`historyBeforeSend`), puis
   affiche le message et l'ajoute à `_history`. Le bouton se bloque
   (`_sending`) pour éviter les doubles envois.
2. **Appel.** `CompanionService.chat()` envoie
   `{ "message": "J'ai peur…", "history": [ …tours précédents… ] }`, avec le
   jeton lu dans le stockage sécurisé du téléphone. Délai max : 90 s.
3. **Passerelle.** Elle voit `/companion/**`, demande à Eureka où se trouve
   `AI-COMPANION-SERVICE`, et transmet. Elle ne vérifie pas le jeton : c'est un
   routeur.
4. **Filtre JWT.** Le service vérifie la signature du jeton. Invalide ou absent
   → la requête est refusée, le modèle n'est jamais sollicité.
5. **Validation.** Message vide ou > 4000 caractères, ou `role` autre que
   `user`/`assistant` → 400.
6. **Garde-fou.** `isRisky(message)` : minuscules, accents retirés, puis test
   des 33 motifs. Ici, aucun ne correspond.
7. **Construction du prompt.** Spring AI assemble, dans l'ordre : le prompt
   système (placé automatiquement par `ChatClientConfig`), chaque tour de
   l'historique converti en `UserMessage` ou `AssistantMessage`, puis le
   nouveau message.
8. **Inférence.** Ollama fait générer la réponse par `qwen2.5:3b`,
   température 0,6.
9. **Réponse.** `{ "reply": "…", "flagged": false }`. L'écran l'affiche et
   l'ajoute à `_history` pour le tour suivant.
10. **Fermeture de l'écran.** Les deux listes disparaissent avec l'objet
    d'état. Plus aucune trace nulle part.

**Variante crise.** Le patient écrit « j'ai envie de mourir ». À l'étape 6, le
motif `envie de mourir` correspond. Le service renvoie immédiatement
`SAFETY_FALLBACK_MESSAGE` avec `flagged: true`. Les étapes 7 et 8 n'ont pas
lieu : Ollama ne reçoit rien. L'écran affiche la bulle dorée avec l'icône
d'assistance.

**Nuance à connaître.** Ce message de crise reste dans `_history` côté
téléphone. Si le patient écrit ensuite « merci », ce nouveau message part au
modèle **avec** l'historique, donc avec le message de crise et la réponse fixe.
Le modèle ne répond jamais *au* message de crise, mais il le voit au tour
suivant. C'est plutôt souhaitable (il a le contexte, et son prompt lui dit
d'orienter vers une aide professionnelle), mais la phrase exacte est « le
modèle ne traite jamais le message de crise », pas « le modèle ne voit jamais
de contenu de crise ».

---

## 4. Les briques techniques, expliquées

### Ollama

Un logiciel qui télécharge et fait tourner des modèles de langage open source
sur sa propre machine, et les expose en HTTP (`localhost:11434`). Il joue ici le
rôle qu'OpenAI jouerait pour une application qui paie une API, sauf que tout
reste chez soi.

`pull-model-strategy=never` : le service ne télécharge jamais le modèle tout
seul au démarrage. Un modèle pèse plusieurs gigaoctets, ce téléchargement doit
être un geste volontaire (`ollama pull qwen2.5:3b`).

### Le modèle : qwen2.5:3b

- Famille Qwen 2.5, publiée en open source par Alibaba.
- « 3b » = 3 milliards de paramètres. C'est petit pour un LLM : il tient dans
  la mémoire d'un MacBook M1 8 Go.
- Choisi **après** Mistral 7B, par contrainte matérielle mesurée : Mistral
  répondait en ~3 minutes (≈ 66 s de chargement + ≈ 4 jetons/s). Le patient
  attendait, l'application abandonnait à 15 s. `qwen2.5:3b` est nettement plus
  rapide et reste correct en français.
- Le modèle est changeable sans toucher au code : variable d'environnement
  `OLLAMA_MODEL`.

### Spring AI et le ChatClient

Spring AI est la couche d'abstraction de l'écosystème Spring pour les modèles
de langage. Le `ChatModel` pour Ollama est configuré automatiquement à partir
des propriétés `spring.ai.ollama.*`. `ChatClientConfig` construit un
`ChatClient` qui colle le prompt système devant chaque conversation.

Intérêt concret : si demain on passe d'Ollama à un autre fournisseur, on change
la dépendance et la configuration, pas `CompanionService`.

### Le prompt système

Le texte d'instructions envoyé au modèle avant la conversation. Celui de Xalaat
fixe :

- **l'identité** : s'appelle Xalaat, sait expliquer son nom ;
- **le rôle** : préparation à une première consultation, « tu n'es pas un
  professionnel de santé » ;
- **ce qu'il peut faire** : informer, rassurer, aider à formuler, respiration,
  encourager à réserver ;
- **quatre interdits** : diagnostic ou nom de trouble, se présenter comme
  professionnel, conseil médical, laisser croire que ça remplace un suivi ;
- **un rappel régulier mais naturel** de ce qu'il est ;
- **un réflexe de crise** (seconde couche, voir partie 5) ;
- **la forme** : français, chaleureux, sans jargon, concis.

### La température : 0,6

Règle le degré de hasard dans le choix des mots. Proche de 0 : réponses
prévisibles, répétitives. Au-delà de 1 : créatives, parfois incohérentes. 0,6
donne un ton naturel sans partir dans tous les sens. Ce n'est pas la
température qui assure la sécurité : c'est le garde-fou.

### Sans état : l'historique renvoyé à chaque appel

Un modèle de langage n'a pas de mémoire propre : à chaque appel, il faut lui
redonner toute la conversation. Deux options :

- le serveur stocke la conversation (base ou cache) ;
- le client la garde et la renvoie à chaque fois.

PsyConnect a pris la seconde, pour la confidentialité : le serveur ne peut pas
fuiter ce qu'il n'a pas. Coût : la requête grossit à chaque tour.

### Le délai d'attente de 90 secondes

Toute l'application coupe les requêtes à 15 s. Seul l'appel à Xalaat a un délai
dédié de 90 s (`ApiConstants.companionChatTimeout`), parce qu'une génération sur
un modèle local est lente, surtout au premier appel quand le modèle doit être
rechargé en mémoire.

### Traçage Zipkin

Le service envoie à Zipkin les **métadonnées** de chaque requête (durée, statut
HTTP, identifiant de trace), jamais le corps. Le `build.gradle` le rappelle : ne
jamais passer ce service en niveau de log DEBUG en production, certains logs
HTTP pourraient inclure le contenu des messages.

---

## 5. Le garde-fou en détail

### Pourquoi il existe

Un LLM est **probabiliste** : la même entrée ne produit pas toujours la même
sortie, et un utilisateur qui insiste ou reformule peut le faire dériver malgré
des instructions « ne jamais… ». Sur une idéation suicidaire, « ça marche la
plupart du temps » n'est pas acceptable.

Le filtre est **déterministe** : même entrée, même sortie, toujours. Sur ce
chemin, on ne dépend plus du modèle.

### Comment il marche

1. Message vide → pas de risque.
2. Normalisation : minuscules, suppression des accents (« Épuisé » devient
   « epuise »), apostrophes typographiques ramenées à l'apostrophe simple
   (`’` → `'`, le clavier de l'iPhone), espaces multiples réduits à un seul.
3. Test de 33 expressions régulières. Une seule correspondance suffit.

Exemples de motifs : `me suicider`, `envie de mourir`, `me faire du mal`,
`en finir avec (ma vie|tout|cette vie|l'existence|mes jours)`,
`sauter du (pont|toit|immeuble|balcon)`, `le monde irait mieux sans moi`,
`j'ai prepare (ma|ce qu'il faut pour)`.

Les motifs sont compilés une seule fois au chargement de la classe : le coût
par message est négligeable devant l'inférence.

### Le message de secours

Texte fixe (`SAFETY_FALLBACK_MESSAGE`), jamais généré :

- reconnaissance (« ce que tu traverses semble vraiment difficile ») ;
- honnêteté (« je ne suis pas la bonne ressource ») ;
- numéros sénégalais vérifiés : SAMU **1515**, numéro vert du
  ministère de la Santé **800 00 50 50** (ligne générale du ministère, pas propre à la santé mentale), Police **17**, Pompiers **18** ;
- priorité à l'appel direct sur la réservation, qui n'est pas instantanée ;
- « Tu n'es pas seul·e. »

### Les deux couches

| Couche | Nature | Force | Faiblesse |
|---|---|---|---|
| 1. Filtre avant le modèle | Règle en dur | Garanti, déterministe | Ne voit que les formulations listées |
| 2. Consigne dans le prompt | Instruction au modèle | Comprend les reformulations | Aucune garantie |

C'est de la **défense en profondeur** : ce que la couche 1 rate, la couche 2
rattrape souvent.

### Le choix du faux positif

Faux positif : quelqu'un qui va bien reçoit un message bienveillant et des
numéros. Désagréable, sans danger. Faux négatif : quelqu'un en détresse reçoit
une réponse générique. Les deux erreurs n'ont pas le même coût, donc le filtre
est réglé pour se déclencher trop plutôt que pas assez.

---

## 6. Ce que le filtre attrape et rate vraiment

État après correction du 24/09/2026, vérifié par exécution. **À connaître par
cœur** : si le jury teste en direct, tu dois déjà savoir ce qui va se passer.

| Message saisi | Résultat | Commentaire |
|---|---|---|
| « Je veux me suicider » | Intercepté | |
| « JE VEUX MOURIR » | Intercepté | Majuscules gérées |
| « J'aimerais mourir » (apostrophe droite `'`) | Intercepté | |
| « je ne veux pas mourir » | Laissé passer | Correct : la négation casse la suite de mots |
| « J'ai envie de vivre pleinement » | Laissé passer | Corrigé : le motif trop large `envie de vivre` a été retiré |
| « Ce boulot va me tuer » | Intercepté | Faux positif attendu, assumé |
| « Je me suicide pas, t'inquiète » | Intercepté | Faux positif acceptable |
| « Je veux en finir » / « je vais en finir » | Intercepté | Corrigé : nouveau motif `(veux\|vais\|voudrais) en finir` |
| « j’aimerais mourir » (apostrophe de l'iPhone `’`) | Intercepté | Corrigé : apostrophes normalisées |
| « je veux  mourir » (deux espaces) | Intercepté | Corrigé : espaces normalisés |
| « Je veux en finir avec ce projet » | Intercepté | Nouveau faux positif, assumé (permissif) |
| « je veux mourrir » (faute) | Laissé passer | Limite connue |
| « je pense au suicide » | Laissé passer | Le mot seul « suicide » n'est pas un motif |
| « je vais me foutre en l'air » | Laissé passer | Registre familier absent |
| « tout le monde serait mieux sans moi » | Laissé passer | Seule la variante « le monde irait mieux sans moi » existe |
| « Mon ami veut se suicider » | Laissé passer | Motifs à la 1re personne seulement |

### Les trois corrections du 24/09/2026

1. **L'apostrophe de l'iPhone.** Le clavier iOS remplace `'` par `’`. Avant la
   correction, quatre motifs (`j'aimerais mourir`, `m'automutiler`,
   `l'existence`, `j'ai prepare…`) ne marchaient jamais sur iPhone. La
   normalisation ramène maintenant toutes les variantes d'apostrophe à `'`, et
   réduit les espaces multiples.
2. **`envie de vivre` retiré.** Il déclenchait l'alerte sur « j'ai envie de
   vivre ». `plus envie de vivre` reste et suffit.
3. **« Je veux en finir » couvert.** Nouveau motif
   `(veux|vais|voudrais) en finir`. Le filtre compte toujours 33 motifs.

**Test automatisé ajouté** : `RiskDetectionServiceTest` vérifie 14 formulations
de crise (dont les trois cas corrigés) qui doivent être interceptées, 5 messages
ordinaires qui doivent passer, et le cas du message vide. C'est un test unitaire
pur, sans Spring ni Ollama : il s'exécute en une fraction de seconde.

Si le jury demande comment tu as trouvé ces défauts : en rejouant le filtre sur
des phrases réelles, dont des phrases positives. C'est exactement le genre
d'autocritique qui se valorise à l'oral.

### Deux autres limites à connaître

- **Seul le dernier message est analysé**, pas l'historique. Un message coupé en
  deux (« envie de » puis « mourir ») passe. Le commentaire dans
  `CompanionService` parle de « l'historique récent », mais le code ne teste que
  `request.message()`. Ne dis pas que l'historique est filtré.
- **La réponse du modèle n'est pas filtrée en sortie.** Si le modèle, malgré son
  prompt, nomme un trouble ou donne un conseil médical, rien ne l'arrête. Le
  seul contrôle en sortie, c'est le prompt.

---

## 7. La confidentialité : ce qui est garanti, ce qui ne l'est pas

**Garanti par le code :**

- aucune base de données dans le service ;
- aucune ligne de log qui écrit le contenu des messages ;
- côté téléphone, aucune écriture sur disque (pas de SharedPreferences, pas de
  base locale) ; fermer l'écran efface tout ;
- le modèle est local : le texte ne sort pas vers un fournisseur tiers ;
- Zipkin ne reçoit que des métadonnées.

**Pas garanti, à dire honnêtement si on te pousse :**

- **Le transport.** En développement, les échanges passent en HTTP simple entre
  le téléphone, la passerelle et le service. En production, il faudrait TLS
  partout.
- **Ollama lui-même.** Il reçoit le texte en clair, c'est inévitable. Ses propres
  journaux ne contiennent pas le contenu par défaut, mais c'est un logiciel
  tiers à configurer (pas de mode debug en production).
- **La mémoire vive.** Pendant la conversation, le texte est dans la RAM du
  téléphone et du serveur. Aucune application ne peut l'éviter.
- **Le psychologue ne voit rien**, l'admin non plus : il n'y a rien à voir.
  C'est un argument fort, mais il a un revers : aucune supervision humaine n'est
  possible a posteriori. Choix assumé.

**Côté juridique (Sénégal) :** la loi n°2008-12 sur les données personnelles
classe les données de santé parmi les données sensibles, sous le contrôle de la
CDP. Ne pas stocker est la façon la plus simple de réduire l'exposition : pas de
durée de conservation à justifier, pas de base à sécuriser, pas de fuite
possible depuis le serveur.

---

## 8. Les choix de conception, et ce qu'on a écarté

| Question | Choix retenu | Alternative écartée | Pourquoi |
|---|---|---|---|
| Où mettre l'IA ? | Microservice dédié | Intégrer à user-service | Isolation : si Ollama rame ou tombe, réservations, paiements, messagerie continuent. Ressources (CPU, RAM) très différentes. |
| Quel fournisseur ? | Modèle open source local (Ollama) | API commerciale (OpenAI, etc.) | Données de santé mentale : rien ne sort. Pas de coût à l'appel, pas de clé à protéger. Moins performant, assumé. |
| Quel modèle ? | qwen2.5:3b | Mistral 7B (premier choix) | Mesure réelle : ~3 min par réponse avec Mistral sur M1 8 Go. Inutilisable. |
| Où garder la conversation ? | Côté client, en mémoire | Base serveur | Le serveur ne peut pas fuiter ce qu'il n'a pas. |
| Comment gérer la crise ? | Filtre regex avant le modèle | Confier au prompt seul ; ou un classifieur entraîné | Le prompt n'est pas une garantie. Un classifieur redevient probabiliste, et il faudrait des données annotées en français et en wolof qu'on n'a pas. |
| Qui peut l'utiliser ? | Tout utilisateur authentifié | Réservé au rôle PATIENT | Rien de sensible côté serveur ; un psy peut vouloir tester ce que voient ses patients. |

---

## 9. Questions probables du jury, avec les réponses qui tiennent

Rappel : le jury ne lit pas le code. Toutes les réponses doivent se dire sans
écran.

### A. Le principe

**1. « À quoi sert concrètement Xalaat ? Ce n'est pas un gadget ? »**
Il répond à un frein réel : ne pas savoir quoi dire à un psychologue et
abandonner avant de consulter. Il n'ajoute pas de soin, il réduit la marche
d'entrée. Et il ramène vers la réservation : il sert le cœur de PsyConnect au
lieu de le concurrencer.

**2. « Un chatbot dans une application de santé mentale, ce n'est pas
dangereux ? »**
Si, et c'est pour ça qu'il est encadré en trois points : un rôle strictement
limité à la préparation, des interdits explicites (diagnostic, conseil
médical), et un filtre déterministe qui retire le modèle de la boucle sur les
messages de crise.

**3. « Pourquoi un nom wolof ? »**
Appropriation locale de l'outil. Un compagnon qui porte un nom familier crée
moins de distance qu'un « assistant IA ». Le modèle sait expliquer son nom si on
le lui demande.

**4. « Pourquoi le tutoiement ? »**
Registre chaleureux, proche de l'oral, adapté à quelqu'un qui appréhende.
C'est un choix de ton, modifiable dans le prompt et le message fixe.

### B. L'IA elle-même

**5. « Pourquoi pas ChatGPT ? Ce serait bien meilleur. »**
Oui, plus performant. Mais on parle de confidences sur la santé mentale : les
envoyer à un fournisseur étranger pose un problème de confidentialité et de
conformité à la loi 2008-12. Le modèle local est moins bon, mais rien ne sort.
Pour de la préparation (rassurer, expliquer), un petit modèle suffit.

**6. « Qu'est-ce qu'un LLM, en deux phrases ? »**
Un modèle entraîné sur de grands volumes de texte à prédire le mot suivant. À
force, il produit des réponses cohérentes, mais il ne « sait » rien : il génère
du plausible, ce qui explique les hallucinations.

**7. « Vous avez entraîné le modèle ? »**
Non, et il ne faut pas laisser croire le contraire. Le modèle est utilisé tel
quel ; on le cadre par le prompt système. Pas de fine-tuning : pas de données
annotées, pas de GPU, et ce n'était pas nécessaire pour ce rôle.

**8. « Que veut dire 3b ? »**
3 milliards de paramètres. Petit modèle, choisi pour tenir sur un portable
8 Go.

**9. « Pourquoi avoir changé de modèle ? »**
Mesure : Mistral 7B mettait environ trois minutes par réponse sur la machine de
développement, l'application abandonnait à 15 secondes. Deux corrections : un
délai dédié de 90 secondes pour Xalaat, et un modèle plus léger. Le modèle se
change par variable d'environnement, sans toucher au code.

**10. « Et si le modèle hallucine ? »**
Hors crise, c'est possible : c'est la limite de tout LLM. Le risque est réduit
par le rôle très étroit (pas de diagnostic, pas de traitement). Point
important : les numéros d'urgence ne viennent **jamais** du modèle, ils sont
dans le texte fixe. Le modèle pourrait en inventer dans une réponse normale ;
c'est une amélioration possible de lui fournir la liste exacte dans son prompt.

**11. « Qu'est-ce que la température ? Pourquoi 0,6 ? »**
Le degré de hasard dans le choix des mots. 0,6 : ton naturel sans incohérence.
La sécurité ne repose pas dessus.

**12. « Qu'est-ce qu'un prompt système ? Peut-on le contourner ? »**
Les instructions données au modèle avant la conversation. Oui, on peut parfois
le contourner en insistant ou par injection de consignes : c'est justement pour
ça que le cas critique ne dépend pas de lui.

### C. Le garde-fou

**13. « Des mots-clés, c'est rudimentaire. »**
Oui, et c'est voulu. La simplicité est ce qui garantit le comportement. Un
classifieur serait plus fin mais probabiliste, donc faillible sur le cas même
qu'on veut sécuriser, et il demanderait des données annotées qu'on n'a pas. Le
filtre est la garantie plancher ; le prompt rattrape une partie de ce qu'il
laisse passer.

**14. « Il détecte les personnes à risque ? »**
Non. Il intercepte **certaines formulations explicites** en français. Ne jamais
dire l'inverse.

**15. « Combien de faux positifs, de faux négatifs ? »**
Pas de mesure statistique : il faudrait un corpus annoté. Il y a des tests
manuels et un test automatisé sur une vingtaine de phrases, crise et ordinaires.
Ces tests ont d'ailleurs révélé trois défauts, corrigés. Les faux négatifs
connus sont documentés : wolof, argot, fautes, formulations indirectes, message
coupé en deux. Réponse honnête, et c'est une perspective claire.

**16. « Et en wolof ? »**
Pas couvert par le filtre, c'est la première évolution. Le modèle garde la
consigne d'orienter vers une aide professionnelle : couverture dégradée, pas
nulle. Ajouter des motifs wolof demande de les construire avec des locuteurs et
idéalement des professionnels, pas de les inventer.

**17. « Pourquoi l'IA ne répond-elle pas elle-même au message de crise, avec
plus d'empathie ? »**
Parce qu'une réponse générée peut varier, se tromper, minimiser. Le texte fixe a
été écrit une fois, relu, avec des numéros vérifiés. Sur ce cas, la constance
vaut mieux que la souplesse.

**18. « Pourquoi dire “appelle plutôt que réserve” dans le message ? »**
Une réservation n'est pas immédiate : en urgence, orienter vers la réservation
serait une erreur. Le message dit la bonne priorité.

**19. « Qui prévient-on quand le filtre se déclenche ? »**
Personne, et c'est cohérent avec la confidentialité : aucun contenu n'est
stocké ni transmis. On oriente, on ne signale pas. Alerter un tiers poserait des
questions de consentement et de secret. Une perspective possible serait de
proposer à l'utilisateur, s'il le souhaite, de joindre un psychologue d'astreinte.

### D. Confidentialité et éthique

**20. « Comment garantissez-vous la confidentialité ? »**
Trois niveaux : rien n'est stocké côté serveur, rien n'est journalisé, rien
n'est écrit sur le téléphone. Et le modèle est local. Le serveur ne peut pas
fuiter ce qu'il n'a jamais gardé.

**21. « Si rien n'est stocké, comment le modèle se souvient-il de la
conversation ? »**
Le téléphone renvoie tout l'historique à chaque message. Le serveur traite puis
oublie.

**22. « Le client renvoie l'historique : il pourrait le falsifier ? »**
Oui : un utilisateur technique peut inventer des tours « assistant ». Mais il ne
peut tromper que sa propre conversation, il n'y a aucune donnée d'autrui en jeu.
Le filtre, lui, s'applique toujours au message courant. Risque accepté.

**23. « Les échanges sont chiffrés ? »**
Pas en développement (HTTP local). En production, TLS obligatoire sur toute la
chaîne. Pas de chiffrement au repos à prévoir : il n'y a rien au repos.

**24. « Et votre responsabilité si quelqu'un se fait du mal ? »**
Calme et factuel : Xalaat ne se présente jamais comme un soignant, le rappelle,
et sur les formulations de crise, renvoie systématiquement vers les urgences et
les psychologues de la plateforme. C'est un outil d'orientation. Un vrai
déploiement demanderait une validation par des professionnels de santé mentale
et un avis de la CDP.

**25. « Des professionnels ont validé le prompt et le message ? »**
Répondre selon la réalité. Si non : « Pas encore formellement. Les numéros ont
été vérifiés sur la source officielle du ministère ; la validation clinique du
texte est une étape indispensable avant mise en production. »

### E. Technique et exploitation

**26. « Pourquoi un microservice à part ? »**
Isolation de la panne et des ressources : l'inférence consomme beaucoup de
mémoire et de CPU, et peut être lente. Si elle tombe, le reste de l'application
continue. Et le cycle de vie est différent : on change de modèle sans
redéployer le reste.

**27. « Que se passe-t-il si Ollama est arrêté ? »**
L'appel au modèle échoue, le service renvoie une erreur, l'écran affiche
« Xalaat n'a pas pu répondre, réessaie dans un instant ». Le reste de
PsyConnect n'est pas touché. À noter : le garde-fou, lui, fonctionne même
sans Ollama, puisqu'il passe avant.

**28. « Combien d'utilisateurs simultanés ? »**
Peu, sur la machine actuelle : un seul modèle sur un portable traite les
demandes quasiment une par une. Pour monter en charge : un serveur avec GPU,
plusieurs instances d'Ollama, et une file d'attente. Il faudrait aussi une
limitation de fréquence par utilisateur, absente aujourd'hui.

**29. « Pourquoi 90 secondes de délai ? Ce n'est pas trop long ? »**
C'est une borne haute, pas le temps normal. Elle couvre le pire cas : le
modèle déchargé de la mémoire après inactivité et rechargé au premier message.
Amélioration : afficher la réponse mot à mot (streaming), comme les assistants
grand public, pour que l'attente se voie moins.

**30. « Comment est protégé l'accès ? »**
Même jeton JWT que le reste de l'application, vérifié par le service lui-même.
Pas de jeton valide, pas d'accès au modèle.

**31. « Y a-t-il une limite de taille ? »**
Le message est limité à 4000 caractères. L'historique n'est pas borné en nombre
de tours : une très longue conversation dépasserait la fenêtre de contexte du
modèle, qui oublierait le début. Borner l'historique aux derniers échanges est
une correction simple.

### F. Tests et perspectives

**32. « Comment avez-vous testé Xalaat ? »**
Deux niveaux. Manuel : conversations normales et messages de crise, bien
interceptés avant le modèle. Automatisé : un test unitaire du filtre, qui
vérifie une liste de phrases de crise et de phrases ordinaires. Le filtre est
une fonction pure (texte en entrée, vrai/faux en sortie), donc facile à tester
sans lancer le modèle. Les réponses du modèle, elles, ne sont pas testées
automatiquement : un LLM ne donne pas deux fois la même réponse.

**33. « Comment évalueriez-vous la qualité des réponses du modèle ? »**
Un jeu de questions types (appréhension, déroulé d'une séance, demande de
diagnostic pour vérifier le refus), relues par un professionnel avec une grille
simple : respect du rôle, absence de diagnostic, ton. Sur un LLM, l'évaluation
humaine reste la référence.

**34. « Quelles évolutions ? »**
Dans l'ordre : motifs en wolof construits avec des locuteurs ; bornage de l'historique ; streaming des réponses ;
filtre sur la réponse du modèle (vérifier qu'elle ne contient ni diagnostic ni
numéro inventé) ; à plus long terme, un classifieur **en complément** du filtre,
jamais à sa place.

---

## 10. Vocabulaire à maîtriser

- **LLM** : grand modèle de langage, prédit le mot suivant.
- **Inférence** : faire tourner un modèle déjà entraîné pour produire une
  réponse (par opposition à l'entraînement).
- **Inférence locale** : sur sa propre machine, pas chez un fournisseur.
- **Paramètres** : les poids du modèle ; « 3b » = 3 milliards.
- **Jeton (token)** : morceau de mot que le modèle traite. La vitesse se mesure
  en jetons par seconde.
- **Fenêtre de contexte** : quantité de texte que le modèle peut lire en une
  fois.
- **Prompt système** : consignes données avant la conversation.
- **Température** : degré de hasard de la génération.
- **Hallucination** : réponse plausible mais fausse.
- **Injection de prompt / jailbreak** : faire dévier le modèle de ses consignes.
- **Garde-fou (guardrail)** : contrôle placé autour du modèle.
- **Déterministe / probabiliste** : même entrée → même sortie toujours / pas
  forcément.
- **Expression régulière** : motif de recherche dans un texte.
- **Normalisation** : mettre le texte sous une forme standard avant comparaison.
- **Faux positif / faux négatif** : alerte à tort / alerte manquée.
- **Défense en profondeur** : plusieurs barrières indépendantes.
- **Sans état (stateless)** : le serveur ne garde rien entre deux requêtes.
- **Souveraineté des données** : les données restent sous le contrôle de celui
  qui les produit ou les héberge.

---

## 11. Phrases à ne jamais dire

| À éviter | À dire |
|---|---|
| « Xalaat détecte les personnes à risque. » | « Xalaat intercepte certaines formulations explicites. » |
| « L'IA ne voit jamais les messages de crise. » | « Le modèle ne traite jamais un message de crise : la réponse est un texte fixe. » |
| « On a entraîné une IA. » | « On utilise un modèle open source existant, cadré par un prompt système. » |
| « Les conversations sont chiffrées. » | « Les conversations ne sont pas stockées. » |
| « C'est un service de machine learning. » | « C'est un service d'IA générative locale avec un filtre à règles. » |
| « L'historique est analysé par le filtre. » | « Le filtre analyse chaque nouveau message. » |
| « Ça remplace le psychologue en attendant. » | « Ça prépare à la première séance. » |

---

## 12. Check-list avant le jour J

- [x] Corriger les trois points de la partie 6 (fait le 24/09/2026).
- [ ] Lancer `./gradlew test` dans `ai-companion-service` et reconstruire
      l'image Docker du service.
- [ ] Dans le mémoire et les slides, citer `qwen2.5:3b` (le README du service
      parle encore de Mistral par défaut).
- [ ] Capture de la bulle dorée « Aide immédiate » dans les slides.
- [ ] Si démo live : Ollama lancé et modèle déjà chargé (envoyer un premier
      message 5 minutes avant pour éviter le rechargement).
- [ ] Savoir réciter les numéros : 1515, 800 00 50 50, 17, 18.
- [ ] Relire le tableau de la partie 6 : c'est là que le jury peut te piéger en
      tapant lui-même.
