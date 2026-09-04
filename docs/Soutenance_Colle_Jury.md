# Soutenance — réponses aux questions du jury

*Fiche de révision. Réponses condensées, à dire à l'oral. Le jury ne lit pas le code :
tout ce qui suit doit être racontable sans écran.*

Statut : manche 1 en cours. Les manches 2 à 5 s'ajoutent au fur et à mesure.

---

## MANCHE 1 — Architecture

### Q1. Pourquoi des microservices plutôt qu'un monolithe bien découpé ?

**À ne jamais dire :** « c'est plus scalable », « c'est plus sécurisé », « ça sépare
mieux les flux ». Les deux premières sont fausses. La troisième, un monolithe la fait
aussi — le jury retournera l'argument.

**Réponse — trois arguments, dans cet ordre :**

1. **L'hétérogénéité technologique.** Le service de recommandation est en Python
   (FastAPI, numpy), le reste en Java / Spring Boot. Aucun monolithe Java ne permet ça.
   Le découpage est ce qui donne accès à l'écosystème scientifique Python.

2. **La dégradation de service différenciée.** Chaque appel entre services porte un
   retry, un circuit breaker et un fallback — et le fallback n'est pas le même partout
   (voir Q1 bis).

3. **La preuve par l'usage.** En cours de projet, la logique de paiement est devenue
   trop lourde dans `appointment-service` ; elle a été extraite en `payment-service`
   sans toucher à l'authentification, aux notifications ni au frontend.

**Le coût, à annoncer soi-même :**

> « Le prix se paie sur trois points : la cohérence des données entre services, gérée
> par compensation et non par transaction distribuée ; le débogage, qui a imposé
> d'instrumenter le traçage avec Zipkin ; et le coût de développement, dix services à
> lancer pour tester un parcours. Sur ce périmètre, un monolithe modulaire aurait été
> plus rapide à livrer. J'ai choisi le distribué parce que le service de recommandation
> impose Python, et parce que la dégradation de service est un enjeu réel dans un
> contexte de connectivité inégale. »

---

### Q1 bis. Concrètement, qu'est-ce que la résilience apporte ?

**Les trois mécanismes :**

- **Retry** — 3 tentatives, 300 ms d'écart, délai aléatoire pour éviter que les
  requêtes parallèles retentent au même instant et achèvent le service (*retry storm*).
- **Circuit breaker** — fenêtre glissante de 10 appels ; au-delà de 50 % d'échec, le
  circuit s'ouvre et l'appel échoue immédiatement pendant 10 s. On cesse de marteler un
  service à terre, et l'utilisateur n'attend plus pour rien. Puis *half-open* : 3
  appels d'essai décident de refermer ou non.
- **Fallback** — le comportement quand le circuit est ouvert.

**Le point différenciant — trois fallbacks, trois décisions :**

| Dépendance | Comportement en panne | Justification |
|---|---|---|
| notification-service | Log d'avertissement, le rendez-vous est créé | La notification est du confort, elle ne bloque pas un acte métier |
| user-service (`OwnershipResolver`) | Exception, réponse 503, opération refusée | Ce service dit qui est l'utilisateur ; sans lui, laisser passer serait une faille |
| payment-service (remboursement) | Log d'erreur « remboursement manuel nécessaire », l'annulation aboutit | Ne pas bloquer un patient pour une panne technique ; tracer la dette |

**La phrase :**

> « La résilience n'est pas un réglage uniforme. Une panne du service de notification ne
> doit pas empêcher de prendre rendez-vous : je dégrade. Une panne du service
> utilisateur m'empêche de savoir qui est l'utilisateur : je refuse l'opération, parce
> que continuer serait une faille de sécurité. J'ai choisi de tomber en marche ou de
> tomber fermé selon l'enjeu. »

Deux tests automatisés couvrent ce comportement : `NotificationClientResilienceTest` et
`OwnershipResolverResilienceTest`.

---

### Q2. Une seule instance PostgreSQL pour six bases — à traiter
### Q3. Cohérence entre paiement et rendez-vous — à traiter
### Q4. Eureka, gateway, Resilience4j, Zipkin : lequel est retirable — à traiter

---

## MANCHE 2 — Le service de recommandation

*à venir*

## MANCHE 3 — Sécurité, données de santé, cadre légal

*à venir*

## MANCHE 4 — Tests, qualité, méthode

*à venir*

## MANCHE 5 — Éthique, Xalaat, limites

*à venir*
