import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_models.dart';

// appelle notification-service pour lire/marquer lues les notifs
// userId = patient ou psy selon le role du token
// utilise pour les notifs RDV (patient) et decision admin (psy)
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
