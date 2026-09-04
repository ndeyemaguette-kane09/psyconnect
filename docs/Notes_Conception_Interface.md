# PsyConnect — notes de conception de l'interface

*Application mobile Flutter — justification des choix d'interface et des contraintes techniques rencontrées.*

Ce document rassemble les décisions prises sur la couche présentation de l'application. Il est
volontairement tenu à l'écart du code : le code dit **ce que** l'interface fait, ce document dit
**pourquoi** elle le fait ainsi. Chaque section renvoie aux fichiers concernés sous
`frontend/psyconnect/lib/`.

---

## 1. Principes retenus

Trois règles ont guidé l'ensemble du travail sur l'interface.

**Une seule source pour chaque valeur visuelle.** Les rayons de bordure, les espacements, les
ombres et les durées d'animation sont déclarés une fois dans `core/theme/app_tokens.dart` et
consommés partout ailleurs. Avant cela, cinq rayons différents (12, 14, 16, 20, 30) se croisaient
d'un écran à l'autre — ce qui donne visuellement une application assemblée pièce par pièce plutôt
qu'un produit conçu d'un seul tenant.

**Le thème avant l'écran.** Une carte, un champ de formulaire ou un bouton hérite de son apparence
du `ThemeData` global (`core/theme/app_theme.dart`), pas d'une décoration recopiée dans chaque
écran. Conséquence pratique : un changement de charte se fait à un seul endroit, et un écran écrit
plus tard ressemble automatiquement aux précédents.

**Le contenu commande la hiérarchie.** Sur un outil d'accompagnement psychologique, ce qui doit
être atteint sans réfléchir, c'est l'aide immédiate — pas le solde du portefeuille. L'ordre des
blocs de l'écran d'accueil découle de ce raisonnement, pas d'un équilibre graphique.

---

## 2. Le système de design

### 2.1 Palette — `core/theme/app_colors.dart`

La base est extraite des maquettes (`docs/PsyConnect Maquettes v2.html`, variables CSS `:root`),
puis enrichie d'une échelle de neutres et de couleurs sémantiques.

| Ajout | Rôle |
|---|---|
| `surfaceAlt` | Fond légèrement en retrait, pour un bloc posé sur une carte blanche |
| `border`, `borderStrong` | Filets de séparation : assez visibles pour structurer, assez discrets pour ne pas alourdir |
| `success` / `warning` / `info` / `danger` (+ variantes `*Bg`) | Couleurs sémantiques, pour cesser de détourner `teal` et `gold` en messages d'état |
| `emergency` | Rouge du bouton SOS, volontairement plus saturé que `danger` : c'est le point le plus chaud de l'écran, et il doit rester unique |
| `scrim` | Voile posé sur un dégradé pour garantir le contraste d'un texte blanc |

**Règle de maintenance :** on n'enlève jamais une constante de ce fichier. Une centaine d'écrans en
dépendent, et une suppression ne se voit qu'à la compilation, écran par écran. On ajoute.

`errorBg` est conservé bien qu'identique à `dangerBg`, pour la même raison.

### 2.2 Jetons — `core/theme/app_tokens.dart`

- **`AppRadius`** — `sm 12` (pastilles, badges, champs compacts), `md 16` (valeur par défaut :
  cartes, champs, boutons), `lg 22` (hero, feuilles modales), `pill 999`.
