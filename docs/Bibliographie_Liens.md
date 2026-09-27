# Bibliographie du mémoire : liens et quoi lire

Chaque référence du mémoire avec son lien, ce qu'elle apporte à PsyConnect, et ce
qu'il faut en lire au minimum. Liens vérifiés le 24/09/2026.

**À savoir avant tout.** Une bibliographie, c'est la liste de ce que tu as
réellement consulté. Le jury peut demander : « Qu'avez-vous tiré de Newman ? ». Si
tu n'as pas ouvert l'ouvrage, la question te met en difficulté. Deux options pour
chaque référence : tu la lis (au moins la partie indiquée), ou tu la retires.

Autre point : aujourd'hui, le texte du mémoire ne renvoie presque jamais aux
références. On ne trouve aucun « [3] » après la mention du PHQ-9, par exemple. Une
bibliographie sans appel dans le texte, c'est une liste décorative. Dès que tu as
lu une référence, ajoute son numéro là où tu l'utilises.

---

## Priorité 1 : à lire, parce qu'elles soutiennent directement ton texte

**[5] OMS (2022). Rapport mondial sur la santé mentale : transformer la santé
mentale pour tous. Vue d'ensemble.**
- Page : <https://www.who.int/fr/publications/i/item/9789240050860>
- PDF en français : <https://iris.who.int/bitstream/handle/10665/356117/9789240051928-fre.pdf>
- Pourquoi : source des chiffres de ton introduction (§1.1, « près de 1 milliard de
  personnes »). Vérifie que le « 80 % sans soins » y figure bien, avec le même
  sens. Sinon, reformule avec le chiffre exact du rapport.
- À lire : la vue d'ensemble, une vingtaine de pages.

**[13] Ministère de la Santé (2024). Plan stratégique d'amélioration de la qualité
des soins en santé mentale au Sénégal 2024–2028.**
- PDF : <https://www.sante.gouv.sn/sites/default/files/Plan%20strate%CC%81gique%20Sante%CC%81%20Mentale%20Senegal%202024-2028%20V.pdf>
- Correction faite : l'ancienne référence (« Plan de développement de la santé
  mentale 2019–2023 », 2020) est introuvable. Je l'ai remplacée par ce plan, qui
  existe bien.
- Pourquoi : c'est **la** source sénégalaise officielle de ton mémoire. Elle
  donne 38 psychiatres en 2019 (ce qui confirme ta « quarantaine » du §1.1). Elle
  constate aussi l'absence de numéro vert pour les urgences psychiatriques
  (cité au §5.4.4).
- Attention : ton résumé annonce une prévalence de « plus de 20 % ». Ce plan cite
  une enquête de 2023 où 6,4 % des personnes déclarant une maladie présentaient
  des troubles mentaux. Ce n'est pas la même mesure, mais le 20 % doit avoir une
  source précise, sinon il faut le retirer.
- À lire : l'analyse de situation (état des lieux, ressources humaines,
  faiblesses).

**[3] Kroenke, Spitzer & Williams (2001). The PHQ-9.**
- Article gratuit : <https://pmc.ncbi.nlm.nih.gov/articles/PMC1495268/>
- DOI : <https://doi.org/10.1046/j.1525-1497.2001.016009606.x>
- Pourquoi : c'est l'article qui valide le questionnaire que tu as implémenté.
  Les seuils de sévérité (5, 10, 15, 20) viennent de là.
- À lire : le résumé, puis le tableau des seuils.

**[7] Spitzer, Kroenke, Williams & Löwe (2006). The GAD-7.**
- DOI : <https://doi.org/10.1001/archinte.166.10.1092>
- Pourquoi : même rôle que le PHQ-9, pour l'anxiété (seuils 5, 10, 15).
- À lire : le résumé.

**[2] Fowler & Lewis (2014). Microservices.**
- Article en ligne : <https://martinfowler.com/articles/microservices.html>
- Correction faite : ce n'est pas une publication O'Reilly, c'est un article
  publié sur le site de Martin Fowler.
- Pourquoi : la définition de référence des microservices. Elle nourrit tes
  réponses sur « pourquoi microservices ».
- À lire : tout l'article, environ 30 minutes. C'est le plus rentable de la liste.

**[12] RFC 7519 : JSON Web Token.**
- <https://www.rfc-editor.org/rfc/rfc7519>
- Pourquoi : le standard des jetons que tu utilises.
- À lire : l'introduction et la section 4 (les « claims » : `sub`, `exp`…).

---

## Priorité 2 : ouvrages techniques, à lire en partie ou à retirer

**[4] Newman S. (2021). Building Microservices, 2e éd. O'Reilly.**
- <https://www.oreilly.com/library/view/building-microservices-2nd/9781492034018/>
- À lire si tu la gardes : le chapitre 1 (« What Are Microservices? »).

