import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_models.dart';
import '../models/profile_models.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    ProfileService? profileService,
  })  : _authService = authService ?? AuthService(),
        _profileService = profileService ?? ProfileService();

  final AuthService _authService;
  final ProfileService _profileService;

  AuthStatus status = AuthStatus.unknown;
  bool isLoading = false;
  String? errorMessage;
  Map<String, String> fieldErrors = {};
  // true quand la dernière erreur de connexion vient d'un compte banni (ACCOUNT_BANNED).
  // Utilisé par LoginScreen pour afficher une carte dédiée avec les coordonnées admin.
  bool isBannedAccount = false;
  bool licenseUploadWarning = false;

  AuthSession? session;

  Future<void> restoreSession() async {
    try {
      final token = await TokenStorage.readToken()
          .timeout(const Duration(seconds: 4));
      final role = await TokenStorage.readRole()
          .timeout(const Duration(seconds: 4));
      final userId = await TokenStorage.readUserId()
          .timeout(const Duration(seconds: 4));
      final pseudo = await TokenStorage.readPseudo()
          .timeout(const Duration(seconds: 4));
      final userProfileId = await TokenStorage.readUserProfileId()
          .timeout(const Duration(seconds: 4));
      final profileId = await TokenStorage.readProfileId()
          .timeout(const Duration(seconds: 4));

      if (token != null && role != null && userId != null && pseudo != null) {
        session = AuthSession(
          token: token,
          role: UserRoleX.fromApiValue(role),
          userId: userId,
          pseudo: pseudo,
          userProfileId: userProfileId,
          profileId: profileId,
        );
      status = AuthStatus.authenticated;
      } else {
        status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void _setError(Object error) {
    if (error is ApiException) {
      errorMessage = error.message;
      fieldErrors = error.fieldErrors;
      isBannedAccount = error.errorCode == 'ACCOUNT_BANNED';
    } else {
      errorMessage = error.toString();
      fieldErrors = {};
      isBannedAccount = false;
    }
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    fieldErrors = {};
    isBannedAccount = false;
    notifyListeners();
  }

  // Étape 1 : crée le compte sans ouvrir de session automatiquement.
  Future<bool> register({
    required UserRole role,
    required RegisterAccountRequest account,
  }) async {
    clearError();
    _setLoading(true);
    try {
      await _authService.register(role: role, request: account);
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    clearError();
    _setLoading(true);
    try {
      final newSession = await _authService.login(
        email: email,
        password: password,
      );
      await _persistSession(newSession);

      final userProfileId = await _profileService
          .getUserProfileIdByAuthUserId(newSession.userId);

      if (newSession.role == UserRole.patient) {
        final profileId = await _profileService
            .getPatientProfileIdByAuthUserId(newSession.userId);
        if (userProfileId != null || profileId != null) {
          await _persistProfileIds(
            userProfileId: userProfileId,
            profileId: profileId,
          );
        }
      } else if (newSession.role == UserRole.psychologist) {
        final profileId = await _profileService
            .getPsychologistProfileIdByAuthUserId(newSession.userId);
        if (userProfileId != null || profileId != null) {
          await _persistProfileIds(
            userProfileId: userProfileId,
            profileId: profileId,
          );
        }
      } else if (userProfileId != null) {
        await _persistProfileIds(userProfileId: userProfileId);
      }

      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> completePatientOnboarding({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? city,
    String? country,
    String? preferredLanguage,
    String? medicalHistory,
  }) async {
    clearError();
    _setLoading(true);
    try {
      final newSession = await _authService.login(
        email: email,
        password: password,
      );

      // Token persisté avant les appels suivants, sinon erreur 403.
      await _persistSession(newSession);

      final userProfile = await _profileService.createUserProfile(
        CreateUserProfileRequest(
          authUserId: newSession.userId,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          city: city,
          country: country,
        ),
      );

      final patientProfileId = await _profileService.createPatientProfile(
        CreatePatientProfileRequest(
          userProfileId: userProfile.id,
          preferredLanguage: preferredLanguage,
          medicalHistory: medicalHistory,
        ),
      );

      // Nécessaire pour réserver un RDV : l'API attend le PatientProfile.id, pas l'authUserId.
      await _persistProfileIds(
        userProfileId: userProfile.id,
        profileId: patientProfileId,
      );

      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Même flux que le patient, avec les champs supplémentaires du psychologue.
  Future<bool> completePsychologistOnboarding({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String specialty,
    String? city,
    String? country,
    String? address,
    int? yearsOfExperience,
    int? consultationPrice,
    String? licenseNumber,
    // chemin local du justificatif (file_picker), envoye apres creation du profil
    String? licenseDocumentPath,
    // nom ORIGINAL du fichier choisi (picked.name) : indispensable pour que
    // le bon Content-Type soit envoye (cf. ApiClient._guessMediaType),
    // licenseDocumentPath seul peut etre un chemin temporaire iOS sans
    // extension fiable
    String? licenseDocumentName,
  }) async {
    clearError();
    _setLoading(true);
    licenseUploadWarning = false;
    try {
      final newSession = await _authService.login(
        email: email,
        password: password,
      );

      // Token persisté avant tout appel authentifié, sinon erreur 403.
      await _persistSession(newSession);

      final userProfile = await _profileService.createUserProfile(
        CreateUserProfileRequest(
          authUserId: newSession.userId,
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          city: city,
          country: country,
        ),
      );

      final psychologistProfileId =
          await _profileService.createPsychologistProfile(
        CreatePsychologistProfileRequest(
          userProfileId: userProfile.id,
          specialty: specialty,
          city: city,
          address: address,
          yearsOfExperience: yearsOfExperience,
          consultationPrice: consultationPrice,
          licenseNumber: licenseNumber,
        ),
      );

      await _persistProfileIds(
        userProfileId: userProfile.id,
        profileId: psychologistProfileId,
      );

      if (licenseDocumentPath != null) {
        try {
          await _profileService.uploadPsychologistLicenseDocument(
            psychologistProfileId,
            licenseDocumentPath,
            fileName: licenseDocumentName,
          );
        } catch (_) {
          licenseUploadWarning = true;
        }
      }

      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _persistSession(AuthSession newSession) async {
    session = newSession;
    status = AuthStatus.authenticated;
    await TokenStorage.saveSession(
      token: newSession.token,
      role: newSession.role.apiValue,
      userId: newSession.userId,
      pseudo: newSession.pseudo,
    );
    notifyListeners();
  }

  // saveProfileIds() efface la valeur stockée si on lui passe null ; on
  // conserve donc la valeur déjà en session pour ne pas perdre un id existant.
  Future<void> _persistProfileIds({int? userProfileId, int? profileId}) async {
    final resolvedUserProfileId = userProfileId ?? session?.userProfileId;
    final resolvedProfileId = profileId ?? session?.profileId;

    if (session != null) {
      session = session!.copyWith(
        userProfileId: resolvedUserProfileId,
        profileId: resolvedProfileId,
      );
    }
    await TokenStorage.saveProfileIds(
      userProfileId: resolvedUserProfileId,
      profileId: resolvedProfileId,
    );
    notifyListeners();
  }

  Future<bool> forgotPassword({required String email}) async {
    clearError();
    _setLoading(true);
    try {
      await _authService.forgotPassword(email: email);
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    clearError();
    _setLoading(true);
    try {
      await _authService.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updatePseudo(String newPseudo) async {
    final current = session;
    if (current == null) return false;
    clearError();
    _setLoading(true);
    try {
      await _authService.updatePseudo(newPseudo);
      await _persistSession(current.copyWith(pseudo: newPseudo));
      return true;
    } catch (e) {
      _setError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    session = null;
    status = AuthStatus.unauthenticated;
    await TokenStorage.clear();
    notifyListeners();
  }
}
