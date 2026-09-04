import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../../patient/models/report_models.dart';
import '../../patient/models/support_message_models.dart';
import '../models/admin_models.dart';

export '../../../core/network/api_client.dart' show DownloadedFile;

// appelle les endpoints /admin/** des 3 services (auth/user/appointment),
// tous routes via l'API Gateway
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

  // suppression definitive, irreversible (contrairement a setUserEnabled)
  Future<void> deleteUser(int userId) async {
    await _api.delete(ApiConstants.adminDeleteUser(userId));
  }

  // force un nouveau mot de passe (cas typique : user qui a perdu son email)
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

  // refuse ou remet en attente. pas pareil que setPsychologistVerified : sur un
  // profil deja en attente, verify?verified=false ne fait rien
  Future<PsychologistProfile> setPsychologistRejected(
    int psychologistId,
    bool rejected,
  ) async {
    final json = await _api.patch(
      ApiConstants.adminSetPsychologistRejected(psychologistId, rejected),
    );
    return PsychologistProfile.fromJson(json as Map<String, dynamic>);
  }

  // recupere le justificatif (diplome/carte pro), a montrer avant d'accepter
  // ou refuser. cote backend, seul le proprietaire ou un admin peut y acceder
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

  // status = valeur d'AppointmentStatusX.apiValue ('PENDING', 'CONFIRMED', ...)
  // ou null pour pas filtrer
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

  // les stats RDV (appointment-service) et paiement/commission (payment-service)
  // sont sur deux endpoints distincts depuis l'extraction du paiement en
  // microservice a part ; on les recupere en parallele et on fusionne les
  // deux JSON pour que le reste de l'app (AdminAppointmentStats) n'ait rien
  // a changer
  Future<AdminAppointmentStats> getAppointmentStats() async {
    final results = await Future.wait([
      _api.get(ApiConstants.adminStatsAppointments),
      _api.get(ApiConstants.adminStatsPayments),
    ]);
    final merged = <String, dynamic>{
      ...(results[0] as Map<String, dynamic>),
      ...(results[1] as Map<String, dynamic>),
    };
    return AdminAppointmentStats.fromJson(merged);
  }

  // --- Signalements psychologues (user-service) ---

  // status = 'PENDING' | 'REVIEWED' | 'DISMISSED' | null (tous)
  Future<List<ReportModel>> listReports({String? status}) async {
    final path = status == null
        ? ApiConstants.adminReports
        : '${ApiConstants.adminReports}?status=$status';
    final json = await _api.get(path);
    return (json as List)
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // traite un signalement : status = 'REVIEWED' ou 'DISMISSED', adminNote optionnel
  Future<ReportModel> reviewReport(
    int reportId, {
    required String status,
    String? adminNote,
  }) async {
    final json = await _api.patch(
      ApiConstants.adminReport(reportId),
      body: {
        'status': status,
        if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
      },
    );
    return ReportModel.fromJson(json as Map<String, dynamic>);
  }

  // télécharge la pièce jointe (photo/PDF) d'un signalement
  Future<DownloadedFile> downloadReportEvidence(int reportId) {
    return _api.getFile(ApiConstants.adminReportEvidence(reportId));
  }

  // --- Messages "Contacter l'administrateur" (user-service) ---

  // status = 'PENDING' | 'RESOLVED' | null (tous)
  Future<List<SupportMessageModel>> listSupportMessages({String? status}) async {
    final path = status == null
        ? ApiConstants.adminSupportMessages
        : '${ApiConstants.adminSupportMessages}?status=$status';
    final json = await _api.get(path);
    return (json as List)
        .map((e) => SupportMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // status = 'RESOLVED' pour marquer comme traité, 'PENDING' pour rouvrir
  Future<SupportMessageModel> resolveSupportMessage(
    int messageId, {
    required String status,
    String? adminNote,
  }) async {
    final json = await _api.patch(
      ApiConstants.adminSupportMessage(messageId),
      body: {
        'status': status,
        if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
      },
    );
    return SupportMessageModel.fromJson(json as Map<String, dynamic>);
  }

  // envoie une vraie réponse à l'expéditeur : elle est stockée sur le ticket
  // ET déclenche une notification (via NotificationClient côté user-service)
  // à destination du patient/psychologue concerné. Passe le ticket en RESOLVED.
  Future<SupportMessageModel> replyToSupportMessage(
    int messageId, {
    required String reply,
  }) async {
    final json = await _api.post(
      ApiConstants.adminSupportMessageReply(messageId),
      body: {'reply': reply},
    );
    return SupportMessageModel.fromJson(json as Map<String, dynamic>);
  }

  // --- Communication admin → utilisateurs (broadcast) ---

  // envoie une annonce à l'audience cible (ALL | PATIENTS | PSYCHOLOGISTS)
  // retourne le nombre de destinataires atteints
  Future<int> broadcastNotification({
    required String title,
    required String message,
    required String audience,
  }) async {
    final json = await _api.post(
      ApiConstants.adminBroadcast,
      body: {'title': title, 'message': message, 'audience': audience},
    );
    return (json as Map<String, dynamic>)['sent'] as int? ?? 0;
  }

  // --- Réglages plateforme (appointment-service) ---

  Future<PlatformSettings> getPlatformSettings() async {
    final json = await _api.get(ApiConstants.adminPlatformSettings);
    return PlatformSettings.fromJson(json as Map<String, dynamic>);
  }

  // taux de commission (0-100) pris par la plateforme sur chaque paiement
  // reussi, modifiable depuis l'onglet Config
  Future<PlatformSettings> setCommissionRate(
    double commissionRatePercent,
  ) async {
    final json = await _api.put(
      ApiConstants.adminSetCommissionRate(commissionRatePercent),
    );
    return PlatformSettings.fromJson(json as Map<String, dynamic>);
  }
}
