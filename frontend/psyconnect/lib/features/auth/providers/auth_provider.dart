import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_models.dart';
import '../models/profile_models.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Centralise tout le flux d'authentification / onboarding pour l'app :
/// 1) register (auth-service)            -> compte créé, pas encore connecté
/// 2) login (auth-service)                -> JWT + userId + role + pseudo
/// 3) createUserProfile (user-service)    -> profil "civil" (nom, tel, etc.)
/// 4) createPatientProfile / createPsychologistProfile (user-service)
///
/// Exposé via Provider pour que les écrans réagissent à isLoading/error/
/// session sans avoir à gérer eux-mêmes les appels réseau.
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

  AuthSession? session;

  /// À appeler au démarrage de l'app pour restaurer une session existante.
  /// Toute erreur de lecture du stockage sécurisé (plateforme indisponible,
  /// keychain verrouillé, etc.) est traitée comme "pas de session" plutôt
  /// que de faire planter le démarrage de l'app.
  ///
  /// Le `.timeout(...)` est une protection : sur iOS, une lecture Keychain
  /// peut rester bloquée (ex. après un changement de Team/Bundle ID en
  /// signing) et `await` ne reviendrait alors jamais, ce qui laisserait
  /// l'app coincée indéfiniment sur l'écran de chargement initial (`_Root`
  /// dans app.dart) tant que `status` reste `AuthStatus.unknown` — perçu par
  /// l'utilisateur comme un écran blanc figé.
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
    } else {
      errorMessage = error.toString();
      fieldErrors = {};
    }
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    fieldErrors = {};
    notifyListeners();
  }

  /// Étape 1 : crée le compte. Ne connecte pas automatiquement.
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

  /// Étape 2 : login simple, utilisé par l'écran de connexion.
  ///
  /// login() (auth-service) ne renvoie que l'authUserId, jamais le
  /// UserProfile.id ni le PatientProfile.id/PsychologistProfile.id dont a
  /// besoin la suite (appointment-service attend patientId/psychologistId,
  /// pas authUserId ; l'onglet Profil attend userProfileId pour
  /// éditer/afficher les infos civiles). Pour un compte déjà onboardé, on
  /// les résout donc ici via GET /users/by-auth-user/{authUserId} et
  /// GET /patients/by-auth-user/{authUserId} ou
  /// GET /psychologists/by-auth-user/{authUserId} selon le rôle. Best-effort :
  /// si ça échoue (pas encore de profil, service indisponible...), on
  /// n'empêche pas la connexion — `userProfileId`/`profileId` resteront
  /// juste null jusqu'à ce qu'ils soient nécessaires.
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

  /// Flux complet d'inscription patient : login juste après le register
  /// (pour récupérer le JWT + userId), puis création du UserProfile et du
  /// PatientProfile. Si une étape échoue, errorMessage est renseigné et on
  /// s'arrête : l'utilisateur reste sur l'écran pour réessayer (le compte
  /// auth existe déjà, donc on rejoue juste login + profils).
  Future<bool> completePatientOnboarding({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? city,
    String? country,
  }) async {
    clearError();
    _setLoading(true);
    try {
      final newSession = await _authService.login(
        email: email,
        password: password,
      );

      // Le token doit être persisté AVANT les appels suivants : ApiClient lit
      // le token depuis TokenStorage (pas depuis `session` en mémoire), donc
      // sans ça les requêtes createUserProfile/createPatientProfile partent
      // sans header Authorization -> 403 côté backend.
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
        CreatePatientProfileRequest(userProfileId: userProfile.id),
      );

      // Nécessaire pour la prise de RDV plus tard (POST /appointments
      // attend le PatientProfile.id, pas l'authUserId du JWT).
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

  /// Même principe pour un psychologue, avec les champs spécifiques au
  /// PsychologistProfile (spécialité obligatoire côté backend pour que le
  /// profil ait un sens, même si le DTO ne l'impose pas explicitement).
  Future<bool> completePsychologistOnboarding({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String specialty,
    String? city,
    String? country,
    int? yearsOfExperience,
    int? consultationPrice,
    String? licenseNumber,
    // Chemin local (device) du justificatif choisi avec file_picker — envoyé
    // après la création du profil, cf. note "best-effort" plus bas.
    String? licenseDocumentPath,
  }) async {
    clearError();
    _setLoading(true);
    try {
      final newSession = await _authService.login(
        email: email,
        password: password,
      );

      // Cf. completePatientOnboarding : le token doit être persisté avant
      // tout appel authentifié, sinon ApiClient part sans Authorization -> 403.
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
          yearsOfExperience: yearsOfExperience,
          consultationPrice: consultationPrice,
          licenseNumber: licenseNumber,
        ),
      );

      await _persistProfileIds(
        userProfileId: userProfile.id,
        profileId: psychologistProfileId,
      );

      // Best-effort : le profil existe déjà à ce stade, donc on ne fait pas
      // échouer tout l'onboarding si seul l'envoi du justificatif rate
      // (réseau, fichier trop gros…) — le psychologue pourra le renvoyer
      // plus tard depuis son profil.
      if (licenseDocumentPath != null) {
        try {
          await _profileService.uploadPsychologistLicenseDocument(
            psychologistProfileId,
            licenseDocumentPath,
          );
        } catch (_) {}
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

  /// TokenStorage.saveProfileIds() écrase/efface la valeur stockée pour tout
  /// paramètre null (pas de sémantique "patch" côté disque, contrairement à
  /// copyWith côté session en mémoire). Pour éviter d'effacer un id déjà
  /// connu suite à un échec transitoire d'une seule résolution
  /// (ex. getUserProfileIdByAuthUserId échoue mais getPatientProfileIdByAuthUserId
  /// réussit), on retombe ici aussi sur la valeur déjà en session avant
  /// d'écrire sur le disque.
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

  Future<void> logout() async {
    session = null;
    status = AuthStatus.unauthenticated;
    await TokenStorage.clear();
    notifyListeners();
  }
}