- **`AppSpacing`** — échelle en base 4, plus `gutter 20` comme marge horizontale standard.
- **`AppShadows`** — ombres à deux couches. Une seule ombre large paraît sale ; un contact net très
  proche combiné à une diffusion large et très transparente donne la profondeur d'un produit fini.
  La teinte est verte (`#0B3B34`) plutôt que noire, pour rester dans la charte. `glow(color)` sert à
  souligner l'appartenance d'un bloc à une couleur (bouton principal, bouton d'urgence).
- **`AppMotion`** — durées et courbes centralisées, pour que toutes les transitions de l'application
  aient le même tempo.
- **`AppDecorations`** — `card`, `tinted`, `hero` : trois `BoxDecoration` prêts à l'emploi, pour ne
  pas recopier la même construction dans chaque écran.

### 2.3 Thème — `core/theme/app_theme.dart`

Playfair Display porte les titres (registre humain, éditorial), DM Sans tout le reste (lisible et
neutre sur les longues listes).

Points notables :

- **Échelle typographique complète** plutôt que cinq styles. Sans cela, un écran qui utilise un
  style non redéfini retombe sur les valeurs Material par défaut — ni la bonne police, ni la bonne
  couleur.
- **`CardTheme.elevation` passé de 0 à 3.** C'est ce seul changement qui donne du relief à toutes
  les listes de l'application. `margin` et `clipBehavior` restent aux valeurs Material par défaut
  pour ne rien décaler dans les écrans existants.
- **Bordure visible au repos sur les champs de formulaire.** Un champ « invisible » sur fond blanc
  est le premier réflexe qui fait amateur.
- **`OutlinedButtonThemeData.minimumSize` impose une largeur infinie.** Un `OutlinedButton` nu placé
  dans un `Row` doit donc surcharger `minimumSize` (cas rencontré dans `psychologist_card.dart`).
- **Pas de `pageTransitionsTheme`.** Voir section 7.1.

### 2.4 Kit de composants — `core/widgets/app_ui.dart`

Objectif : que deux écrans écrits à deux moments différents produisent exactement la même carte, le
même titre de section et le même état vide. Aucun de ces widgets ne connaît les services — ils sont
purement visuels.

| Widget | Usage |
|---|---|
| `AppCard` | Carte blanche standard, cliquable ou non |
| `AppNoticeCard` | Encart d'information teinté (astuce, avertissement, rappel) |
| `AppHero` | Grand bloc coloré en tête d'écran |
| `SectionHeader` | Titre de section avec action facultative à droite |
| `AppEmptyState` / `AppErrorState` | États vide et erreur réseau, avec bouton « Réessayer » |
| `AppPill` | Pastille d'étiquette (spécialité, statut, tarif) |
| `AppIconBadge` | Pastille d'icône colorée, repère en tête de ligne |
| `AppAvatar` | Avatar à initiales avec anneau — bien plus identifiable qu'une icône « personne » répétée sur toute une liste |
| `StatTile` | Tuile de statistique pour les tableaux de bord |
| `QuickAction` | Action rapide en grille |
| `FadeInUp` | Entrée en fondu + montée, décalée par index |

`AppHero` accepte un paramètre `color` optionnel : le passer donne un aplat uni, l'omettre retombe
sur le dégradé. **L'aplat est préféré dès qu'il y a du texte posé dessus** — un dégradé fait varier
le contraste d'un bout à l'autre du bloc, et c'est une signature visuelle très répandue dont on se
passe.

`FadeInUp` est réservé aux blocs principaux d'un écran. Utilisée partout, l'animation d'entrée
devient un ralentissement perçu.

---

## 3. Parcours patient

### 3.1 Écran d'accueil — `features/patient/screens/patient_home_screen.dart`

L'ordre des blocs est le résultat d'un arbitrage explicite :

1. **Bandeau d'identification** (`_HomeHero`) — qui est connecté, plus les deux accès aux messages
   du système (annonces, notifications). Aplat uni, pas de dégradé.
2. **Bouton d'urgence** (`_SosButton`) — **premier élément du corps de page**, volontairement. C'est
   ce qu'une personne en détresse doit trouver sans chercher.
3. **Actions rapides** — Journal et Xalaat.
4. **Solde** (`_WalletRow`) — une ligne sobre, pas une carte de couleur. Sur une application
   d'accompagnement psychologique, l'argent ne doit pas être la première information de l'écran
   d'accueil. Il reste accessible en un tap.
5. **Contenu** — profil incomplet, prochain rendez-vous, recommandations.

**Choix d'icônes.** Journal : `Icons.book_outlined`, un carnet fermé — l'objet réel, pas une
métaphore. Xalaat : `Icons.question_answer_outlined`, deux bulles de dialogue — ce que l'assistant
est réellement, une conversation. Surtout pas `Icons.auto_awesome` (l'étincelle devenue le symbole
du « contenu généré par IA »), et pas la bulle simple de l'onglet Messages, pour ne pas confondre
avec la messagerie du psychologue.

**Recherche.** L'écran comportait à la fois une barre de recherche et un onglet Chercher dans la
barre de navigation. La barre a été retirée : deux points d'entrée pour une même destination
partagent l'attention sans rien apporter.

**Recommandations.** Elles proviennent du `ml-service`. En cas d'indisponibilité, repli sur un tri
par note. Les recommandations post-séance non cochées apparaissent comme des cases à cocher.

**Chargements en échec silencieux, assumés :** le badge de la cloche, la carte de solde et le
bandeau « Complétez votre profil » ne bloquent pas l'affichage. Si leur appel échoue, l'élément
n'apparaît simplement pas — l'accueil reste utilisable.

**Compte des annonces non vues.** Le nombre affiché sur le mégaphone compte les diffusions postées
après le dernier horodatage de lecture, persisté via `flutter_secure_storage` pour survivre aux
redémarrages. À l'ouverture, on marque « tout vu », puis on revérifie au retour si de nouvelles sont
arrivées pendant la consultation.

### 3.2 Carte de psychologue — `features/patient/widgets/psychologist_card.dart`

La carte comportait auparavant deux boutons — « Voir profil » et « Réserver » — qui menaient
**exactement au même écran**, en plus de la carte elle-même déjà cliquable : trois zones tactiles
pour une seule destination. Il n'en reste qu'un geste, la carte entière.

Le tarif est remonté à droite du nom. Aligné d'une carte à l'autre, il forme une colonne que l'œil
peut comparer sans lire le reste. Quand il est absent, une pastille « Tarif non précisé » prend sa
place — l'alignement de la colonne est préservé.

**Pas de badge « Nouveau sur PsyConnect »** quand le praticien n'a pas encore de note. Ce badge ne
dit rien d'utile au patient et met inutilement en avant l'absence d'avis. La ligne de notation
disparaît simplement.

**Pas de badge de disponibilité** non plus : afficher « Disponible » sur une carte de liste laisse
croire à une disponibilité immédiate, que rien ne garantit.

### 3.3 Fiche du praticien — `features/patient/screens/psychologist_profile_screen.dart`

**Cet écran est informatif uniquement.** Le formulaire de réservation vivait auparavant au bas de la
même page. Il est maintenant derrière le bouton « Réserver une séance ». Le raisonnement : la fiche
sert à **décider** (est-ce le bon praticien pour ce que je traverse ?), l'écran suivant sert à
**réserver**. Un patient qui cherche un sexologue ne se retrouve plus à sélectionner un créneau chez
un spécialiste de l'anxiété sans s'en être rendu compte.

Quatre champs présents en base mais que l'interface patient ignorait ont été remontés :

| Champ | Affichage | Justification |
|---|---|---|
| `offersFreeSessions` | Encart « Consultations solidaires » | L'information la plus décisive de la page pour un patient qui ne peut pas payer |
| `profileVerified` / `hasLicenseDocument` | Ligne « Profil vérifié · diplôme contrôlé » | Boucle la chaîne avec la validation administrateur : le justificatif a été transmis et contrôlé avant que ce profil soit visible |
| `availableForEmergency` | Pastille « Joignable en urgence », en vert | Statut vivant. En vert et non en rouge : c'est une bonne nouvelle, le rouge reste réservé au bouton d'urgence |
| `createdAt` | « Sur PsyConnect depuis *mois année* » | Ancienneté, signal de sérieux |

La spécialité est mise en avant sous le nom : c'est l'information qui décide si ce praticien
correspond au besoin.

Une **barre fixe en bas** conserve le tarif visible et rend le bouton de réservation atteignable
sans avoir à faire défiler toute la fiche. Le bouton est désactivé quand le praticien n'est pas
disponible.

Le profil et les disponibilités sont chargés **en parallèle** puis transmis à l'écran de
réservation, qui n'a donc aucun appel réseau à refaire.

### 3.4 Réservation — `features/patient/screens/booking_screen.dart`

Écran nouveau, issu de l'extraction décrite ci-dessus. Il reçoit le profil et les disponibilités en
paramètres, et renvoie `pop(true)` quand la demande est partie.

**Calcul des créneaux :**

- Aucune disponibilité configurée par le praticien → plage générique 8 h – 22 h, avec une
  granularité plus fine en soirée.
- Disponibilités configurées mais pas pour le jour choisi → aucun créneau, message explicite.
- Plusieurs plages le même jour (matin + après-midi) → fusionnées.
- Jour du jour → les créneaux déjà passés sont retirés.

Les jours sans disponibilité sont grisés dans le sélecteur mais **restent cliquables** : le message
qui suit explique pourquoi il n'y a rien, ce qui vaut mieux qu'une case morte sans explication.

**Le rendez-vous reste en attente après l'envoi.** Le paiement n'intervient qu'une fois le
psychologue a confirmé.

---

### 3.5 Rendez-vous du patient — `features/patient/screens/appointments_tab.dart`

Écran refondu le 02/09/2026 pour reprendre le patron déjà en place côté psychologue
(`features/psychologist/screens/agenda_tab.dart`) : une carte épurée et cliquable ouvre une fiche
détail en feuille modale (`DraggableScrollableSheet`), plutôt que d'empiler tous les boutons
possibles sur la carte.

**Ce qui reste sur la carte :** avatar, nom du psychologue, date, statut, chevron — la même
composition que côté psychologue. Le bouton « Rejoindre l'appel » y reste aussi, à l'identique du
comportement psychologue : c'est une action sensible au temps, elle doit être visible sans ouvrir
quoi que ce soit.

**Ce qui part dans la fiche détail :** payer, reporter, annuler, laisser un avis, supprimer. La
fiche reprend l'ordre du psychologue (date, horaire, type, statut) puis ajoute une section
Paiement — montant et moyen si payé, bouton « Payer » sinon — suivie des actions de gestion. La
suppression est isolée en bas, séparée par un filet, pour ne pas la placer au même niveau que les
actions courantes.

**Mise à jour du 02/09/2026 :** magui a demandé le calendrier semaine complet, identique à celui du
psychologue — la première version de cette refonte l'avait volontairement omis en pariant qu'un
patient suivant peu de rendez-vous n'en aurait pas l'usage, mais dans les faits l'attente était de
retrouver le même repère visuel des deux côtés de l'application. `_WeekStrip`, `_DayCell` et
`_DayHeading` sont donc repris tels quels depuis `agenda_tab.dart` (classes privées, dupliquées
faute de pouvoir les importer d'un autre fichier). Le premier chip de la rangée de filtres devient
« Semaine » (au lieu de « Tous ») et pilote désormais l'affichage jour par jour ; les autres chips
gardent leur usage de filtre à plat, toutes dates confondues. Le tri de la liste passe de « création
la plus récente d'abord » à « horaire le plus proche d'abord », plus cohérent avec une lecture en
calendrier.

---

## 4. Notifications

### 4.1 Liste — `features/patient/screens/notifications_screen.dart`

Écran partagé entre patient et psychologue ; `userId` correspond au `PatientProfile.id` ou au
`PsychologistProfile.id` selon l'appelant.

**Parti pris central : la couleur encode l'état, pas le type.** Une notification non lue est teintée
(`tealSoft`) et son icône passe en teal ; tout le reste est gris. Le type se lit dans le glyphe de
l'icône et dans les filtres — il n'a pas besoin d'une couleur à lui. C'est ce qui évite la liste
arc-en-ciel où chaque ligne réclame l'attention pour une raison différente.

La teinte de fond est très légère : suffisante pour repérer une non-lue au premier coup d'œil, trop
discrète pour transformer la liste en damier.

Le filet de séparation est aligné **sous le texte, pas sous l'icône** : c'est ce qui fait lire la
colonne comme une liste et non comme une succession de blocs.

Les filtres sont affichés dès qu'il y a des notifications, quels que soient les types présents :
patient et psychologue voient toujours les mêmes catégories. Le filtre « Questionnaires » couvre à
la fois `questionnaire` et `questionnaireResult` — le patient (questionnaires à remplir) et le
psychologue (résultats) partagent ainsi la même catégorie, et `questionnaireResult` est exclu de la
liste des chips pour éviter le doublon.

Le tap sur une notification déclenche son marquage comme lue ; **l'échec est silencieux**,
l'utilisateur peut retaper pour réessayer.

**Mise à jour du 02/09/2026 — toutes les notifications sont désormais cliquables.**
Auparavant, seuls les types `questionnaire` (côté patient) et `announcement` ouvraient un écran ; le
reste ne faisait que marquer la notification comme lue, sans chevron. `_destinationFor` couvre
maintenant les 8 types, en tenant compte du rôle (`_role`) puisque l'écran est partagé :

- `appointment`, `reminder`, `session` → `AppointmentsTab` (patient) ou `AgendaTab` (psychologue),
  chacun enveloppé dans un `Scaffold` + `AppBar` minimal car ce sont des corps d'onglet sans
  Scaffold propre (pensés pour vivre dans le shell).
- `payment` → `WalletScreen` (patient) ou `PsyWalletScreen` (psychologue), en leur passant
  `widget.userId` : c'est le même id que celui déjà utilisé pour charger les notifications, donc
  pas d'appel réseau supplémentaire pour le récupérer.
- `questionnaireResult` → `PatientsTab` côté psychologue. Le modèle `AppNotification` ne porte pas
  d'identifiant de cible (choix déjà en place, cf. plus haut), donc impossible d'ouvrir directement
  la fiche du patient concerné (`PatientQuestionnairesScreen` exige un `patientId`) ; la liste des
  patients est le meilleur point d'atterrissage sans étendre le modèle.
- `system` : pas d'écran dédié — le contenu est déjà entièrement visible dans la ligne (titre +
  message), donc plutôt que de ne rien faire, le tap ouvre une **feuille modale** qui réaffiche ce
  contenu en plus grand. Ce fallback s'applique aussi, par construction, à toute combinaison
  type/rôle qui ne correspond à aucun écran (ex. `questionnaireResult` reçu côté patient, qui ne
  devrait normalement pas arriver).

Le chevron n'est donc plus conditionnel (`actionable` a été supprimé) : chaque ligne est cliquable,
soit vers un écran, soit vers la feuille de détail.

### 4.2 Bannière temps réel — `patient_shell.dart` et `psychologist_shell.dart`

- Interrogation toutes les **10 secondes**.
- `WidgetsBindingObserver` + `didChangeAppLifecycleState` : au retour de l'application au premier
  plan, rafraîchissement **immédiat** plutôt que d'attendre le prochain battement du minuteur.
- `HapticFeedback.mediumImpact()` : une vibration courte, pour que la notification se remarque même
  quand l'écran n'est pas regardé au moment précis où elle arrive.
- Aplat `tealDark` plutôt qu'une carte blanche discrète : une notification qui arrive doit se voir
  sans ambiguïté, quel que soit l'écran affiché derrière.
- Fermeture automatique au bout de **6 secondes** — assez pour lire deux lignes et taper dessus.

**Garde d'identité sur la fermeture différée.** Le minuteur ne referme que *cette* bannière : si une
autre est arrivée entre-temps, elle conserve son propre délai.

```dart
final shown = _notifPopupEntry;
Future.delayed(const Duration(seconds: 6), () {
  if (mounted && identical(_notifPopupEntry, shown)) _dismissNotifPopup();
});
```

Sans le `identical`, la deuxième bannière serait fermée par le minuteur de la première.

Dans la barre de navigation, une pastille animée derrière l'icône marque l'onglet actif : repère de
position bien plus lisible qu'un simple changement de couleur du glyphe.

---

## 5. Paiement et solde

### 5.1 Architecture réelle

Point important pour la soutenance, car il n'est pas évident à la lecture des écrans :

- Un **rendez-vous est toujours réglé depuis le solde PsyConnect**. Jamais directement auprès d'un
  opérateur.
- Les **opérateurs (Wave, Orange Money, carte) ne servent qu'à recharger ce solde**, et ils sont
  **simulés** : aucun débit réel n'a lieu, les trois valeurs `SIMULATED_*` marquent un dépôt ou un
  retrait sur le solde.
- Le **solde, lui, est réellement persisté en base**. C'est lui qui règle les rendez-vous et qui
  reçoit les remboursements.

En pratique, un paiement créé est toujours `completed` puisqu'il est simulé ; les autres valeurs de
l'énumération existent pour que le modèle soit complet.

### 5.2 Écran de paiement — `features/payment/screens/payment_screen.dart`

Le montant est présenté en hero, le solde figure **comme moyen de paiement sélectionné**
(`_WalletMethodTile`) plutôt que comme une simple information de contexte : c'est effectivement par
là que passe la transaction.

Si le solde est insuffisant, un bandeau `_TopUpNotice` affiche le **montant exact qui manque** et
renvoie vers la recharge. Le backend refuse de son côté.

`pop(true)` si le paiement est passé, `pop(false)` si le patient choisit « payer plus tard » — le
rendez-vous reste alors en attente.

**Protection contre le double clic.** `setState` ne désactive le bouton qu'au frame suivant ; l'état
`_paying` est donc re-testé en tête de méthode. Le backend protège également.

### 5.3 Solde — `features/payment/screens/wallet_screen.dart`

Les logos des opérateurs sont chargés depuis `assets/images/wave.png` et
`assets/images/orange_money.png` (le dossier est déjà déclaré dans `pubspec.yaml`). `_BrandMark`
utilise `errorBuilder` : **si un fichier manque, on retombe automatiquement sur un carré aux
couleurs de l'opérateur avec ses initiales**. L'application ne casse pas et reste présentable — un
fichier absent n'affiche jamais d'écran rouge.

Les deux logos fournis étant des vignettes carrées complètes (Wave sur fond cyan, Orange Money sur
fond blanc), ils sont affichés bord à bord dans un carré arrondi, comme une icône d'application,
plutôt que rétrécis à l'intérieur d'une tuile.

La feuille de montant (`_WalletAmountSheet`) est partagée entre « Recharger » et « Retirer » ;
`maxAmount` plafonne le retrait au solde disponible et reste nul pour une recharge. Quatre montants
sont proposés en un tap (2 000 / 5 000 / 10 000 / 25 000), uniquement pour la recharge.

**Pas de champ « numéro de téléphone » :** le backend simulé n'attend que le montant et le moyen de
paiement. Un champ qui n'est envoyé nulle part est un mensonge d'interface.

### 5.4 Formatage — `features/payment/models/payment_models.dart`

`formatAmount(num)` formate un montant en F CFA à la française : séparateur de milliers en **espace
insécable** (` `, pour qu'un montant ne soit jamais coupé en fin de ligne) et deux décimales
seulement quand il y en a. Partagé par l'écran de paiement, le solde et le relevé des mouvements —
un seul formatage pour toute l'application.

---

## 6. Journal — `features/journal/screens/journal_screen.dart`

L'échelle d'humeur était une rangée de cinq émojis. Elle est maintenant une **échelle en 5 points
façon échelle clinique**, dans le même registre que les questionnaires PHQ-9 et GAD-7 déjà présents
dans l'application.

Deux partis pris :

- **Pas d'emoji.** Un visage triste dessiné en jaune dans une application de suivi psychologique
  infantilise le propos, et ne se cite pas dans un mémoire. Des repères chiffrés avec leurs ancrages
  textuels, si.
- **Une seule couleur, quel que soit le niveau.** Colorer le « 1 » en rouge reviendrait à signaler
  une mauvaise journée comme une alerte ou une faute. Le teal marque la sélection, pas un jugement.

Détails d'ergonomie :

- **Ancrages textuels** aux extrémités (« Très difficile » / « Très bien ») : sans eux, « 1 » et
  « 5 » ne veulent rien dire.
- **Ligne de libellé à hauteur réservée** : la feuille ne bouge pas au moment de la sélection.
- **Zone tactile de 52 px**, indépendante du diamètre dessiné.
- **Retaper le point sélectionné efface la note** : l'humeur est facultative, il faut pouvoir
  revenir en arrière.
- Sur les cartes de la liste, `_MoodGauge` reprend la note en **cinq barres remplies jusqu'au
  niveau** — se lit d'un coup d'œil en faisant défiler.

`moodRating` reste un entier côté backend ; tout ce qui précède n'est que de la présentation.

Les états d'erreur utilisent une `ListView` plutôt qu'un `Center`, afin de **conserver le
tirer-pour-rafraîchir**.

---

## 7. Contraintes techniques Flutter rencontrées

Cette section documente des pièges réels, rencontrés en cours de développement. Ils sont
reproductibles et méritent d'être connus.

### 7.1 `CupertinoPageTransitionsBuilder` — erreur de compilation

Une version du thème déclarait un `pageTransitionsTheme` avec un `CupertinoPageTransitionsBuilder`
explicite. **Ce symbole n'existe pas dans le SDK Flutter utilisé** et cassait la compilation :

```
Error: Method not found: 'CupertinoPageTransitionsBuilder'
```

Le bloc a été supprimé entièrement. Les valeurs par défaut de Flutter donnent déjà la transition
Cupertino sur iOS (donc le retour par glissement, indispensable sur iPhone) et la transition
Material ailleurs. Le bloc n'apportait rien.

### 7.2 `PsyAvailabilitySlot` — type introuvable après extraction

Lors de l'extraction de l'écran de réservation :

```
Error: Type 'PsyAvailabilitySlot' not found
```

**Cause :** `PsyAvailabilitySlot` est déclaré à l'intérieur de
`lib/features/patient/services/psychologist_service.dart`, et non dans un fichier de modèles comme
la convention le laisserait supposer. `booking_screen.dart` importe donc ce fichier de service
uniquement pour le type.

### 7.3 `CrossAxisAlignment.stretch` dans une `ListView`

Un `Row` avec `crossAxisAlignment: CrossAxisAlignment.stretch` placé dans une `ListView` reçoit une
**contrainte verticale infinie** et fait échouer la mise en page. Le `Row` doit être enveloppé dans
un `IntrinsicHeight`, qui résout le problème et aligne au passage les enfants sur la même hauteur.

Quatre emplacements sont concernés : les actions rapides de l'accueil patient, les indicateurs du
tableau de bord psychologue, et le bloc de statistiques de la fiche praticien (où c'est aussi ce qui
fait courir les séparateurs verticaux sur toute la hauteur de la rangée).

### 7.4 `FloatingActionButton.extended` écrasé par le thème

Le thème impose `shape: CircleBorder()` à tous les boutons flottants. Un
`FloatingActionButton.extended` placé sous ce thème voit sa forme écrasée et son texte devient
disproportionné. Le bouton du journal est donc un `FloatingActionButton` rond simple, sans libellé.

### 7.5 `setState` depuis `initState`

Le calcul des créneaux devait tourner avant le premier build. La solution est de séparer :

```dart
_Slots _slotsFor(DateTime date) { ... }    // pure, aucun effet de bord
void _applySlotsFor(DateTime date) { ... } // assignation directe, appelable depuis initState
```

`_slotsFor` peut ainsi être appelée aussi bien depuis `initState` que depuis un `setState`.

### 7.6 `Ink` et `InkWell`

Pour qu'une couleur de fond soit visible sous un effet d'ondulation, `Ink` doit envelopper
`InkWell`, jamais l'inverse. Dans l'ordre contraire, l'ondulation est peinte sous la couleur et
devient invisible.

### 7.7 `context` après un `await`

Dans les méthodes de chargement, tout ce qui dépend du `BuildContext` (session, navigateur) est lu
**avant le premier `await`**, afin de ne jamais utiliser un `context` potentiellement démonté.

---

## 8. Points ouverts

Identifiés, non traités à ce stade :

1. **Fuite du contact d'urgence en mode anonyme.** La pseudonymisation est appliquée dans
   `PatientProfileServiceImpl` (remplacement de `firstName` par le pseudo, `lastName` vidé quand
   `!isOwner && callerIsPsychologist && anonymousMode`). En revanche,
   `emergencyContactName` et `emergencyContactPhone` ne sont **pas** masqués et restent affichés au
   psychologue (`patients_tab.dart`). Le correctif tient dans le même bloc conditionnel côté
   backend.

2. **Modalité présentiel sans adresse.** `BookingScreen` propose la modalité « en cabinet » même
   quand `psychologist.address` est nul.

3. **Repli du `ml-service` invisible.** Quand le service de recommandation est indisponible, la
   liste est triée par note mais le titre reste « Sélection personnalisée ». Afficher « Les mieux
   notés » dans ce cas serait plus honnête, et démontrerait le mécanisme de repli.

4. **Tests Flutter.** Le backend dispose de tests réels, dont deux tests de résilience. Côté
   Flutter, il n'existe que `widget_test.dart`. Trois ou quatre tests ciblés (calcul des créneaux,
   formatage des montants, groupement des notifications) couvriraient la logique pure la plus
   susceptible de régresser.

---

## 9. Contacter l'administrateur — `SupportMessage` (user-service)

**Ajouté le 02/09/2026.** Formulaire (sujet + message) accessible depuis les réglages patient
(`settings_screen.dart`, section « Aide ») et depuis le profil psychologue
(`psychologist_profile_screen.dart`, avant la déconnexion), qui envoie un message à
l'administrateur. Contrairement au signalement (`PsychologistReport`), ce n'est pas dirigé contre
un psychologue précis — c'est un canal de support général, ouvert aux deux rôles.

**Calqué délibérément sur le système de signalement existant** plutôt que d'inventer un style
différent : même famille de fichiers (`entity` + `enum` de statut + `repository` + `dto` +
`service`/`impl` + `controller`), même convention de sécurité (vérification que
`callerAuthUserId` correspond au propriétaire du profil expéditeur avant d'enregistrer), même
pattern côté admin (`_ActionTile` dans la section Modération → page plein écran →
liste filtrable + feuille de détail). Différences volontaires :

- Statut à deux valeurs seulement (`PENDING` / `RESOLVED`) plutôt que trois : il n'y a pas
  d'équivalent de « rejeté », un message adressé à l'admin n'est pas rejetable, seulement traité
  ou non.
- Un même expéditeur peut être patient ou psychologue (`senderRole` + `senderProfileId`), donc la
  vérification de propriété bascule entre `PatientProfileRepository` et
  `PsychologistProfileRepository` selon le rôle déclaré.
- Deux routes de soumission (`POST /patients/{id}/support-messages`,
  `POST /psychologists/{id}/support-messages`) plutôt qu'une seule : ça permet de garder la
  sécurité Spring alignée avec le découpage déjà en place (`/psychologists/**` → rôle PSYCHOLOGIST
  par défaut ; seule la route patient a nécessité une règle explicite, la route psychologue
  héritait déjà de la bonne restriction).
- Pas de pièce jointe (contrairement au signalement) : un message de support n'a pas besoin de
  preuve, seulement d'un sujet et d'un texte.

**Bug corrigé le 02/09/2026 : route manquante côté API Gateway.** Patient et psychologue
arrivaient à envoyer un message, mais l'admin voyait « Impossible de charger les messages » — les
routes du Gateway (`api-gateway/src/main/resources/application.properties`) ne sont **pas**
déclarées avec un `/admin/**` générique : chaque famille de endpoints admin a sa propre route
explicite (`admin-reports-route` → `/admin/reports/**`, `admin-user-route` →
`/admin/psychologists/**,/admin/patients/**,...`, etc.), pour éviter toute ambiguïté de matching
entre services. `POST /patients/{id}/support-messages` et `POST /psychologists/{id}/support-messages`
passaient déjà par les routes génériques `/patients/**` et `/psychologists/**` — d'où l'envoi
fonctionnel des deux côtés — mais `GET /admin/support-messages` et
`PATCH /admin/support-messages/{id}` ne correspondaient à **aucune** route déclarée, donc 404 côté
Gateway avant même d'atteindre `user-service`. Correctif : nouvelle route `routes[22]`
(`admin-support-messages-route` → `USER-SERVICE`, `Path=/admin/support-messages/**`), sur le
modèle de `admin-reports-route`. **Leçon à retenir pour toute future route `/admin/...` :** elle
doit systématiquement être ajoutée ici en plus du contrôleur backend, sans quoi elle reste
invisible du Gateway malgré une sécurité et un code par ailleurs corrects.

**Évolution du 02/09/2026 (suite) : identité de l'expéditeur + réponse admin.** Remontée
utilisateur : la liste admin n'affichait que `senderRole` + `senderProfileId` (ex. « Psychologue
#10 »), sans nom ni moyen de répondre — l'action unique était « Marquer comme traité », un simple
changement de statut qui ne renvoie rien à l'expéditeur. Deux correctifs :

- **Nom + téléphone résolus côté serveur.** `SupportMessageResponse` gagne `senderName` et
  `senderPhone`, calculés dans `SupportMessageServiceImpl.mapToResponse()` en rechargeant le
  `PatientProfile`/`PsychologistProfile` correspondant à `senderProfileId` puis son `UserProfile`
  lié (`firstName`/`lastName`/`phoneNumber` — l'identité et les coordonnées vivent dans
  `UserProfile`, pas dans les profils patient/psy eux-mêmes). La relation `@OneToOne` vers
  `UserProfile` étant en fetch `EAGER` par défaut, la lecture est sûre même en dehors d'une
  transaction explicite. Si le profil a été supprimé entretemps, `senderName` reste `null` et le
  frontend retombe sur l'ancien affichage `"Rôle #id"`.
- **Vraie réponse à la place du simple statut.** Nouveau champ `adminReply` (+ `repliedAt`) sur
  `SupportMessage`, nouvelle route `POST /admin/support-messages/{id}/reply` (déjà couverte par la
  route Gateway existante `Path=/admin/support-messages/**`, aucune modif du Gateway nécessaire).
  Envoyer une réponse : l'enregistre sur le ticket, bascule le statut à `RESOLVED`, et déclenche une
  notification vers l'expéditeur via le `NotificationClient` déjà utilisé par `BroadcastServiceImpl`
  (type `SUPPORT_REPLY`, titre = sujet du ticket, corps = texte de la réponse). Pas de fil de
  discussion multi-messages : une réponse peut être réécrite et renvoyée (nouvel envoi = nouvelle
  notification), ce qui suffit pour un canal de support à un seul aller-retour typique. Le bouton
  « Marquer comme traité » disparaît ; « Rouvrir » reste disponible une fois `RESOLVED`, pour
  remettre le ticket en attente si un échange supplémentaire est nécessaire.

**Bug corrigé le 02/09/2026 : réponse envoyée mais jamais reçue (`NotificationType` fermé).**
L'admin envoyait sa réponse sans erreur, mais rien n'apparaissait côté patient/psychologue, nulle
part. Cause : exactement le même bug déjà rencontré (et documenté) trois fois dans
`notification-service` pour `PAYMENT`, `QUESTIONNAIRE`/`QUESTIONNAIRE_RESULT` et `SESSION` —
`NotificationController.createNotification()` désérialise le corps JSON directement dans
l'entité `Notification`, dont le champ `type` est un `@Enumerated(EnumType.STRING)` sur l'enum
Java `NotificationType`. `"SUPPORT_REPLY"` n'y figurait pas : Jackson rejette la requête (400)
avant même d'atteindre `NotificationServiceImpl`, et ce 400 est avalé silencieusement par le
`@Retry`/`fallbackSend` de `NotificationClient` (juste un `LOGGER.warn`, aucune exception
remontée à l'appelant) — d'où le succès apparent côté admin. Correctif : ajout de
`SUPPORT_REPLY` à `NotificationType.java`. **Leçon toujours valable, maintenant vérifiée quatre
fois :** toute notification envoyée depuis un microservice avec un nouveau `type` doit d'abord
être ajoutée à cet enum, sans quoi l'échec est total et silencieux. Corrigé en même temps côté
Flutter : `AppNotificationType` gagne un cas `supportReply` dédié (icône `support_agent`, filtre
« Support ») au lieu de retomber sur `system` — `fromApiValue()` gardait déjà un `default` de
repli vers `system` (pratique introduite après les mêmes bugs PAYMENT/QUESTIONNAIRE/SESSION,
justement pour qu'un type inconnu ne fasse pas planter l'écran), donc ce point précis n'était pas
en cause côté client.

**Bug corrigé le 03/09/2026 : plus aucune notification visible, nulle part.** Après le correctif
ci-dessus, plus rien ne s'affichait — même les anciennes notifications (RDV, questionnaires,
paiements) qui fonctionnaient encore la veille. Deux bugs distincts empilés, trouvés par
diagnostic direct (requêtes SQL sur `psyconnect_notification` + `curl` direct sur
`notification-service`, en contournant l'app) :

1. **`user_role` jamais enregistré en base**, sur toutes les notifications existantes. Or
   `NotificationServiceImpl.getNotificationsByUserId()` filtre avec un `findByUserIdAndUserRole`
   à correspondance exacte — une comparaison à `NULL` en SQL n'est jamais vraie, donc toute ligne
   sans rôle est invisible pour toujours, peu importe le compte. Un `curl` direct sur
   `POST http://localhost:8086/notifications` a prouvé que `notification-service` enregistre
   correctement `userRole` quand on le lui envoie — le problème n'était donc pas côté réception.
   En creusant service par service : `appointment-service` avait un jar non reconstruit depuis
   l'ajout du paramètre `userRole` à `NotificationClient.send()` (5 arguments au lieu de 4) —
   reconstruit, corrigé (vérifié : les nouvelles notifs de RDV ont bien `user_role` rempli).
2. **`NotificationClient.send()` de `user-service` (et, par précaution, la même faille dans
   `payment-service`) plante silencieusement hors du thread de requête HTTP.** Le client appelle
   `SecurityUtils.currentAuthorizationHeader()` → `RequestContextHolder.currentRequestAttributes()`
   sans filet ; si ce code tourne sur un thread sans requête HTTP liée (typiquement
   `BroadcastServiceImpl.sendAsync()`, annoté `@Async`, donc exécuté sur un pool à part), ça lève
   `IllegalStateException: No thread-bound request found`, le `@Retry` s'épuise, et
   `fallbackSend()` avale l'échec avec un simple `LOGGER.warn` — aucune notification n'est jamais
   envoyée, sans qu'aucune erreur ne remonte à l'appelant. La version d'`appointment-service`
   avait déjà un `try/catch (IllegalStateException ignored)` autour de cet appel précis ; celles de
   `user-service` et `payment-service` ne l'avaient pas. Correctif : ajout du même `try/catch` aux
   deux. Sans risque fonctionnel — `POST /notifications` est `permitAll()` côté
   `notification-service` (appel interne inter-services), l'en-tête `Authorization` n'y est de
   toute façon pas exigé.

**Leçon à retenir :** dès qu'un `NotificationClient` (chaque service en a sa propre copie, pas de
lib partagée) peut être appelé depuis un contexte `@Async` ou tout autre thread hors requête HTTP,
l'appel à `SecurityUtils.currentAuthorizationHeader()` doit systématiquement être protégé par un
`try/catch (IllegalStateException ignored)` — sans quoi l'échec est total et silencieux, exactement
comme pour le bug d'enum `NotificationType` documenté plus haut. Pour diagnostiquer ce genre de
panne « succès affiché côté appelant mais rien ne se passe », le réflexe le plus efficace reste de
court-circuiter l'app entièrement : requête SQL directe sur la table concernée, et `curl` direct
sur le service suspecté, avant de perdre du temps à relire du code qui a l'air correct.

**Bug corrigé le 03/09/2026 (cause réelle et finale) : contrainte SQL `notifications_type_check`
jamais mise à jour.** Après le correctif ci-dessus, toujours rien — mais cette fois avec une vraie
exception dans les logs `user-service` (contrairement aux échecs silencieux précédents) :
```
HttpClientErrorException$BadRequest: 400 ... "notifications_type_check" ...
Failing row contains (..., SUPPORT_REPLY, ...)
```
Cause : `notification-service` a une contrainte `CHECK` en base sur la colonne `type`, générée par
Hibernate à un moment donné à partir des valeurs de `NotificationType` *à cet instant précis*.
`spring.jpa.hibernate.ddl-auto=update` ajoute les tables/colonnes manquantes mais **ne modifie
jamais les contraintes existantes** quand l'enum Java évolue ensuite. Vérification :
`SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'notifications_type_check'`
ne listait que `APPOINTMENT, REMINDER, SYSTEM, PAYMENT, QUESTIONNAIRE, QUESTIONNAIRE_RESULT` —
`ANNOUNCEMENT` et `SESSION` manquaient déjà (silencieusement cassés depuis leur ajout à l'enum,
sans qu'on l'ait jamais remarqué), et `SUPPORT_REPLY` n'avait aucune chance d'y être. Correctif en
SQL direct, sans rebuild :
```sql
ALTER TABLE notifications DROP CONSTRAINT notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('APPOINTMENT','REMINDER','SYSTEM','PAYMENT','QUESTIONNAIRE',
                  'QUESTIONNAIRE_RESULT','ANNOUNCEMENT','SESSION','SUPPORT_REPLY'));
```
**Leçon désormais complète pour tout ajout de valeur à `NotificationType` :** trois endroits à
synchroniser, pas un seul — (1) l'enum Java `NotificationType.java`, (2) la contrainte SQL
`notifications_type_check` en base (`ddl-auto=update` ne la touche jamais), et (3) l'enum Flutter
`AppNotificationType` (avec ses `switch` exhaustifs dans `notifications_screen.dart`,
`patient_shell.dart` et `psychologist_shell.dart`). Oublier la contrainte SQL est le piège le plus
sournois des trois : l'erreur ne remonte nulle part côté utilisateur (juste un log `WARN` avalé
par le circuit breaker), contrairement à un oubli d'enum Flutter qui casse la compilation
immédiatement et bruyamment.

---

## 10. Vocabulaire

**Pseudonymisation, pas anonymisation.** Le « mode anonyme » de l'application remplace l'identité
affichée par un pseudonyme ; l'identité réelle reste connue du système et accessible à
l'administrateur. Au sens du RGPD et de la loi sénégalaise n° 2008-12 sur la protection des données
à caractère personnel, il s'agit d'une **pseudonymisation** — une donnée pseudonymisée demeure une
donnée à caractère personnel. Une anonymisation véritable serait irréversible, ce qui est
incompatible avec le suivi thérapeutique et avec les obligations de traçabilité.

Le badge « Mode anonyme » affiché à côté du nom est cohérent : le nom qui figure à cet endroit est
déjà le pseudonyme.

---

## 11. Bouton « Laisser un avis » — corrigé le 03/09/2026

**Symptôme signalé :** dans le détail d'un rendez-vous terminé (`appointments_tab.dart`), le bouton
« Laisser un avis » restait affiché à l'identique même après qu'un avis avait déjà été envoyé pour
ce psychologue.

**Cause :** dans `_openDetail()`, le callback `onReview` n'était conditionné qu'au statut du
rendez-vous (`appointment.status == AppointmentStatus.completed`), sans jamais vérifier si un avis
existait déjà pour ce psychologue. Le bouton ne reflétait donc que « le rendez-vous est terminé »,
jamais « un avis a déjà été laissé ».

**Correctif :** un avis est rattaché au couple (patiente, psychologue) et non à un rendez-vous
précis (`getMyReview(psychologistId)` renvoie `rating: null` tant qu'aucun avis n'existe — c'est un
upsert côté backend). `_AppointmentsTabState` charge désormais, au même moment que les paiements
(`_loadPaidAppointmentIds`), l'ensemble des identifiants de psychologues déjà notés
(`_loadReviewedPsychologistIds`, appelé sur les psychologues de tous les rendez-vous `completed`) et
le garde dans `_reviewedPsychologistIds`. Ce set est transmis à `_AppointmentDetailSheet` via un
nouveau paramètre `hasReview`, qui change le libellé et l'icône du bouton : « Laisser un avis »
(étoile vide) si aucun avis n'existe, « Modifier votre avis » (étoile pleine) sinon — l'avis restant
modifiable après coup plutôt que masqué, puisque `submitReview` est un upsert. `_leaveReview()` met
aussi à jour `_reviewedPsychologistIds` immédiatement après un envoi réussi, pour que le bouton
change d'état sans attendre un rechargement complet de l'onglet.

---

## 8. Retrait des marqueurs « généré par IA » — lot 1 (2026-09-03)

Ce lot fait suite à l'audit chiffré du design existant (56 pastilles d'icône, 12 dégradés d'écran,
74 ombres, 151 `BorderRadius.circular()` en dur sur 11 valeurs différentes, 34 écrans sur 55 touchés)
et aux croquis avant/après de `docs/croquis-avant-apres-psyconnect.html`, validés avant écriture.

