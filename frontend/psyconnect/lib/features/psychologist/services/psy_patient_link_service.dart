import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

// gestion du lien de suivi psy ↔ patient.
// endpoints : POST/DELETE /psychologists/{psyId}/followed-patients/{patientId}
//             GET /psychologists/{psyId}/followed-patients
//             GET /psychologists/{psyId}/followed-patients/{patientId} (bool)
class PsyPatientLinkService {
  PsyPatientLinkService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // marque un patient comme "suivi" par ce psy
  Future<void> followPatient(int psyId, int patientId) async {
    await _api.post(
      ApiConstants.followedPatient(psyId, patientId),
      body: {},
    );
  }

  // retire le patient du suivi
  Future<void> unfollowPatient(int psyId, int patientId) async {
    await _api.delete(ApiConstants.followedPatient(psyId, patientId));
  }

  // liste des patientProfileId suivis par ce psy
  Future<List<int>> getFollowedPatientIds(int psyId) async {
    final json = await _api.get(ApiConstants.followedPatients(psyId));
    return (json as List).map((e) => (e as num).toInt()).toList();
  }

  // vrai/faux : ce psy suit-il ce patient ?
  Future<bool> isFollowing(int psyId, int patientId) async {
    final json = await _api.get(ApiConstants.followedPatient(psyId, patientId));
    return json as bool;
  }
}
