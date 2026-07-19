import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/report_models.dart';

class ReportService {
  ReportService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // soumet un signalement (multipart : champs texte + fichier optionnel)
  Future<ReportModel> submitReport({
    required int patientId,
    required int psychologistId,
    required String reason,
    String? description,
    String? filePath,         // chemin local de la pièce jointe (nullable)
    String? fileNameOverride, // nom original du fichier pour le Content-Type
  }) async {
    final fields = <String, String>{
      'psychologistId': '$psychologistId',
      'reason': reason,
      if (description != null && description.isNotEmpty)
        'description': description,
    };

    final json = await _api.postMultipartFields(
      ApiConstants.patientReports(patientId),
      fields: fields,
      filePath: filePath,
      fileFieldName: filePath != null ? 'file' : null,
      fileNameOverride: fileNameOverride,
    );
    return ReportModel.fromJson(json as Map<String, dynamic>);
  }
}