**Principe** : la palette (teal `#0D7B6E`, or `#D4A853`, fond `#F7F5F2`) et les polices
(Playfair Display + DM Sans) ne changent pas. Le contenu, les libellés, la navigation et la logique
des écrans non plus. Seule change la grammaire visuelle.

### 8.1 Jetons — `core/theme/app_tokens.dart`

- `AppRadius.sm/md/lg` passent de 12/16/22 à **0**. Une seule valeur de rayon pour toute l'application,
  au lieu des onze qui coexistaient. `pill` reste défini à 999 : il n'est plus utilisé par le kit, mais
  une vingtaine d'écrans non repris dans ce lot le référencent encore.
- `AppShadows.sm/md/lg` et `AppShadows.glow()` renvoient désormais une liste vide. La séparation entre
  surfaces est portée par un filet 1px, plus par une ombre. Les getters sont conservés plutôt que
  supprimés pour ne pas casser la centaine d'appels existants.
- `AppDecorations.card()` ajoute un filet par défaut ; `AppDecorations.hero()` rend un aplat de couleur
  au lieu d'un dégradé.

### 8.2 Thème — `core/theme/app_theme.dart`

`elevation` ramené à 0 sur les cartes, dialogues, feuilles modales, snack-bars, boutons et le FAB ;
`CardTheme` gagne un `side` (filet). `ChipTheme` quitte la forme pilule pour la forme carrée.
`NavigationBarTheme.indicatorColor` passe en transparent : la pastille teal derrière l'onglet actif
était l'un des marqueurs les plus visibles.

