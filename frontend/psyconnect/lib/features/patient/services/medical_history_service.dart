import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/medical_history_models.dart';

// GET/PUT /patients/{id}/medical-history : accessible au patient proprietaire
// et au psy qui le suit (verifie cote backend), jamais a l'admin
class MedicalHistoryService {
  MedicalHistoryService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<MedicalHistory> getMedicalHistory(int patientId) async {
    final json = await _api.get(ApiConstants.patientMedicalHistory(patientId));
    return MedicalHistory.fromJson(json as Map<String, dynamic>);
  }

  Future<MedicalHistory> updateMedicalHistory(
    int patientId,
    UpdateMedicalHistoryRequest request,
  ) async {
    final json = await _api.put(
      ApiConstants.patientMedicalHistory(patientId),
      body: request.toJson(),
    );
    return MedicalHistory.fromJson(json as Map<String, dynamic>);
  }
}