**[6] Richardson C. (2018). Microservices Patterns. Manning.**
- <https://www.manning.com/books/microservices-patterns>
- Les patrons décrits gratuitement par l'auteur : <https://microservices.io/patterns/>
- Très utile pour toi : le patron **Saga** (<https://microservices.io/patterns/data/saga.html>),
  qui explique exactement la limite que tu cites au §5.3 sur le paiement.
  Idem pour **API Gateway** et **Database per service**.

**[10] Walls C. (2022). Spring in Action, 6e éd. Manning.**
- <https://www.manning.com/books/spring-in-action-sixth-edition>

**[11] Windmill E. (2020). Flutter in Action. Manning.**
- <https://www.manning.com/books/flutter-in-action>

Pour ces deux livres, la documentation officielle (webographie) couvre en
pratique ce que tu as utilisé. Si tu ne les as pas lus, tu peux les retirer sans
perdre en crédibilité.

---

## Priorité 3 : articles sur les modèles de langage

Aucun n'est cité dans le texte. Ce sont des articles de recherche fondateurs, pas
des sources que tu as utilisées pour construire Xalaat.

**[9] Vaswani et al. (2017). Attention Is All You Need.** L'architecture
Transformer, sur laquelle reposent tous les LLM.
- <https://arxiv.org/abs/1706.03762>

**[1] Brown et al. (2020). Language Models are Few-Shot Learners.** L'article de
GPT-3.
- <https://arxiv.org/abs/2005.14165>

**[8] Touvron et al. (2023). LLaMA.** Les modèles ouverts de Meta.
- <https://arxiv.org/abs/2302.13971>

Deux possibilités : les retirer, ou garder la seule [9] et la citer au §4.2.5 en
une phrase (« qwen2.5 repose, comme les autres grands modèles de langage, sur
l'architecture Transformer [9] »). Si tu la gardes, sache expliquer en deux phrases
ce qu'est un Transformer.

---

## [14] OMS : plan d'action

**OMS (2021). Comprehensive mental health action plan 2013–2030.**
- <https://www.who.int/publications/i/item/9789240031029>
- Correction faite : l'ancienne entrée disait 2023 et « Mental health action
  plan ». Le titre exact est « Comprehensive… », publié en 2021.
- Pourquoi : cadre international dans lequel s'inscrit PsyConnect (le plan
  encourage la santé numérique et les soins de proximité).

---

## Webographie

**Applications du chapitre 2**

| Application | Lien |
|---|---|
| BetterHelp | <https://www.betterhelp.com> |
| Talkspace | <https://www.talkspace.com> |
| Wysa | <https://www.wysa.com> (l'ancien <https://www.wysa.io> redirige) |
| 7 Cups | <https://www.7cups.com> |
| NOCD | <https://www.treatmyocd.com> |
| MindShift CBT | <https://www.anxietycanada.com/resources/mindshift-cbt> |
| Elomia | <https://elomia.com> |
| Lyynk | <https://www.lyynk.com> (corrigé : c'était lyynk.app, et lyynk.fr au §2.3.10) |
| Fadjou | <https://fadjou.com> (absent de la webographie : à ajouter) |
| Consultel | Application Android : <https://play.google.com/store/apps/details?id=sn.app.consultel> (le site consultel.sn cité au §2.3.3 reste à vérifier ; Consultel est absent de la webographie) |

Pour les chiffres cités sur les concurrents (30 000 thérapeutes, 300 000
écoutants, 5 millions d'utilisateurs…), vérifie-les sur ces sites. Garde seulement
ceux que tu retrouves.

**Santé mentale au Sénégal et en Afrique**

- OMS, santé mentale : <https://www.who.int/fr/health-topics/mental-health>
- Ministère de la Santé, programme santé mentale : <https://www.sante.gouv.sn/programmes-et-projets/programme-sant%C3%A9-mentale-psm>
- OMS Afrique : <https://www.afro.who.int/health-topics/mental-health>

**Technologies**

- Spring Boot : <https://docs.spring.io/spring-boot/index.html>
- Spring Cloud Gateway : <https://docs.spring.io/spring-cloud-gateway/reference/>
- Flutter : <https://docs.flutter.dev>
- Docker : <https://docs.docker.com>
- Ollama : <https://ollama.com>
- Zipkin : <https://zipkin.io>
- Resilience4j : <https://resilience4j.readme.io>

Les deux liens Spring de ta webographie (`…/current/reference/html`) sont
d'anciennes adresses. Elles redirigent encore, mais mieux vaut mettre celles
ci-dessus.

---

## Chiffres de l'introduction encore sans source

- « plus de 20 % de la population » (résumé) : aucune source. Voir [13].
- « plus de 19 millions de SIM actives recensées par l'ARTP » (§1.1) : il faut le
  rapport ou l'observatoire ARTP précis, avec l'année. Cherche-le sur le site de
  l'ARTP (<https://www.artp.sn>).
- « moins d'une quarantaine de psychiatres » : maintenant sourcé par [13]
  (38 en 2019). Ajoute « [13] » après la phrase.
- « 17 millions d'habitants » : ajoute la source ANSD (<https://www.ansd.sn>).