### 8.3 Kit de composants — `core/widgets/app_ui.dart`

L'API publique de chaque composant est **inchangée** (mêmes noms, mêmes paramètres nommés) : aucun
écran appelant n'a eu besoin d'être modifié, tous héritent du nouveau rendu.

| Composant | Avant | Après |
|---|---|---|
| `AppCard` | ombre douce + rayon 16 | filet 1px, coins droits, sans ombre |
| `AppHero` | dégradé teal + halo | aplat de couleur |
| `AppIconBadge` | icône dans un carré arrondi teinté (marqueur n°1, 56 occurrences) | icône nue, colorée |
| `AppPill` | conteneur pilule teinté | pastille de couleur + texte |
| `StatTile` | carte ombrée avec pastille d'icône | chiffre en Playfair + étiquette en petites capitales, sans carte |
| `QuickAction` | tuile avec pastille | carte à filet, icône nue |
| `SectionHeader` | titre en `titleMedium` + bouton « Voir tout » | étiquette en petites capitales espacées + filet horizontal |
| `AppEmptyState` | icône dans un cercle teinté 76px | icône nue |
| `AppAvatar` | cercle teinté avec anneau | carré teinté, initiales en Playfair |
| `AppNoticeCard` | carte teintée + pastille | bande teintée à bord gauche coloré 3px |

