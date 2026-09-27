# ai-companion-service

Compagnon de préparation IA de PsyConnect : aide une personne à se préparer
avant sa première consultation avec un psychologue (jamais de diagnostic,
jamais de remplacement d'un professionnel de santé).

## Principes de conception

- **Confidentialité** : ce service ne stocke rien. Pas de base de données,
  pas de log du contenu des échanges. L'historique de conversation est
  géré côté client (Flutter) et renvoyé à chaque appel — rien ne persiste
  côté serveur.
- **Garde-fou avant le modèle** : `RiskDetectionService` filtre chaque
  message *avant* tout appel au LLM. Si un signal de détresse
  (idées suicidaires, automutilation...) est détecté, le modèle n'est
  jamais sollicité : un message fixe et garanti est renvoyé directement,
  avec les numéros d'urgence sénégalais (SAMU 1515, numéro vert du
  ministère de la Santé 800 00 50 50, Police 17, Pompiers 18).
- **Modèle open source local** : aucune clé API, aucun appel à un service
  tiers. Le modèle (Mistral 7B Instruct par défaut) tourne via
  [Ollama](https://ollama.com), localement ou sur une machine du réseau du
  projet.

## Lancer le service en local

1. Installer et démarrer Ollama : <https://ollama.com/download>
2. Télécharger le modèle (≈ 4-5 Go, à faire une seule fois) :
   ```bash
   ollama pull mistral
   ```
3. Vérifier qu'Ollama tourne (par défaut sur `http://localhost:11434`) :
   ```bash
   ollama serve
   ```
4. Démarrer Eureka, l'api-gateway, puis ce service :
   ```bash
   ./gradlew bootRun
   ```

Variables d'environnement disponibles (toutes optionnelles, valeurs par
défaut dans `application.properties`) : `SERVER_PORT` (8087),
`EUREKA_URL`, `JWT_SECRET`, `OLLAMA_URL`, `OLLAMA_MODEL`, `ZIPKIN_ENDPOINT`.

## Endpoint

`POST /companion/chat` (via la gateway, ou directement sur le port 8087)

```json
{
  "message": "J'ai peur de mon premier rendez-vous, je ne sais pas par où commencer",
  "history": [
    { "role": "user", "content": "Bonjour" },
    { "role": "assistant", "content": "Bonjour, comment puis-je t'aider ?" }
  ]
}
```

Réponse :

```json
{
  "reply": "C'est tout à fait normal d'être un peu nerveux...",
  "flagged": false
}
```

`flagged: true` signifie que le garde-fou de sécurité s'est déclenché : la
réponse est le message fixe avec les numéros d'urgence, pas une réponse du
modèle.

## Non vérifié

Le build n'a pas pu être lancé dans l'environnement de développement
(pas d'accès réseau à Maven Central pour télécharger les dépendances).
À tester avec `./gradlew build` en local avant la première utilisation
réelle — en particulier la version `1.0.8` du BOM Spring AI et la
compatibilité avec Spring Boot 3.5.14.
