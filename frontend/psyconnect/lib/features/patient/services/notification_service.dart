import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_models.dart';

/// Appelle les endpoints de notification-service (via l'API Gateway) :
/// GET /notifications/user/{userId}, PUT /notifications/{id}/read.
///
/// Côté backend, `userId` est soit un PatientProfile.id (rôle PATIENT) soit
/// un PsychologistProfile.id (rôle PSYCHOLOGIST) — `OwnershipResolver`
/// résout la propriété selon le rôle du jeton courant. Utilisé pour les
/// notifications patient (RDV) et psychologue (décision admin de
/// validation/refus).
class NotificationService {
  NotificationService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<AppNotification>> getNotificationsByUserId(
    int userId,
  ) async {
    final json = await _api.get(ApiConstants.notificationsByUser(userId));
    return (json as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppNotification> markAsRead(int notificationId) async {
    final json = await _api.put(ApiConstants.notificationRead(notificationId));
    return AppNotification.fromJson(json as Map<String, dynamic>);
  }
}