Deux composants ajoutés :

- **`StatBand`** — range N `StatTile` sur une seule ligne, séparés par des filets verticaux, entre deux
  filets horizontaux. Des chiffres qu'on veut comparer doivent partager une ligne de base ; en tuiles
  séparées, chacun vit dans sa boîte et la comparaison est perdue.
- **`AppListRow`** — ligne de liste avec filets, icône nue, chevron. Remplace les grilles de raccourcis :
  on peut ajouter une entrée sans casser la mise en page, ce qu'une grille 2×2 interdit.

### 8.4 Accueil patient — `features/patient/screens/patient_home_screen.dart`

- `_HomeHero` : le bandeau teal à coins arrondis 28px disparaît. La salutation devient une ligne en
  petites capitales ocre, le prénom un titre Playfair sur le fond de page, suivi d'un filet.
- `_HeroIconButton` : plus de rond blanc translucide, icône nue.
- `_SosButton` : garde son rouge et sa position (premier bloc de l'écran), perd le dégradé, le halo, le
  rayon et le cercle blanc autour de l'icône.
- Les deux `QuickAction` côte à côte et `_WalletRow` deviennent trois `AppListRow` : ce sont trois
  raccourcis de même nature, ils n'ont plus trois formes différentes. `_WalletRow` et `_HeroPill` sont
  supprimés.
- `_NextAppointmentCard` : carte blanche à filet et bord gauche teal 3px, date en Playfair, statut en
  une ligne « type · statut » au lieu de deux pilules blanches.

### 8.5 Tableau de bord psychologue — `features/psychologist/screens/psychologist_home_tab.dart`

- `_PsyHero` : même traitement que côté patient (fin du dégradé et des coins arrondis).
- Les quatre `StatTile` disposées en 2×2 deviennent un `StatBand` de quatre chiffres. Même information,
  environ un tiers de la hauteur.
- `_EmergencyToggleCard` : dégradé rouge, ombre portée et pastille d'icône retirés ; l'état actif reste
  un aplat rouge plein.
- `_NextPatientAppointmentCard` : même carte blanche à bord teal que côté patient. `_WhitePill` supprimé.
- `_PlanningCard` : le bloc horaire teinté devient l'heure en Playfair, qui fait colonne.

### 8.6 Reste à faire

Les 151 `BorderRadius.circular()` en dur des autres écrans ne sont pas repris dans ce lot : ils ne
suivent pas les jetons, donc ces écrans gardent leurs rayons d'origine tant qu'ils ne sont pas repris.
Même chose pour la vingtaine d'usages restants de `AppRadius.pill` hors du kit.

### 8.7 Note récupérée du code (elle était en commentaire dans `app_theme.dart`)

`FilledButtonTheme` impose une hauteur mais **pas** de largeur : `minimumSize: const Size(0, 46)`.
`Size.fromHeight(52)` vaut `Size(double.infinity, 52)` — dans une `Row`, une `AppBar` ou les actions d'un
dialogue, le bouton réclamait alors toute la largeur, écrasait ses voisins et sortait de l'écran. Les
boutons pleine largeur de l'application sont déjà enveloppés dans un `SizedBox(width: double.infinity)`
ou un `Expanded`, qui leur donne leur largeur. Ne pas remettre `Size.fromHeight` ici.

---

## 9. Changement de police — Figtree (2026-09-03)

Playfair Display est classée **Display** chez Google Fonts : dessinée pour du gros corps. L'application
l'utilisait à 17px (colonne horaire de l'agenda) et 26px (chiffres de date), tailles auxquelles ses déliés
tombent sous le pixel sur un écran de téléphone — d'où une impression de fragilité. Son registre, à contraste
fort, évoque par ailleurs la presse et le luxe plutôt qu'une plateforme de santé.

