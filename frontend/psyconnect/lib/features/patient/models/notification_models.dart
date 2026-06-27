/// Reflète l'entité `Notification` de notification-service
/// (backend/notification-service/.../entity/Notification.java).
enum AppNotificationType { appointment, reminder, system }

extension AppNotificationTypeX on AppNotificationType {
  static AppNotificationType fromApiValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'APPOINTMENT':
        return AppNotificationType.appointment;
      case 'REMINDER':
        return AppNotificationType.reminder;
      case 'SYSTEM':
        return AppNotificationType.system;
      default:
        // Le backend a un enum fermé, mais on reste tolérant côté client :
        // une valeur inattendue ne doit pas faire planter tout l'écran.
        return AppNotificationType.system;
    }
  }
}

/// Correspond à l'entité `Notification` renvoyée par
/// GET /notifications/user/{userId} et PUT /notifications/{id}/read.
///
/// Nommée `AppNotification` (pas `Notification`) pour éviter toute collision
/// avec `dart:ui`/`flutter/material.dart` qui n'exposent pas ce nom
/// aujourd'hui mais pourraient le faire — et pour rester explicite.
class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String message;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        userId: (json['userId'] as num).toInt(),
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        type: AppNotificationTypeX.fromApiValue(json['type'] as String?),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
      );
}
