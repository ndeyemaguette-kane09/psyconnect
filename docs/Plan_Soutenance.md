# PsyConnect — plan de soutenance

*25 minutes de présentation avec projection. Variantes 20 et 30 minutes en §3.*

---

## 1. Le principe directeur

**Le contexte sénégalais n'est pas une section d'introduction. C'est ce qui justifie
chaque choix technique.**

L'erreur classique : trois slides de contexte au début, puis vingt minutes de
technique qui pourraient décrire n'importe quelle application de prise de rendez-vous.
Le jury voit alors deux travaux collés l'un à l'autre.

La bonne méthode : chaque décision technique est présentée **avec la contrainte
sénégalaise qui l'a produite**. Pas « j'ai intégré Wave et Orange Money », mais « le
taux de bancarisation est faible et le paiement mobile domine, donc le portefeuille de
l'application se recharge par Wave et Orange Money ».

Tu as déjà tout ce qu'il faut dans ton code. Il ne manque que la phrase qui relie.

---

## 2. Les cinq ancrages sénégalais dans ton code

À placer là où ils tombent naturellement, jamais groupés.

| Ancrage | La contrainte | Ce que ton code en fait |
|---|---|---|
| **Paiement mobile** | Faible bancarisation, domination du transfert mobile | Portefeuille interne rechargé par Wave / Orange Money, retrait praticien par les mêmes canaux |
| **Stigmatisation** | La santé mentale reste taboue ; la peur d'être reconnu est un frein d'accès documenté | Mode anonyme : pseudonymisation de l'identité affichée au psychologue |
| **Cadre juridique** | Loi 2008-12 sur la protection des données à caractère personnel, CDP | Pseudonymisation (et non anonymisation) assumée et justifiée |
| **Coût des soins** | Consultation hors de portée d'une grande partie de la population | Champ « consultations solidaires » remonté sur la fiche du praticien |
| **Rareté des praticiens** | Très faible densité de psychiatres et psychologues | Bouton d'urgence en tête d'accueil, statut « joignable en urgence » du praticien |

Deux ancrages de plus, plus discrets, à glisser si l'occasion se présente :

- **Xalaat** — le compagnon IA porte un nom wolof. Ce n'est pas cosmétique : c'est un
  choix d'appropriation culturelle de l'outil.
- **Connectivité inégale** — trois modalités de consultation (visio, audio, présentiel)
  plutôt qu'une seule ; l'audio reste utilisable là où la vidéo ne passe pas.

> **Chiffres :** reprends ceux de ton mémoire, avec leur source. Ne cite jamais une
> statistique que tu ne peux pas sourcer si on te la demande — un jury vérifie.

---

## 3. Budget minute par minute — 25 minutes

| Temps | Séquence | Contenu |
|---|---|---|
| **0 – 4 min** | **Contexte et problématique** | Les chiffres sourcés, la stigmatisation, le coût, la rareté. Se termine sur la question de recherche. |
| **4 – 6 min** | **La réponse** | Les trois promesses de l'app, une phrase chacune : trouver un praticien adapté, payer par mobile money, préserver son anonymat. |
| **6 – 10 min** | **Architecture** | Le schéma microservices. Insister sur ce qui se défend : Eureka, la gateway, la résilience (Resilience4j), le traçage (Zipkin), le service ML. |
| **10 – 18 min** | **DÉMONSTRATION** | Une seule histoire, de bout en bout. Voir §4. |
| **18 – 22 min** | **Points techniques différenciants** | Résilience (1 min 30), recommandation ML (1 min), sécurité (1 min 30). |
| **22 – 25 min** | **Limites et perspectives** | Ce qui n'est pas fait, et pourquoi. Se termine sur l'ouverture. |

**Pour tenir en 20 minutes :** réduis l'architecture à 3 minutes et la démonstration à
6 (coupe la partie messagerie). Ne touche pas au contexte, c'est ton sujet.

**Si tu as 30 minutes :** ajoute 2 minutes sur la démonstration (le parcours
psychologue complet) et 3 minutes sur les points différenciants — c'est là que tu
marques, pas dans plus de contexte.

**Règle absolue : la démonstration fait au moins un tiers du temps.** C'est le seul
moment où le jury voit que l'application existe vraiment.

---

## 4. Le script de démonstration — 8 minutes

**Une seule histoire suivie, pas une visite des écrans.** Le fil : une personne en
difficulté trouve de l'aide et la paie.

### Côté patient — 5 minutes

1. **Accueil.** Le bouton d'urgence est le premier élément de la page.
   → *« Sur un outil d'accompagnement psychologique, ce qui doit être trouvé sans
   réfléchir, c'est l'aide immédiate — pas le solde. C'est un arbitrage de hiérarchie
   visuelle. »*

2. **Recherche d'un psychologue**, filtre par spécialité.
   → *« Les recommandations viennent du service ML, en filtrage de contenu ; en cas
   d'indisponibilité, repli sur un tri par note. »*

3. **Fiche du praticien.** Montre la spécialité, le profil vérifié, et **les
   consultations solidaires**.
   → *« L'écran sert à décider, pas à réserver — c'est pour ça que la réservation est
   un écran distinct. »*

