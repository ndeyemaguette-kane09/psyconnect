// correspond a ConversationResponse cote appointment-service. le backend
// envoie jamais les noms, faut aller les chercher cote client via
// PsychologistService/ProfileService, pareil que pour les RDV
class Conversation {
  final int id;
  final int patientId;
  final int psychologistId;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.patientId,
    required this.psychologistId,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: (json['id'] as num).toInt(),
        patientId: (json['patientId'] as num).toInt(),
        psychologistId: (json['psychologistId'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
        lastMessagePreview: json['lastMessagePreview'] as String?,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

// correspond a MessageResponse cote appointment-service
class ChatMessage {
  final int id;
  final int conversationId;
  final int senderAuthUserId;
  final String content;
  final DateTime sentAt;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderAuthUserId,
    required this.content,
    required this.sentAt,
    required this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] as num).toInt(),
        conversationId: (json['conversationId'] as num).toInt(),
        senderAuthUserId: (json['senderAuthUserId'] as num).toInt(),
        content: json['content'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'] as String),
      );
}
