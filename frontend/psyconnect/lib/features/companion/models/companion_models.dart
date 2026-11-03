// contrat de ai-companion-service (POST /companion/chat)
// confidentialité : ne jamais persister ces objets, l'historique reste en mémoire

// "role" est soit "user" soit "assistant", comme côté backend (ChatTurn).
class CompanionTurn {
  const CompanionTurn({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// flagged : c'est le garde-fou qui a répondu (numéros d'urgence), pas le modèle
class CompanionReply {
  const CompanionReply({required this.reply, required this.flagged});

  final String reply;
  final bool flagged;

  factory CompanionReply.fromJson(Map<String, dynamic> json) => CompanionReply(
        reply: json['reply'] as String,
        flagged: json['flagged'] as bool? ?? false,
      );
}
