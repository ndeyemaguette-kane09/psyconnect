import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/recommendation_models.dart';

class RecommendationService {
  RecommendationService({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // PSY : cree une recommandation (seance COMPLETED obligatoire cote backend)
  Future<SessionRecommendation> createRecommendation({
    required int appointmentId,
    required String content,
  }) async {
    final json = await _api.post(
      ApiConstants.sessionRecommendations,
      body: {'appointmentId': appointmentId, 'content': content},
    );
    return SessionRecommendation.fromJson(json as Map<String, dynamic>);
  }

  // PATIENT : recommandations non cochees (vue accueil)
  Future<List<SessionRecommendation>> getMyPendingRecommendations() async {
    final json = await _api.get(ApiConstants.myPendingRecommendations);
    return (json as List)
        .map((e) => SessionRecommendation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // PSY ou PATIENT : recommandations d'un RDV specifique
  Future<List<SessionRecommendation>> getByAppointment(
      int appointmentId) async {
    final json = await _api
        .get(ApiConstants.recommendationsByAppointment(appointmentId));
    return (json as List)
        .map((e) => SessionRecommendation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // PATIENT : coche comme accomplie
  Future<SessionRecommendation> markCompleted(int id) async {
    final json = await _api.patch(ApiConstants.recommendationComplete(id));
    return SessionRecommendation.fromJson(json as Map<String, dynamic>);
  }

  // PSY : supprime
  Future<void> deleteRecommendation(int id) async {
    await _api.delete(ApiConstants.sessionRecommendation(id));
  }
}
