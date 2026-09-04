import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';
import '../models/user_role.dart';

// appelle les endpoints de auth :
// POST /auth/register/patient, /auth/register/psy, /auth/login
class AuthService {
  AuthService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // cree le compte pour le role donne. cree pas le profil tout de suite
  // (UserProfile/PatientProfile/PsychologistProfile), ca vient apres
  // le login car on a besoin du token et de l'id.
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

  // renvoie le code de dev (devCode) tant qu'aucun envoi d'email reel n'est
  // branche cote backend ; null une fois ce mode desactive (voir
  // AuthService.forgotPassword cote auth-service)
  Future<String?> forgotPassword({required String email}) async {
    final json = await _api.post(
      ApiConstants.forgotPassword,
      body: {'email': email},
      withAuth: false,
    );
    final map = json as Map<String, dynamic>;
    return map['devCode'] as String?;
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post(
      ApiConstants.resetPassword,
      body: {'email': email, 'code': code, 'newPassword': newPassword},
      withAuth: false,
    );
  }

  Future<void> updatePseudo(String pseudo) async {
    await _api.post(
      ApiConstants.updatePseudo,
      body: {'pseudo': pseudo},
    );
  }
}
