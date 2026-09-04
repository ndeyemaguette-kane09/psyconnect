import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/models/user_role.dart';
import '../models/support_message_models.dart';

class SupportMessageService {
  SupportMessageService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<SupportMessageModel> submitMessage({
    required int profileId,
    required UserRole role,
    required String subject,
    required String message,
  }) async {
    final path = role == UserRole.patient
        ? ApiConstants.patientSupportMessages(profileId)
        : ApiConstants.psychologistSupportMessages(profileId);
    final json = await _api.post(
      path,
      body: {'subject': subject, 'message': message},
    );
    return SupportMessageModel.fromJson(json as Map<String, dynamic>);
  }
}
