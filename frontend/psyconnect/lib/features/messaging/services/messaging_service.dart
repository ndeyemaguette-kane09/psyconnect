import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/messaging_models.dart';

/// Appelle les endpoints de messagerie (routés via /messages/** vers
/// appointment-service, cf. messaging-route dans
/// api-gateway/application.properties). Pas de WebSocket : le "temps réel"
/// est simulé côté écran par polling périodique (cf. chat_screen.dart).
class MessagingService {
  MessagingService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<Conversation>> getMyConversations() async {
    final json = await _api.get(ApiConstants.messagesConversations);
    return (json as List)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// "Get or create" : démarre une conversation avec [otherProfileId] (un
  /// PsychologistProfile.id si l'appelant est patient, un PatientProfile.id
  /// sinon) ou récupère la conversation existante si elle existe déjà.
  Future<Conversation> startOrGetConversation(int otherProfileId) async {
    final json = await _api.post(
      ApiConstants.messagesConversations,
      body: {'otherProfileId': otherProfileId},
    );
    return Conversation.fromJson(json as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getMessages(int conversationId) async {
    final json =
        await _api.get(ApiConstants.messagesConversationMessages(conversationId));
    return (json as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage(int conversationId, String content) async {
    final json = await _api.post(
      ApiConstants.messagesConversationMessages(conversationId),
      body: {'content': content},
    );
    return ChatMessage.fromJson(json as Map<String, dynamic>);
  }

  Future<void> markConversationRead(int conversationId) async {
    await _api.patch(ApiConstants.messagesConversationRead(conversationId));
  }
}
