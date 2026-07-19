// reflete l'entite Notification de notification-service
enum AppNotificationType {
  appointment,
  reminder,
  payment,
  questionnaire,
  questionnaireResult,
  system,
  announcement, // broadcast admin → tous / patients / psys
  session,      // fin de session (normale ou urgence) — session-service
}

extension AppNotificationTypeX on AppNotificationType {
  static AppNotificationType fromApiValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'APPOINTMENT':
        return AppNotificationType.appointment;
      case 'REMINDER':
        return AppNotificationType.reminder;
      case 'PAYMENT':
        return AppNotificationType.payment;
      case 'QUESTIONNAIRE':
        return AppNotificationType.questionnaire;
      case 'QUESTIONNAIRE_RESULT':
        return AppNotificationType.questionnaireResult;
      case 'SYSTEM':
        return AppNotificationType.system;
      case 'ANNOUNCEMENT':
        return AppNotificationType.announcement;
      case 'SESSION':
        return AppNotificationType.session;
      default:
        // valeur inconnue, on plante pas l'ecran pour ca
        return AppNotificationType.system;
    }
  }

  // utilise pour le libelle des filtres dans NotificationsScreen
  String get label {
    switch (this) {
      case AppNotificationType.appointment:
        return 'Rendez-vous';
      case AppNotificationType.reminder:
        return 'Rappels';
      case AppNotificationType.payment:
        return 'Paiements';
      case AppNotificationType.questionnaire:
      case AppNotificationType.questionnaireResult:
        return 'Questionnaires';
      case AppNotificationType.system:
        return 'Système';
      case AppNotificationType.announcement:
        return 'Annonces';
      case AppNotificationType.session:
        return 'Sessions';
    }
  }
}

// correspond a la notif renvoyee par notification-service
// et PUT /notifications/{id}/read. nomme AppNotification (pas juste
// Notification) pour eviter une collision avec flutter/material.dart un jour
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