**Retenu : Figtree, seule famille pour toute l'application** (titres, texte, chiffres). Sans humaniste
légèrement arrondie, dessinée pour l'écran, lisible de 9px à 40px. Deux pistes écartées après comparaison
(`docs/croquis-typographie.html`) : Fraunces (serif douce, plus de signature mais registre éditorial) et
Nunito (plus tendre, mais registre bien-être plus attendu et risque d'infantiliser).

Le raisonnement : PsyConnect n'est pas seulement une application de relaxation. On y paie une consultation,
un psychologue y gère son agenda et ses revenus, un administrateur y valide des diplômes. Figtree tient les
deux registres, et l'unicité de famille supprime tout risque d'incohérence entre les 55 écrans.

### 9.1 Ce qui a changé

Tout passe par `_textTheme()` dans `core/theme/app_theme.dart`, plus les 17 appels directs à
`GoogleFonts.dmSans(...)` du même fichier (boutons, champs, chips, snack-bar, barre de navigation, onglets,
info-bulles). Aucun autre fichier ne référençait de police.

- La fonction locale `serif()` devient `display()` : le nom décrivait une famille à empattements qui n'existe
  plus. Même signature, plus un paramètre `letterSpacing`.
- Les **tailles de l'échelle typographique sont inchangées** (34 / 26 / 22 / 28 / 23 / 20 pour les titres,
  18 / 16 / 14 pour les titres fonctionnels, 15 / 14 / 12,5 pour le corps). Seuls la famille et
  l'interlettrage bougent.
- **Interlettrage négatif ajouté sur les grandes tailles** (−0,9 à −0,4 selon le niveau, −0,2 et −0,1 sur
  `titleLarge` / `titleMedium`). Une sans-serif en gros corps a besoin d'être resserrée ; sans ça les titres
  paraissent distendus. C'est le seul réglage réellement nécessaire au changement de famille.

### 9.2 Tailles en dur ajustées

Deux endroits fixaient une taille pour le chiffre du jour dans la carte « prochain rendez-vous » :
`patient_home_screen.dart` et `psychologist_home_tab.dart`, `fontSize: 26` → **24**. Figtree a une hauteur
d'x et une graisse apparente supérieures à Playfair au même corps ; à 26 le chiffre écrasait le nom du
praticien à 15px juste à côté.

Non modifiés, vérifiés comme corrects tels quels : la colonne horaire de l'agenda (17px, une sans grasse y
gagne en solidité), le solde du patient (16px), les initiales d'`AppAvatar` (`size * 0.36`), les chiffres de
`StatTile` (hérités de `displaySmall`, 22px) et le logotype du splash (38px, interlettrage −0,5).

### 9.3 Dépendance

Aucune. `google_fonts: ^8.1.0` était déjà au `pubspec.yaml` et sert la totalité du catalogue Google Fonts ;
Figtree y figure. Aucun fichier de police à embarquer dans `assets/`.

---

## 10. Épuration — lot 2 (2026-09-03)

Suite du lot 1 (section 8) et du changement de police (section 9). Objectif : appliquer aux autres écrans le
traitement validé sur les deux tableaux de bord. Approche retenue : **supprimer les composants recopiés en
local plutôt que redessiner écran par écran**, parce que ces copies sont partagées par des écrans très
différents et qu'une seule suppression en corrige plusieurs.

### 10.1 Déduplication de `_SectionLabel` — 7 fichiers, 25 appels

`_SectionLabel` existait en **7 exemplaires** pour **2 variantes réellement distinctes** : l'une en
`tealDark` 13px gras (rendez-vous patient, agenda, patients, profil psy), l'autre en `muted` 12px avec
interlettrage (édition de profil patient, paramètres, édition de profil psy). Les 25 appels passent à
`SectionHeader` du kit, la classe est supprimée des 7 fichiers, et l'import de `app_ui.dart` est ajouté là
où il manquait (5 fichiers).

Effet : tous les intitulés de section de l'application adoptent d'un coup les petites capitales espacées
suivies d'un filet, y compris sur des écrans qui n'étaient pas au programme (paramètres, édition de profil).

### 10.2 Suppression du jeton `pill`

`AppRadius.pillAll` était utilisé **15 fois** dans 9 fichiers — jamais pour un élément circulaire, toujours
pour une étiquette ou un filtre. Les 15 usages passent à `AppRadius.mdAll` et **le jeton `pill` est retiré
de `app_tokens.dart`** : garder un jeton nommé « pilule » qui vaut 0 aurait été un nom mensonger. Il ne
reste donc qu'une seule valeur de rayon dans les jetons.

Écrans concernés au passage, sans les avoir ouverts : splash, messagerie, réservation, notifications,
recherche de psychologue, rendez-vous patient, les deux portefeuilles, agenda.

### 10.3 Agenda du psychologue

- `_AgendaCard` : la carte (rayon 14, bordure teal, `CircleAvatar`, badge de statut en pilule teintée)
  devient une **ligne à filet avec colonne horaire** — l'heure en gras à gauche fait la colonne, la date en
  petit dessous, le statut en `AppPill` (pastille de couleur + texte). Même patron que le « Planning du
  jour » du tableau de bord : le praticien retrouve la même lecture aux deux endroits.
- Les couleurs de statut sont **remappées pour le contraste** : sur fond blanc, `gold` et `rose` (pensées
  pour un fond teinté) passent à `warning` et `danger`.
