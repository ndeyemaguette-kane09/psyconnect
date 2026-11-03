import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/companion_models.dart';

// appelle Xalaat (/companion/chat). rien n'est sauvegardé ici, XalaatScreen
// garde l'historique en mémoire et le renvoie à chaque appel
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
