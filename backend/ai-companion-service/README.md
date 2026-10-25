# ai-companion-service

Service du compagnon Xalaat. Il aide le patient à préparer sa première consultation : comprendre comment elle se passe, mettre des mots sur ce qu'il ressent. Il ne pose jamais de diagnostic et ne remplace pas le psychologue.

## Fonctionnement

- Aucun stockage : pas de base de données, et le contenu des messages n'est jamais écrit dans les logs. L'historique de la conversation est gardé par l'application et renvoyé à chaque appel.
- Avant tout appel au modèle, `RiskDetectionService` cherche des expressions de détresse (idées suicidaires, automutilation…). Si l'une d'elles est trouvée, le modèle n'est pas appelé : le service renvoie un message fixe avec les numéros d'urgence (SAMU 1515, numéro vert 800 00 50 50, Police 17, Pompiers 18).
- Le modèle (qwen2.5:3b) tourne en local avec [Ollama](https://ollama.com). Aucune clé d'API, aucun service externe.

## Lancer en local

```bash
ollama pull qwen2.5:3b
ollama serve
./gradlew bootRun
```

Eureka et la passerelle doivent être démarrés. Variables disponibles (valeurs par défaut dans `application.properties`) : `SERVER_PORT` (8087), `EUREKA_URL`, `JWT_SECRET`, `OLLAMA_URL`, `OLLAMA_MODEL`, `ZIPKIN_ENDPOINT`.

## Point d'accès

`POST /companion/chat`

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

`flagged: true` indique que le filtre s'est déclenché : la réponse est le message fixe avec les numéros d'urgence.