4. **Réservation** : modalité, date, créneau. Envoi de la demande.

5. **Portefeuille** : recharge par Wave ou Orange Money, puis paiement de la séance.
   → *« Le rendez-vous se règle toujours sur le solde interne ; les opérateurs ne
   servent qu'à l'alimenter. Le paiement est simulé, le solde est réellement
   persisté. »*

### Côté psychologue — 3 minutes

6. **Bascule de compte.** Agenda : le bandeau de semaine, la demande en attente.

7. **Confirmation** de la demande. Reviens montrer la notification arrivée côté
   patient — c'est le moment le plus convaincant de toute la démonstration, parce qu'il
   prouve que les services communiquent.

8. **Fiche patient** : montre le pseudonyme au lieu du nom réel.
   → *« Le mode anonyme est activé côté patient. Le psychologue ne voit jamais son nom
   civil ; c'est le backend qui substitue le pseudonyme, aucun autre service n'a
   connaissance de cette règle. »*

**Ce que tu ne montres pas :** le journal, les questionnaires, Xalaat, les statistiques,
l'espace administrateur. Cite-les en une phrase sur un slide de couverture
fonctionnelle — *« l'application comporte également… »* — et propose de les montrer
pendant les questions.

---

## 5. La sécurité en 90 secondes

**Un slide, deux colonnes, et tu passes.** Pas de section dédiée, pas de démonstration
live.

Sur le slide, à droite du tableau « implémenté / assumé » : **une capture d'écran de
Postman montrant le 403** avec le message « Ce rendez-vous ne vous appartient pas ».
Une image, zéro seconde de manipulation.

Ce que tu dis, en une respiration :

> La sécurité repose sur trois piliers : les mots de passe hachés en BCrypt, le JWT
> validé indépendamment par **chaque** microservice — pas seulement à la passerelle — et
> un contrôle de propriété qui ne fait jamais confiance à l'identifiant passé dans
> l'URL : l'identité métier est reconstruite depuis le jeton. Cette capture montre un
> patient qui tente d'accéder au rendez-vous d'un autre : 403.
>
> J'assume trois limites, liées au déploiement local : le transport en HTTP, le secret
> JWT non externalisé, et la réinitialisation de mot de passe qui renvoie son code
> faute de service d'envoi d'e-mail intégré. Elles sont documentées dans l'audit joint
> en annexe.

**Garde Postman ouvert dans un onglet.** Si on te pose la question en discussion, tu
fais la démonstration en direct — et là, le temps ne t'est plus compté.

---

## 6. Le filet de sécurité technique

Tu as eu un jeton expiré aujourd'hui à cause des 24 heures de validité. Le jour J, ce
genre d'incident coûte cher.

- [ ] **Enregistre une vidéo de la démonstration** la veille, écran + voix. Si le
      backend tombe, tu la projettes et tu commentes. Personne ne t'en tiendra rigueur
      si tu l'annonces calmement ; en revanche une démo qui plante sans plan B coûte
      très cher.
- [ ] **Connecte-toi le matin même** sur les deux comptes de démonstration. Le JWT dure
      24 h — une session de la veille sera morte.
- [ ] **Prépare le jeu de données** : au moins une demande en attente, un rendez-vous
      confirmé, un solde non nul, une conversation avec quelques messages, une annonce
      système non lue. Un écran vide fait mauvaise impression.
- [ ] **Lance la pile 15 minutes avant** et fais un passage complet du scénario.
- [ ] Mets ton téléphone en mode avion sauf le Wi-Fi, et coupe les notifications.
- [ ] Aie les captures d'écran des écrans clés dans les slides, en secours.

---

## 7. La conclusion — 3 minutes

Ne termine pas sur les limites, termine sur la trajectoire.

Trois perspectives, dans cet ordre :

1. **Intégration réelle des opérateurs** — les API Wave et Orange Money existent ; le
   code est déjà structuré pour, la simulation est isolée derrière un service.
2. **Passage en production** — terminaison TLS, secrets externalisés, envoi SMTP. Trois
   points identifiés et chiffrés dans l'audit.
3. **Ce que ça permettrait** — reviens sur le contexte de départ. C'est là que tu
   refermes la boucle : l'application répond à un problème d'accès aux soins, et voici
   ce qui la sépare d'un usage réel.

La dernière phrase doit parler du Sénégal, pas de Spring Boot.

---

## 8. Checklist finale

**Slides à préparer ou modifier**

- [ ] Slide « Sécurité — implémenté / assumé » avec la capture du 403
- [ ] Slide de couverture fonctionnelle listant ce qui n'est pas démontré
- [ ] Vérifier que chaque slide technique porte **une** phrase de contexte sénégalais

**Documents à joindre au mémoire**

- [ ] `docs/Audit_Securite.md`
- [ ] `docs/Notes_Conception_Interface.md`

**Répétitions**

- [ ] Une répétition chronométrée complète, à voix haute
- [ ] La réponse sécurité de 90 secondes, deux fois
- [ ] Le passage de la démo au slide suivant (c'est là qu'on perd du temps)
