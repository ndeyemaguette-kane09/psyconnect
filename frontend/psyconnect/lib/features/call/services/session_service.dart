import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/session_models.dart';

// endpoints /sessions de appointment-service : demarrer/finir/consulter
// la session simulee liee a un RDV CONFIRMED. utilise par patient et psy
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
    // le controller backend utilise @PutMapping("/{id}/end")
    final json = await _api.put(ApiConstants.sessionEnd(sessionId));
    return CallSession.fromJson(json as Map<String, dynamic>);
  }

  Future<List<CallSession>> getSessionsByAppointment(int appointmentId) async {
    final json = await _api.get(ApiConstants.sessionByAppointment(appointmentId));
    return (json as List)
        .map((e) => CallSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // démarre une session d'urgence sans RDV : appel direct patient → psy dispo
  Future<CallSession> startEmergencySession({
    required int patientId,
    required int psychologistId,
  }) async {
    final json = await _api.post(
      ApiConstants.sessionsEmergency,
      body: {'patientId': patientId, 'psychologistId': psychologistId},
    );
    return CallSession.fromJson(json as Map<String, dynamic>);
  }
}
