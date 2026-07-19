import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/messaging_models.dart';

// endpoints de messagerie, routes via /messages/** vers appointment-service.
// pas de websocket, le "temps reel" c'est juste du polling cote ecran (chat_screen)
class MessagingService {
  MessagingService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<Conversation>> getMyConversations() async {
    final json = await _api.get(ApiConstants.messagesConversations);
    return (json as List)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // get-or-create : démarre une conversation avec otherProfileId (un
  // PsychologistProfile.id si on est patient, un PatientProfile.id sinon)
  // ou renvoie celle qui existe déjà
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
