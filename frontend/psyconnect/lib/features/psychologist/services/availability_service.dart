import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/availability_models.dart';

class AvailabilityService {
  AvailabilityService({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // GET public : liste des plages de disponibilite d'un psy
  Future<List<PsychologistAvailability>> getAvailabilities(
      int psychologistId) async {
    final json = await _api
        .get(ApiConstants.psychologistAvailabilities(psychologistId));
    return (json as List)
        .map((e) =>
            PsychologistAvailability.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // PUT proprietaire : remplace tout le planning hebdomadaire
  // ApiClient.put() encode en { ... } donc on wrappe dans { "availabilities": [...] }
  // (le backend attend ReplaceAvailabilitiesRequest avec ce champ)
  Future<List<PsychologistAvailability>> saveAvailabilities(
    int psychologistId,
    List<AvailabilityRequest> requests,
  ) async {
    final json = await _api.put(
      ApiConstants.psychologistAvailabilities(psychologistId),
      body: {
        'availabilities': requests.map((r) => r.toJson()).toList(),
      },
    );
    return (json as List)
        .map((e) =>
            PsychologistAvailability.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
