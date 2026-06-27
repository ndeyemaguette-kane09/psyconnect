/// Sérialise un `DateTime` local en ISO-8601 sans suffixe de zone, attendu
/// par les `LocalDateTime` côté Java (partagé par [CreateAppointmentRequest]
/// et [RescheduleAppointmentRequest]).
String isoLocalDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}'
      'T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

/// Reflète l'enum `ConsultationType` de appointment-service
/// (backend/appointment-service/.../entity/ConsultationType.java).
enum ConsultationType { video, audio, chat, physical }

extension ConsultationTypeX on ConsultationType {
  String get apiValue {
    switch (this) {
      case ConsultationType.video:
        return 'VIDEO';
      case ConsultationType.audio:
        return 'AUDIO';
      case ConsultationType.chat:
        return 'CHAT';
      case ConsultationType.physical:
        return 'PHYSICAL';
    }
  }

  String get label {
    switch (this) {
      case ConsultationType.video:
        return 'Vidéo';
      case ConsultationType.audio:
        return 'Audio';
      case ConsultationType.chat:
        return 'Chat';
      case ConsultationType.physical:
        return 'Cabinet';
    }
  }

  static ConsultationType fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'VIDEO':
        return ConsultationType.video;
      case 'AUDIO':
        return ConsultationType.audio;
      case 'CHAT':
        return ConsultationType.chat;
      case 'PHYSICAL':
        return ConsultationType.physical;
      default:
        throw ArgumentError('Type de consultation inconnu: $value');
    }
  }
}

/// Reflète l'enum `AppointmentStatus` de appointment-service.
enum AppointmentStatus { pending, confirmed, completed, cancelled, rejected }

extension AppointmentStatusX on AppointmentStatus {
  /// Valeur attendue par le backend (query param `?status=` de
  /// PUT /appointments/{id}/status, cf. AppointmentService).
  String get apiValue {
    switch (this) {
      case AppointmentStatus.pending:
        return 'PENDING';
      case AppointmentStatus.confirmed:
        return 'CONFIRMED';
      case AppointmentStatus.completed:
        return 'COMPLETED';
      case AppointmentStatus.cancelled:
        return 'CANCELLED';
      case AppointmentStatus.rejected:
        return 'REJECTED';
    }
  }

  String get label {
    switch (this) {
      case AppointmentStatus.pending:
        return 'En attente';
      case AppointmentStatus.confirmed:
        return 'Confirmé';
      case AppointmentStatus.completed:
        return 'Terminé';
      case AppointmentStatus.cancelled:
        return 'Annulé';
      case AppointmentStatus.rejected:
        return 'Refusé';
    }
  }

  static AppointmentStatus fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return AppointmentStatus.pending;
      case 'CONFIRMED':
        return AppointmentStatus.confirmed;
      case 'COMPLETED':
        return AppointmentStatus.completed;
      case 'CANCELLED':
        return AppointmentStatus.cancelled;
      case 'REJECTED':
        return AppointmentStatus.rejected;
      default:
        throw ArgumentError('Statut de RDV inconnu: $value');
    }
  }
}

/// Correspond à CreateAppointmentRequest côté appointment-service
/// (POST /appointments). `startTime`/`endTime` sont sérialisés en
/// ISO-8601 sans suffixe de zone (LocalDateTime côté Java) — il faut donc
/// construire les DateTime localement (pas en UTC).
class CreateAppointmentRequest {
  final int patientId;
  final int psychologistId;
  final DateTime startTime;
  final DateTime endTime;
  final ConsultationType consultationType;

  CreateAppointmentRequest({
    required this.patientId,
    required this.psychologistId,
    required this.startTime,
    required this.endTime,
    required this.consultationType,
  });

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'psychologistId': psychologistId,
        'startTime': isoLocalDateTime(startTime),
        'endTime': isoLocalDateTime(endTime),
        'consultationType': consultationType.apiValue,
      };
}

/// Correspond à RescheduleAppointmentRequest côté appointment-service
/// (PUT /appointments/{id}/reschedule).
class RescheduleAppointmentRequest {
  final DateTime newStartTime;
  final DateTime newEndTime;

  RescheduleAppointmentRequest({
    required this.newStartTime,
    required this.newEndTime,
  });

  Map<String, dynamic> toJson() => {
        'newStartTime': isoLocalDateTime(newStartTime),
        'newEndTime': isoLocalDateTime(newEndTime),
      };
}

/// Correspond à AppointmentResponse côté appointment-service.
class Appointment {
  final int id;
  final int patientId;
  final int psychologistId;
  final DateTime startTime;
  final DateTime endTime;
  final ConsultationType consultationType;
  final AppointmentStatus status;

  // Date de création du RDV — distincte de [startTime] (qui change lors
  // d'un report). Utilisée pour trier l'agenda "par date d'ajout" plutôt
  // que par date du créneau. Absente sur les très anciens RDV créés avant
  // l'ajout de ce champ côté backend : repli sur [startTime] dans ce cas.
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.patientId,
    required this.psychologistId,
    required this.startTime,
    required this.endTime,
    required this.consultationType,
    required this.status,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final startTime = DateTime.parse(json['startTime'] as String);
    return Appointment(
      id: (json['id'] as num).toInt(),
      patientId: (json['patientId'] as num).toInt(),
      psychologistId: (json['psychologistId'] as num).toInt(),
      startTime: startTime,
      endTime: DateTime.parse(json['endTime'] as String),
      consultationType:
          ConsultationTypeX.fromApiValue(json['consultationType'] as String),
      status: AppointmentStatusX.fromApiValue(json['status'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : startTime,
    );
  }
}
