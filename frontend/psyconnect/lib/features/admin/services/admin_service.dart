import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../models/admin_models.dart';

export '../../../core/network/api_client.dart' show DownloadedFile;

/// Appelle les endpoints /admin/** des 3 services (auth/user/appointment),
/// tous routés via l'API Gateway (cf. application.properties, routes
/// admin-auth-route / admin-user-route / admin-appointment-route).
class AdminService {
  AdminService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // --- Comptes (auth-service) ---

  Future<List<UserAccount>> listUsers() async {
    final json = await _api.get(ApiConstants.adminUsers);
    return (json as List)
        .map((e) => UserAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserAccount> setUserEnabled(int userId, bool enabled) async {
    final json = await _api.patch(
      ApiConstants.adminSetUserEnabled(userId, enabled),
    );
    return UserAccount.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminAccountStats> getAccountStats() async {
    final json = await _api.get(ApiConstants.adminStatsAccounts);
    return AdminAccountStats.fromJson(json as Map<String, dynamic>);
  }

  /// Suppression définitive d'un compte (irréversible — contrairement à
  /// [setUserEnabled], qui se renverse en un clic).
  Future<void> deleteUser(int userId) async {
    await _api.delete(ApiConstants.adminDeleteUser(userId));
  }

  /// Force un nouveau mot de passe pour un compte (utilisateur qui a perdu
  /// l'accès à son email, par exemple).
  Future<UserAccount> resetPassword(int userId, String newPassword) async {
    final json = await _api.patch(
      ApiConstants.adminResetPassword(userId),
      body: {'newPassword': newPassword},
    );
    return UserAccount.fromJson(json as Map<String, dynamic>);
  }

  // --- Profils (user-service) ---

  Future<List<PsychologistProfile>> listPsychologists() async {
    final json = await _api.get(ApiConstants.adminPsychologists);
    return (json as List)
        .map((e) => PsychologistProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PsychologistProfile> setPsychologistVerified(
    int psychologistId,
    bool verified,
  ) async {
    final json = await _api.patch(
      ApiConstants.adminSetPsychologistVerified(psychologistId, verified),
    );
    return PsychologistProfile.fromJson(json as Map<String, dynamic>);
  }

  /// Refuse (rejected=true) ou remet en attente (rejected=false) une
  /// demande de validation. Distinct de [setPsychologistVerified] : sur un
  /// profil déjà en attente, `verify?verified=false` est un no-op.
  Future<PsychologistProfile> setPsychologistRejected(
    int psychologistId,
    bool rejected,
  ) async {
    final json = await _api.patch(
      ApiConstants.adminSetPsychologistRejected(psychologistId, rejected),
    );
    return PsychologistProfile.fromJson(json as Map<String, dynamic>);
  }

  /// Récupère le justificatif (diplôme/carte pro) d'un psychologue, à
  /// afficher avant d'accepter/refuser sa demande de validation. Réservé
  /// côté backend au propriétaire OU à un ADMIN (cf. SecurityConfig).
  Future<DownloadedFile> downloadLicenseDocument(int psychologistId) {
    return _api.getFile(
      ApiConstants.psychologistLicenseDocument(psychologistId),
    );
  }

  Future<AdminProfileStats> getProfileStats() async {
    final json = await _api.get(ApiConstants.adminStatsProfiles);
    return AdminProfileStats.fromJson(json as Map<String, dynamic>);
  }

  // --- Rendez-vous & paiements (appointment-service) ---

  /// [status] doit être une valeur d'[AppointmentStatusX.apiValue]
  /// ('PENDING', 'CONFIRMED', ...) ou null pour ne pas filtrer.
  Future<List<Appointment>> listAppointments({String? status}) async {
    final json =
        await _api.get(ApiConstants.adminAppointmentsByStatus(status));
    return (json as List)
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Payment>> listPayments() async {
    final json = await _api.get(ApiConstants.adminPayments);
    return (json as List)
        .map((e) => Payment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminAppointmentStats> getAppointmentStats() async {
    final json = await _api.get(ApiConstants.adminStatsAppointments);
    return AdminAppointmentStats.fromJson(json as Map<String, dynamic>);
  }

  // --- Réglages plateforme (appointment-service) ---

  Future<PlatformSettings> getPlatformSettings() async {
    final json = await _api.get(ApiConstants.adminPlatformSettings);
    return PlatformSettings.fromJson(json as Map<String, dynamic>);
  }

  /// Règle le taux de commission (0-100) prélevé par la plateforme sur
  /// chaque paiement réussi — surfacé dans l'onglet Config.
  Future<PlatformSettings> setCommissionRate(
    double commissionRatePercent,
  ) async {
    final json = await _api.put(
      ApiConstants.adminSetCommissionRate(commissionRatePercent),
    );
    return PlatformSettings.fromJson(json as Map<String, dynamic>);
  }
}
