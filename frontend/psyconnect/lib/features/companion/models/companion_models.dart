// correspond au contrat de ai-companion-service (POST /companion/chat).
//
// IMPORTANT (confidentialité) : ces objets ne doivent JAMAIS être écrits
// dans un stockage persistant (SharedPreferences, base locale, fichier...).
// L'historique de conversation avec Xalaat existe seulement en mémoire,
// le temps que l'écran XalaatScreen reste ouvert.

// "role" est soit "user" soit "assistant", comme côté backend (ChatTurn).
class CompanionTurn {
  const CompanionTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// flagged=true => le garde-fou de sécurité (RiskDetectionService) s'est
// déclenché côté backend : "reply" est le message fixe avec les numéros
// d'urgence, pas une réponse générée par le modèle.
class CompanionReply {
  const CompanionReply({required this.reply, required this.flagged});

  final String reply;
  final bool flagged;

  factory CompanionReply.fromJson(Map<String, dynamic> json) => CompanionReply(
        reply: json['reply'] as String,
        flagged: json['flagged'] as bool? ?? false,
      );
}
