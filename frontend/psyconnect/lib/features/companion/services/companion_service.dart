import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/companion_models.dart';

// appelle Xalaat (ai-companion-service, /companion/chat).
//
// Aucune sauvegarde locale ici : l'appelant (XalaatScreen) garde l'historique
// en mémoire et le renvoie en entier à chaque appel. Ne JAMAIS faire
// persister "history" (SharedPreferences, DB locale...) : la confidentialité
// de la conversation est une contrainte dure du projet, cf. README du
// service backend.
class CompanionService {
  CompanionService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<CompanionReply> chat({
    required String message,
    required List<CompanionTurn> history,
  }) async {
    final json = await _api.post(
      ApiConstants.companionChat,
      body: {
        'message': message,
        'history': history.map((t) => t.toJson()).toList(),
      },
      timeout: ApiConstants.companionChatTimeout,
    );
    return CompanionReply.fromJson(json as Map<String, dynamic>);
  }
}
