# Site vitrine PsyConnect

Site statique de présentation de l'application PsyConnect, avec trois questionnaires
d'auto-évaluation exécutés entièrement côté navigateur.

## Contenu

```
website/
├── index.html          Landing : constat chiffré, fonctionnalités, deux parcours, FAQ, urgences
├── tests.html          Hub des tests + moteur de questionnaire + page de résultat
├── mentions.html       Mentions légales et protection des données
├── README.md
└── assets/
    ├── css/site.css    @font-face + charte reprise de l'application Flutter
    ├── js/site.js      En-tête collant, menu mobile, année du footer
    ├── js/tests.js     Les 3 échelles, le scoring, les bandes d'interprétation, le parcours de crise
    ├── fonts/          Playfair Display 600 et DM Sans 400/500/700, en woff2 (116 Ko)
    └── img/psyconnect-mark.svg
```

Aucune dépendance, aucun build, aucun `node_modules`, **aucune requête vers un domaine
extérieur**. Le site fonctionne hors ligne une fois chargé.

## Lancer en local

Ouvrir `index.html` directement dans un navigateur suffit. Pour un serveur local :

```bash
cd website
python3 -m http.server 8000
```

Puis http://localhost:8000

## Déployer

**Netlify** — https://app.netlify.com/drop, glisser le dossier `website/`. En ligne en 30 secondes.

**Cloudflare Pages** — bande passante illimitée et réseau plus rapide en Afrique de l'Ouest.
Connecter le dépôt, `website` comme dossier de sortie, aucune commande de build.

**Vercel** — `npx vercel --prod` depuis `website/`, ou import du dépôt GitHub avec
`website` comme *root directory* et « Other » comme framework.

**GitHub Pages** — pousser le contenu de `website/` sur une branche `gh-pages`,
ou activer Pages sur `/website` depuis les réglages du dépôt.

### Avant la première mise en ligne

`mentions.html` contient deux champs à compléter, signalés en jaune sur la page :
l'adresse e-mail de contact et le nom de l'hébergeur retenu.

## Les trois échelles

| Test | Échelle | Items | Score | Seuils utilisés |
|---|---|---|---|---|
| Humeur et moral | PHQ-9 (Kroenke, Spitzer & Williams, 2001) | 9 | 0–27 | 0-4 / 5-9 / 10-14 / 15-19 / 20-27 |
| Anxiété | GAD-7 (Spitzer et al., 2006) | 7 | 0–21 | 0-4 / 5-9 / 10-14 / 15-21 |
| Estime de soi | Rosenberg (RSES, 1965) | 10 | 0–30 | <15 / 15-25 / >25 |

Les trois échelles sont libres d'usage. Les items 3, 5, 8, 9 et 10 de l'échelle de
Rosenberg sont cotés en inversé (`reverse: true` dans `tests.js`, score = `3 - réponse`).

## Trois garde-fous à ne pas retirer

1. **Aucune donnée ne sort du navigateur.** Pas de `fetch`, pas de `localStorage`,
   pas d'analytics. Les réponses vivent dans une variable JavaScript et disparaissent
   au rafraîchissement de la page. C'est ce qui met le site hors du champ des données
   de santé et permet de l'annoncer sans réserve.

2. **Aucune requête vers un tiers.** Les polices sont hébergées avec le site plutôt que
   chargées depuis Google Fonts, dont la requête révélerait l'adresse IP du visiteur.
   Ne pas réintroduire de CDN, de police distante, ni d'iframe : la promesse du point 1
   ne tiendrait plus.

3. **Le parcours de crise.** Si l'item 9 du PHQ-9 (pensées de mort ou d'automutilation)
   reçoit une réponse autre que « Jamais », un bloc rouge s'affiche en tête de résultat
   avec le SAMU (1515), les pompiers (18), Thiaroye et le CHNU Fann. Ce bloc apparaît
   quel que soit le score total. Toute modification de `tests.js` doit préserver ce
   comportement.

## Modifier le contenu

- **Textes de la landing** : directement dans `index.html`.
- **Questions, options, seuils et textes d'interprétation** : objet `SCALES` en haut
  de `assets/js/tests.js`. Ajouter un test = ajouter une entrée à cet objet (avec
  `id`, `items`, `options`, `bands` couvrant `0` à `max` sans trou) puis une carte
  dans `tests.html`.
- **Couleurs et typographie** : variables CSS dans `:root` (`assets/css/site.css`),
  alignées sur `frontend/psyconnect/lib/core/theme/app_colors.dart`.
- **Ajouter une graisse de police** : récupérer le `.woff2` correspondant, le déposer
  dans `assets/fonts/`, ajouter un bloc `@font-face` en tête de `site.css`.

## Source des chiffres

Plan stratégique Santé Mentale Sénégal 2024–2028, Ministère de la Santé et de l'Action
sociale : 43 psychiatres recensés en 2020, 6 régions sans service de psychiatrie
(Diourbel, Kaffrine, Matam, Kédougou, Kolda, Sédhiou), 6,4 % de troubles mentaux
d'après l'enquête nationale de 2023.