- `_DayHeading` rend un `SectionHeader` au lieu d'un `Text`.
- Séparateurs de liste supprimés : c'est le filet bas de chaque ligne qui sépare désormais.
- Feuille de détail : coins arrondis remplacés par un filet haut, `CircleAvatar` remplacé par un carré
  teinté, pilule « Mode anonyme » remplacée par un `AppPill`, rayons 12 retirés.

### 10.4 Statistiques du psychologue

- Les **quatre `_StatBox` en 2×2 deviennent un `StatBand`** de quatre `StatTile`. La classe `_StatBox`,
  qui était une recopie de l'ancien `StatTile`, est supprimée.
- `_RevenueCard` : aplat `tealDark` conservé (l'argent reste le point fort de l'écran), rayon retiré.
- `_RevenueValue` : le montant passe au-dessus de son étiquette, en style `displaySmall` ; l'étiquette
  descend en petites capitales espacées.
- `_StatusRow` : lignes à filets, compteur en `displaySmall`.
- Titre « Répartition des rendez-vous » → `SectionHeader`.
- Cartes portefeuille (et son état de repli) : rayon 14 retiré, bordure ramenée sur `AppColors.border`.

### 10.5 Patients du psychologue

`_PatientCard` suit exactement le même chemin que `_AgendaCard` : ligne à filet, `AppAvatar` du kit à la
place du `CircleAvatar`, badge « Suivi » en `AppPill`. Feuille de détail alignée sur celle de l'agenda.

### 10.6 Ce qui reste (lot 3 éventuel)

Mesuré après ce lot, sur l'ensemble de `lib/` :

| Marqueur | Avant lot 1 | Après lot 2 |
|---|---|---|
| Pastilles d'icône | 56 | 42 (dans 27 fichiers) |
| Dégradés | 27 | 24 |
| `BoxShadow` | 74 (avec elevation) | 21 |
| `circular()` en dur | 151 | 137 |

Le gros du reste est concentré dans les écrans **admin** (5 fichiers), le **parcours paiement /
portefeuille** (5 fichiers) et quelques écrans patient (journal, urgence, antécédents, Xalaat, réservation).
Ce sont des écrans que ce lot n'a pas ouverts : ils ont seulement hérité du thème, des jetons et des
composants du kit.

---

## 11. Épuration — lot 3, passes transverses (2026-09-03)

Le lot 2 avait traité les écrans un par un. Le lot 3 procède autrement : des **passes mécaniques sur
l'ensemble de `lib/`**, chacune vérifiée fichier par fichier (équilibrage des accolades et parenthèses,
et nombre d'accolades inchangé) avec **annulation automatique** du fichier en cas d'anomalie. Trois fichiers
ont effectivement été annulés par cette garde à la première passe et traités autrement ensuite.

### 11.1 Pastilles d'icône — 12 retirées

Transformateur structurel : repérage des `Container(...)` dont la décoration est teintée (couleur
`AppColors.*Light/Bg/Soft/Mid` ou `withValues(alpha:)`), qui portent un rayon ou `BoxShape.circle`, et dont
l'enfant direct est une `Icon(...)` unique. Le conteneur est remplacé par son icône seule.

Volontairement conservateur : les cas où l'icône est enveloppée dans un `Center` ou plus profondément n'ont
pas été touchés. **Précision importante sur le chiffre de 56 annoncé lors de l'audit initial** : cette
heuristique large comptait aussi des étiquettes de statut teintées (conteneur + `Text`), des poignées de
feuille modale et des blocs d'information teintés contenant une icône plus bas. Le nombre de véritables
pastilles d'icône était donc inférieur. Les autres cas sont traités par la passe suivante (rayons) et par le
remplacement des étiquettes par `AppPill` fait au lot 2.

### 11.2 Rayons en dur — 147 supprimés sur 151

Trois passes successives couvrant les formes rencontrées : ligne isolée
`borderRadius: BorderRadius.circular(N),`, forme en ligne avant une parenthèse fermante,
`BorderRadius.vertical(top:/bottom:)`, `BorderRadius.all(Radius.circular(N))`, `BorderRadius.only(...)`, et
`shape: RoundedRectangleBorder(borderRadius: ...)` sur les boutons.

**Quatre rayons volontairement conservés** : les trois constantes de forme des bulles de conversation dans
`chat_screen.dart` (16 / 6 / 4) et un rayon de 4 dans `patient_questionnaires_screen.dart`. Une bulle de
messagerie est une convention à part entière, pas un marqueur ; la rendre carrée nuirait à la lisibilité de
l'échange sans rien apporter.

### 11.3 Dégradés

Plutôt que de modifier les huit sites d'appel (risque de doublon avec un `color:` déjà présent dans la même
`BoxDecoration`), **les dégradés de la palette rendent désormais un aplat** : `splashGradient`,
`headerGradient`, `heroGradient` et `goldGradient` sont définis avec deux fois la même couleur. Même
mécanique que `AppShadows` au lot 1. Les écrans concernés (accueil, connexion, splash, tableau de bord admin,
statistiques admin, paramètres, profil patient) basculent sans être ouverts.

`scrim` est conservé tel quel : c'est un voile transparent vers noir destiné à garder un texte lisible
au-dessus d'une image, pas une décoration.

Le seul vrai dégradé restant, un `RadialGradient` blanc, était le halo `_GlowCircle` du splash — trois
cercles flous superposés derrière le logo. **La classe et ses trois usages sont supprimés.**

### 11.4 Ombres portées

Toutes les listes `boxShadow:` littérales et tous les appels `boxShadow: AppShadows.*` restants ont été
retirés des écrans (15 blocs dans 14 fichiers). Il ne reste **aucun `BoxShadow` construit** dans `lib/` :
les seules occurrences du mot sont des déclarations de type dans `app_tokens.dart` et `app_ui.dart`.

### 11.5 Bilan chiffré

| Marqueur | Avant lot 1 | Après lot 3 |
|---|---|---|
| Pastilles d'icône (heuristique large) | 56 | 13 |
| Rayons en dur | 151 | 4 (assumés) |
| `BoxShadow` construits | 74 (avec elevation) | 0 |
| Dégradés réels | 12 | 0 |

Reste : les 13 conteneurs teintés encore comptés sont des blocs d'information et des étiquettes de statut,
pas des pastilles d'icône. Les convertir en `AppPill` ou en bandes à bord coloré demande une lecture écran
par écran — c'est du travail d'ajustement, plus du retrait de marqueur.

### 11.6 Correctif après `flutter analyze` (2026-09-03)

L'analyse a été lancée après le lot 3 : **aucune erreur de compilation**, 10 avertissements. Trois venaient
du chantier design, et l'un révélait un vrai dégât.

**`_NoteCard` (notes cliniques) avait été avalée.** Le transformateur de la passe 11.1 cherchait
`child: Icon(...)` dans tout le corps d'un `Container` teinté au lieu de vérifier qu'il s'agissait de son
enfant **direct**. Dans `_NoteCard`, il a trouvé l'icône du bouton « supprimer », imbriquée dans une `Row`,
et a remplacé la carte entière (38 lignes : date, bouton, contenu de la note) par ce seul bouton. Les deux
contrôles automatiques n'ont rien vu : les parenthèses restaient équilibrées et le nombre d'accolades était
inchangé, le bloc supprimé n'en contenant aucune. C'est l'avertissement `unused_local_variable: dateLabel`
qui a mis sur la piste.

La carte est reconstruite, dans la nouvelle grammaire cette fois : ligne à filet, date en petites capitales,
contenu sur quatre lignes maximum, bouton de suppression en `AppColors.danger`.

**Vérification des dix autres fichiers** passés par le même transformateur : diff systématique contre les
sauvegardes, avec un seuil d'alerte sur le nombre de lignes retirées. Neuf retiraient 6 à 9 lignes — la taille
attendue d'une pastille — contre 38 pour `_NoteCard`. **Aucun autre dégât.**

Deux `Container` devenus inutiles (`patient_shell.dart`, `psychologist_shell.dart`), conséquence du retrait
des ombres, ont également été supprimés.

**Avertissements restants, tous antérieurs au chantier design** et sans rapport avec lui : un paramètre
`badge` jamais utilisé dans `admin_shell.dart` (fichier non modifié), quatre noms de constantes en majuscules
dans `questionnaire_models.dart` (`PHQ9`, `GAD7`, `SENT`, `COMPLETED` — renommer casserait la sérialisation
si ces noms viennent du backend, à vérifier avant), et deux `activeColor` dépréciés dans
`settings_screen.dart` (renommé `activeThumbColor` par Flutter).

### 11.7 Suppression réelle des dégradés (2026-09-04)

Le point 11.3 avait pris un raccourci : les dégradés de la palette rendaient un aplat (deux fois la même
couleur), ce qui donnait le bon résultat à l'écran mais laissait du vocabulaire de dégradé partout dans le
code. C'est fait proprement maintenant.

- Les **7 sites d'appel** passent de `gradient: AppColors.xxxGradient` à `color:` avec la couleur
  correspondante : `headerGradient` → `AppColors.teal` (accueil, tableau de bord admin, statistiques admin,
  paramètres, profil patient), `heroGradient` → `AppColors.tealDark` (connexion), `splashGradient` →
  `AppColors.tealDark` (splash). Aucune de ces `BoxDecoration` ne portait déjà un `color:`, la substitution
  était donc directe.
- Les **cinq constantes** `splashGradient`, `headerGradient`, `heroGradient`, `goldGradient` et `scrim` sont
  **supprimées de `app_colors.dart`**. `scrim` et `goldGradient` n'étaient plus utilisés nulle part.
