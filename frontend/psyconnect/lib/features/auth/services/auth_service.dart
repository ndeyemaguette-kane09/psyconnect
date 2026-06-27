import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';
import '../models/user_role.dart';

/// Appelle les endpoints de auth-service (via l'API Gateway) :
/// POST /auth/register/patient, /auth/register/psy, /auth/login.
class AuthService {
  AuthService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// Crée le compte (auth-service) pour le rôle donné. Ne crée PAS encore
  /// le profil métier (UserProfile / PatientProfile / PsychologistProfile),
  /// qui se fait après login car il faut le JWT + userId.
  Future<void> register({
    required UserRole role,
    required RegisterAccountRequest request,
  }) async {
    final path = role == UserRole.psychologist
        ? ApiConstants.registerPsychologist
        : ApiConstants.registerPatient;

    await _api.post(path, body: request.toJson(), withAuth: false);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      ApiConstants.login,
      body: {'email': email, 'password': password},
      withAuth: false,
    );
    return AuthSession.fromJson(json as Map<String, dynamic>);
  }
}
