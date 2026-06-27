import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/profile_models.dart';

/// Appelle les endpoints de user-service (via l'API Gateway) pour créer le
/// profil métier d'un utilisateur déjà authentifié :
/// POST /users, POST /patients, POST /psychologists.
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

  /// Retourne l'id du PatientProfile créé (pas le userProfileId) : c'est ce
  /// "patientId" qu'attend ensuite appointment-service.
  Future<int> createPatientProfile(
    CreatePatientProfileRequest request,
  ) async {
    final json = await _api.post(
      ApiConstants.patientProfiles,
      body: request.toJson(),
    );
    return ((json as Map<String, dynamic>)['id'] as num).toInt();
  }

  /// Retourne l'id du PsychologistProfile créé (pas le userProfileId).
  Future<int> createPsychologistProfile(
    CreatePsychologistProfileRequest request,
  ) async {
    final json = await _api.post(
      ApiConstants.psychologistProfiles,
      body: request.toJson(),
    );
    return ((json as Map<String, dynamic>)['id'] as num).toInt();
  }

  /// Envoie/remplace le justificatif (diplôme, carte professionnelle) joint
  /// à l'inscription d'un psychologue — appelé juste après
  /// [createPsychologistProfile] dans le flux d'onboarding (cf.
  /// AuthProvider#completePsychologistOnboarding). Best-effort volontaire :
  /// si l'upload échoue, le profil existe déjà (créé à l'étape précédente),
  /// donc on ne veut pas faire échouer tout l'onboarding pour ça — le
  /// psychologue pourra renvoyer son justificatif plus tard.
  Future<void> uploadPsychologistLicenseDocument(
    int psychologistProfileId,
    String filePath,
  ) async {
    await _api.postMultipart(
      ApiConstants.psychologistLicenseDocument(psychologistProfileId),
      fieldName: 'file',
      filePath: filePath,
    );
  }

  /// Lit le UserProfile "civil" (nom, téléphone, ville…) — utilisé par
  /// l'onglet Profil de l'accueil patient.
  Future<UserProfile> getUserProfileById(int id) async {
    final json = await _api.get('${ApiConstants.userProfiles}/$id');
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  /// Lit le PatientProfile (contact d'urgence, langue préférée…).
  Future<PatientProfile> getPatientProfileById(int id) async {
    final json = await _api.get('${ApiConstants.patientProfiles}/$id');
    return PatientProfile.fromJson(json as Map<String, dynamic>);
  }

  /// Résout le UserProfile.id (pas le PatientProfile.id/PsychologistProfile.id)
  /// à partir de l'authUserId du JWT — nécessaire pour l'onglet Profil
  /// (édition des infos civiles) lors d'une simple reconnexion, puisque
  /// login() ne le connaît pas non plus. Best-effort comme les méthodes
  /// ci-dessous : renvoie null si pas encore de UserProfile.
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

  /// Résout le PatientProfile.id à partir de l'authUserId du JWT, pour le cas
  /// d'un utilisateur déjà onboardé qui se reconnecte simplement (login()
  /// n'appelle jamais user-service, donc ne connaît pas ce id autrement).
  /// Renvoie null si l'utilisateur n'a pas (encore) de PatientProfile
  /// (ex. compte créé mais onboarding jamais terminé) plutôt que de
  /// propager l'erreur 404 : ce n'est pas bloquant pour login().
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

  /// Équivalent psychologue de [getPatientProfileIdByAuthUserId] — le
  /// backend expose le même endpoint en miroir (`GET
  /// /psychologists/by-auth-user/{authUserId}`, vérifié dans
  /// PsychologistProfileController). Best-effort comme pour le patient.
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

  /// Met à jour le UserProfile "civil" (nom, téléphone, ville…) — utilisé
  /// par l'édition de l'onglet Profil.
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

  /// Met à jour le PatientProfile (contact d'urgence, langue préférée, mode
  /// anonyme…). Utilisé par l'édition du Profil ET par l'écran Paramètres :
  /// dans les deux cas, l'appelant doit fournir l'état complet connu (pas
  /// seulement le champ qu'il modifie), cf. doc de [CreatePatientProfileRequest].
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
}