- `AppDecorations.hero()` supprimée de `app_tokens.dart` : inutilisée, et c'était le dernier point du code à
  prendre un `Gradient` en paramètre. Le reste de la classe `AppDecorations` est également inutilisé, mais
  conservé — ce n'est pas l'objet de ce chantier.
- Le paramètre `gradient` d'`AppHero` est retiré : il avait été gardé au lot 1 pour ne casser aucun appel,
  mais il était ignoré par le rendu et plus aucun appelant ne le renseignait.

**Résultat : plus aucune occurrence de `Gradient` ni de `gradient` dans `lib/`.**

---

## 12. Pop-up « Nouveau message » — ajouté le 04/09/2026, revu le même jour

**Demande :** quand un patient ou un psychologue reçoit un message dans une conversation, avoir un
pop-up en direct plutôt que de devoir ouvrir l'onglet Messages pour s'en apercevoir, et taper dessus
doit ouvrir directement la conversation concernée.

**Première version (abandonnée) :** faire transiter l'événement par `notification-service`, comme
les autres types de notifications — `MessagingServiceImpl.sendMessage()` appelait
`NotificationClient` avec un nouveau type `MESSAGE`, persisté en base et remonté dans l'écran
Notifications. Écartée après coup : un message vit déjà dans sa conversation (avec son propre état
lu/non-lu via `unreadCount`) ; le dupliquer comme `Notification` créait un second état de lecture
désynchronisé pour le même événement, et aurait fini par noyer l'écran Notifications sous une entrée
par message. L'entité `Notification` ne porte de toute façon aucun identifiant de référence, donc
même avec cette approche le tap n'aurait pu ouvrir que l'onglet Messages en entier, pas la
conversation précise.

**Version retenue :** le pop-up est sourcé directement depuis les conversations, sans passer par
`notification-service` — `sendMessage()` ne notifie plus rien côté backend.
- `patient_shell.dart` et `psychologist_shell.dart` pollent déjà `getMyConversations()` toutes les
  10 secondes pour le badge de messages non lus (`_refreshUnreadCount`). Chaque cycle compare
  désormais `lastMessageAt` de chaque conversation à la dernière valeur vue
  (`_seenConversationActivity`) ; une conversation dont `unreadCount > 0` et dont `lastMessageAt` a
  avancé déclenche un pop-up (le premier trouvé dans le cycle, jamais une rafale — les autres sont
  marquées vues sans pop-up et seront rattrapées au cycle suivant si toujours pertinentes).
  `unreadCount` ne compte que les messages envoyés par l'autre participant, donc écrire soi-même un
  message ne déclenche jamais son propre pop-up.
- Le pop-up réutilise le composant `_NotifPopup` déjà existant, avec une `AppNotification`
  construite localement (jamais envoyée ni reçue du backend) — `AppNotificationType.newMessage`
  reste dans l'enum Flutter pour cet usage d'affichage uniquement, mais n'est plus mappée depuis
  l'API (`fromApiValue` ne la produit plus) et a été retirée des filtres de l'écran Notifications :
  aucune vraie notification de ce type n'existera jamais.
- `_showNotifPopup` accepte maintenant un `onOpen` optionnel (par défaut : ouvrir l'écran
  Notifications, comme avant). Pour un message, il résout le nom de l'interlocuteur via
  `PsychologistService.getPsychologistById` / `ProfileService.getPatientProfileById` — les mêmes
  endpoints que `MessagesTab`/`PsychologistMessagesTab`, donc la pseudonymisation est respectée sans
  code supplémentaire — puis ouvre `ChatScreen` directement sur la conversation.
- Contenu du pop-up toujours générique (« Nouveau message », sans nom ni aperçu) : rien de personnel
  ne doit apparaître sur un écran verrouillé ou visible par-dessus l'épaule, dans une messagerie
  thérapeutique.

`NotificationType.MESSAGE` et la contrainte SQL associée ont été retirés (la première version n'a
jamais été utilisée en dehors des tests de ce jour).

---

## 13. Modification du pseudonyme (mode anonyme) — ajouté le 04/09/2026

**Constat :** le mode anonyme masque le nom du patient auprès du psychologue en le remplaçant par un
pseudonyme (`AuthServiceClient.getPseudo`, voir §9/§10 sur la pseudonymisation), mais ce pseudonyme
est fixé une seule fois à l'inscription (`RegisterRequest.pseudo`, contrôle d'unicité dans
`AuthService.register`) et rien nulle part ne permettait de le changer ensuite.

**Correctif :**
- `auth-service` expose un nouvel endpoint `POST /auth/pseudo` (authentifié, route déjà couverte par
  le wildcard `/auth/**` de la gateway — aucune route à ajouter). `AuthService.updatePseudo(email,
  nouveauPseudo)` réutilise le même contrôle d'unicité que l'inscription (`userRepository
  .findByPseudo`), avec le même message d'erreur, remonté tel quel côté client via le
  `GlobalExceptionHandler` déjà en place (`RuntimeException` → 400 + `{"message": "..."}`).
- Côté Flutter, le pseudo était déjà entièrement présent côté client (`AuthSession.pseudo`, chargé au
  login et persisté dans `TokenStorage`) — pas besoin d'un nouvel appel pour l'afficher.
  `AuthProvider.updatePseudo()` appelle le nouvel endpoint puis persiste la session mise à jour via
  `_persistSession(session.copyWith(pseudo: ...))`, exactement comme après un login.
- Ajouté dans `SettingsScreen`, juste sous le bouton « Mode anonyme » (même carte, même
  regroupement logique) : une ligne « Pseudonyme » affichant la valeur actuelle, qui ouvre une
  feuille de saisie (`_PseudoSheet`, même style que `_ReviewSheet` dans `AppointmentsTab`) pour la
  modifier.
- Restreint au patient pour l'instant : le mode anonyme n'existe que côté patient
  (`PatientProfile.anonymousMode`, aucun équivalent sur `PsychologistProfile`).

---

## 12. Signalements — notification du psychologue traité (point 9c, 2026-09-04)

Dernier point ouvert de la liste du 02/09. La note d'origine prévoyait d'étendre `BroadcastService` pour
qu'il puisse cibler un utilisateur précis (il ne connaît que les audiences ALL / PATIENTS / PSYCHOLOGISTS).
**Ce n'était pas nécessaire** : `user-service` possède déjà un `NotificationClient` qui poste vers
`notification-service` pour un `userId` donné, et il s'en sert déjà pour prévenir un psychologue de la
validation ou du refus de son profil (`PsychologistProfileServiceImpl`). Aucun nouvel endpoint, aucune
extension du broadcast.

### 12.1 Ce qui change

`ReportServiceImpl` reçoit le `NotificationClient` par constructeur et appelle une méthode privée
`notifyPsychologist(report, status)` juste après l'enregistrement dans `reviewReport`. Le service n'était
instancié nulle part à la main (uniquement injecté par Spring) et aucun test ne le référence : l'ajout d'un
paramètre au constructeur est sans effet de bord.

Deux messages, selon la décision de l'administrateur :

| Statut | Titre | Message |
|---|---|---|
| `REVIEWED` | Signalement traité | Un signalement vous concernant a été examiné par l'administration et une mesure a été prise. Contactez le support pour plus d'informations. |
| `DISMISSED` | Signalement classé sans suite | Un signalement vous concernant a été examiné par l'administration et jugé non fondé. Aucune mesure n'a été prise à votre encontre. |

Type `SYSTEM`, rôle `PSYCHOLOGIST` — donc la notification remonte dans l'écran Notifications côté psychologue,
qui existe déjà.

### 12.2 Deux décisions de confidentialité

- **L'identité du patient signalant n'est jamais transmise.** Elle n'apparaît ni dans le titre ni dans le
  message, cohérent avec le masquage `#anonyme` fait côté écran admin.
- **La note interne de l'administrateur n'est pas incluse.** Elle est saisie pour la modération et peut
  contenir un raisonnement interne ou des éléments permettant de remonter au patient. Le psychologue est
  invité à contacter le support plutôt que de recevoir cette note telle quelle. À rediscuter si
  l'administration veut au contraire motiver explicitement sa décision.

Le patient signalant, lui, n'est pas notifié : ce n'était pas demandé, et l'informer qu'une mesure a été
prise contre un praticien soulève d'autres questions.

### 12.3 Robustesse

Aucun try/catch ajouté : `NotificationClient.send()` porte déjà `@Retry` avec une méthode de repli qui se
contente de journaliser un avertissement. Si `notification-service` est indisponible, le traitement du
signalement aboutit quand même — le statut est enregistré, seule la notification est perdue. C'est le
comportement voulu : la modération ne doit pas dépendre de la disponibilité des notifications.

`NOTIFICATION_SERVICE_URL` est déjà correctement renseignée avec son port (`http://notification-service:8086`)
dans le bloc `user-service` du `docker-compose.yml` — le piège rencontré au point 3 ne se represente pas ici.

### 12.4 À faire côté machine

La compilation n'a pas pu être lancée depuis l'environnement de travail : pas d'accès réseau pour récupérer
la distribution Gradle, et le JDK disponible est un 11 alors que le projet exige un 17. À exécuter localement :

```
cd backend/user-service && ./gradlew build
cd ../.. && docker compose up --build -d user-service
```

Le `./gradlew build` avant le rebuild n'est pas optionnel : les Dockerfile du projet se contentent de copier
`build/libs/*.jar` sans compiler. Sans lui, l'ancien jar est republié silencieusement.
