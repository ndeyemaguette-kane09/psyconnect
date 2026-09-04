# Perspectives — Politique de confidentialité & protection des données (PsyConnect)

Notes pour la rédaction de la section "Perspectives" du mémoire. À ne PAS implémenter dans le code actuel — juste à mentionner comme axe d'amélioration futur.

## Terminologie à corriger

Ne pas parler de "politique de cookies". PsyConnect est une application 100% Flutter mobile : pas de navigateur, pas de tracking cross-site, donc pas de cookies au sens classique du terme. Le terme juste est **politique de confidentialité et de protection des données à caractère personnel**.

## Ancrage légal (Sénégal)

- Loi n°2008-12 du 25 janvier 2008 sur la protection des données à caractère personnel.
- Autorité de contrôle : CDP — Commission de protection des données personnelles.
- Argument à mettre en avant devant le jury : PsyConnect manipule des données de santé mentale (rendez-vous psy, questionnaires cliniques PHQ-9/GAD-7, notes cliniques privées) → catégorie de données sensibles nécessitant une protection renforcée, ce qui justifie de traiter le sujet même si l'implémentation complète n'a pas pu être faite dans le temps imparti.

## Points à couvrir dans le paragraphe Perspectives

- Consentement explicite du patient à la collecte de données (inscription / première prise de RDV).
- Minimisation des données visibles par des tiers — déjà partiellement amorcé dans le projet : un psychologue non approuvé reste invisible des patients tant qu'il n'est pas validé par un administrateur.
- Chiffrement au repos des données sensibles (notes cliniques, résultats de questionnaires).
- Politique de rétention et droit à l'effacement des données (suppression de compte = suppression réelle des données associées, pas juste désactivation).
- Registre des traitements : qui accède à quoi (patient / psychologue / admin) et pourquoi.

## Lien avec l'audit déjà fait

Un audit "écarts documentation vs code" avait déjà identifié le chiffrement comme point manquant — cette section Perspectives peut s'appuyer dessus pour montrer une continuité de réflexion sur le sujet tout au long du projet.
