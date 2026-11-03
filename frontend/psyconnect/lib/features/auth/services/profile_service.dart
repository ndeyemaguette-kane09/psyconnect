import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../patient/models/psychologist_models.dart';
import '../models/profile_models.dart';

// appelle user-service pour creer le profil d'un utilisateur deja connecte
class ProfileService {
  ProfileService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<UserProfile> createUserProfile(
    CreateUserProfileRequest request,
  ) async {
    final json = await _api.post(
      ApiConstants.userProfiles,
      body: request.toJson(),
    );
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  // renvoie l'id du PatientProfile cree (pas le userProfileId), c'est ce
  // "patientId" qu'attend appointment-service ensuite
  Future<int> createPatientProfile(
    CreatePatientProfileRequest request,
  ) async {
    final json = await _api.post(
      ApiConstants.patientProfiles,
      body: request.toJson(),
    );
    return ((json as Map<String, dynamic>)['id'] as num).toInt();
  }

  // renvoie l'id du PsychologistProfile cree (pas le userProfileId)
  Future<int> createPsychologistProfile(
    CreatePsychologistProfileRequest request,
  ) async {
    final json = await _api.post(
      ApiConstants.psychologistProfiles,
      body: request.toJson(),
    );
    return ((json as Map<String, dynamic>)['id'] as num).toInt();
  }

  // envoie ou remplace le justificatif du psy. si ca rate, le profil
  // existe deja donc ca bloque pas, le psy pourra renvoyer plus tard
  Future<void> uploadPsychologistLicenseDocument(
    int psychologistProfileId,
    String filePath, {
    // nom d'origine du fichier : sur iOS le chemin temporaire peut perdre
    // l'extension, et le Content-Type serait faux
    String? fileName,
  }) async {
    await _api.postMultipart(
      ApiConstants.psychologistLicenseDocument(psychologistProfileId),
      fieldName: 'file',
      filePath: filePath,
      fileNameOverride: fileName,
      // justificatif jusqu'à 20 Mo, 15 s ne suffisent pas sur un réseau lent
      timeout: ApiConstants.licenseUploadTimeout,
    );
  }

  // lit le UserProfile "civil" (nom, tel, ville...), utilise par l'onglet
  // Profil de l'accueil patient
  Future<UserProfile> getUserProfileById(int id) async {
    final json = await _api.get('${ApiConstants.userProfiles}/$id');
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  // lit le PatientProfile (contact d'urgence, langue preferee...)
  Future<PatientProfile> getPatientProfileById(int id) async {
    final json = await _api.get('${ApiConstants.patientProfiles}/$id');
    return PatientProfile.fromJson(json as Map<String, dynamic>);
  }

  // resout UserProfile.id a partir de l'authUserId (login() le connait pas).
  // best-effort : null si pas encore de UserProfile
  Future<int?> getUserProfileIdByAuthUserId(int authUserId) async {
    try {
      final json = await _api.get(
        ApiConstants.userProfileByAuthUser(authUserId),
      );
      return ((json as Map<String, dynamic>)['id'] as num).toInt();
    } catch (_) {
      return null;
    }
  }

  // trouve PatientProfile.id a partir de l'authUserId, renvoie null si pas
  // encore de profil (inscription pas finie) au lieu de faire planter avec un 404
  Future<int?> getPatientProfileIdByAuthUserId(int authUserId) async {
    try {
      final json = await _api.get(
        ApiConstants.patientProfileByAuthUser(authUserId),
      );
      return ((json as Map<String, dynamic>)['id'] as num).toInt();
    } catch (_) {
      return null;
    }
  }

  // equivalent psy de getPatientProfileIdByAuthUserId
  Future<int?> getPsychologistProfileIdByAuthUserId(int authUserId) async {
    try {
      final json = await _api.get(
        ApiConstants.psychologistProfileByAuthUser(authUserId),
      );
      return ((json as Map<String, dynamic>)['id'] as num).toInt();
    } catch (_) {
      return null;
    }
  }

  // Sert à vérifier le statut de validation lors de la restauration d'une
  // session psychologue déjà stockée sur l'appareil.
  Future<PsychologistProfile?> getPsychologistProfileByAuthUserId(
    int authUserId,
  ) async {
    try {
      final json = await _api.get(
        ApiConstants.psychologistProfileByAuthUser(authUserId),
      );
      return PsychologistProfile.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // met a jour le UserProfile "civil", utilise par l'edition du Profil
  Future<UserProfile> updateUserProfile(
    int id,
    UpdateUserProfileRequest request,
  ) async {
    final json = await _api.put(
      '${ApiConstants.userProfiles}/$id',
      body: request.toJson(),
    );
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  // met a jour PatientProfile, utilise par edition Profil et Parametres :
  // faut renvoyer toutes les infos connues, pas juste le champ change
  Future<PatientProfile> updatePatientProfile(
    int id,
    CreatePatientProfileRequest request,
  ) async {
    final json = await _api.put(
      '${ApiConstants.patientProfiles}/$id',
      body: request.toJson(),
    );
    return PatientProfile.fromJson(json as Map<String, dynamic>);
  }

  // le backend réutilise CreatePsychologistProfileRequest : on renvoie tout le profil
  Future<PsychologistProfile> updatePsychologistProfile(
    int id,
    CreatePsychologistProfileRequest request,
  ) async {
    final json = await _api.put(
      '${ApiConstants.psychologistProfiles}/$id',
      body: request.toJson(),
    );
    return PsychologistProfile.fromJson(json as Map<String, dynamic>);
  }
}
