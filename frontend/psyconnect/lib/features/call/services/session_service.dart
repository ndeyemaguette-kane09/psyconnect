import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/session_models.dart';

/// Appelle les endpoints /sessions de appointment-service (via l'API
/// Gateway) : démarrage/fin/consultation de la session simulée associée à
/// un RDV CONFIRMED. Partagé entre parcours patient et psychologue.
class SessionService {
  SessionService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<CallSession> startSession(int appointmentId) async {
    final json = await _api.post(
      ApiConstants.sessionsStart,
      body: {'appointmentId': appointmentId},
    );
    return CallSession.fromJson(json as Map<String, dynamic>);
  }

  Future<CallSession> endSession(int sessionId) async {
    final json = await _api.post(ApiConstants.sessionEnd(sessionId));
    return CallSession.fromJson(json as Map<String, dynamic>);
  }

  Future<List<CallSession>> getSessionsByAppointment(int appointmentId) async {
    final json = await _api.get(ApiConstants.sessionByAppointment(appointmentId));
    return (json as List)
        .map((e) => CallSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
