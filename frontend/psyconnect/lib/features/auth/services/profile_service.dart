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
    // nom ORIGINAL du fichier (avant file_picker ne le copie dans un
    // chemin temporaire potentiellement sans extension sur iOS) : sert a
    // deviner le bon Content-Type cote ApiClient. Sans lui, un fichier
    // PNG/JPEG peut etre envoye en "application/octet-stream" et rejete
    // par user-service ("Format non supporté").
    String? fileName,
  }) async {
    await _api.postMultipart(
      ApiConstants.psychologistLicenseDocument(psychologistProfileId),
      fieldName: 'file',
      filePath: filePath,
      fileNameOverride: fileName,
      // photo/PDF de diplome jusqu'a 20MB (cf. backend) : le timeout par
      // defaut de 15s est trop court sur un reseau lent, d'ou ce timeout
      // dedie (meme principe que companionChatTimeout)
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

  // met a jour PsychologistProfile. reutilise CreatePsychologistProfileRequest
  // cote backend (pas de DTO d'update dedie) : faut renvoyer toutes les
  // infos connues, pas juste le champ change. seul le proprietaire du
  // profil peut le faire (verifie cote backend via authUserId)
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
