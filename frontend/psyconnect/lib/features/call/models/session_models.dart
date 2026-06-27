/// Reflète l'enum `SessionStatus` de appointment-service.
enum SessionStatus { inProgress, completed, cancelled }

extension SessionStatusX on SessionStatus {
  static SessionStatus fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'IN_PROGRESS':
        return SessionStatus.inProgress;
      case 'COMPLETED':
        return SessionStatus.completed;
      case 'CANCELLED':
        return SessionStatus.cancelled;
      default:
        throw ArgumentError('Statut de session inconnu: $value');
    }
  }
}

/// Correspond à SessionResponse côté appointment-service. La session est
/// entièrement simulée côté backend (pas de SDK Agora/WebRTC réel) :
/// [meetingToken] est une chaîne `SIM-AGORA-<uuid>` générée au démarrage,
/// jamais utilisée par un vrai service de visio.
class CallSession {
  final int id;
  final int appointmentId;
  final SessionStatus status;
  final String meetingToken;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  CallSession({
    required this.id,
    required this.appointmentId,
    required this.status,
    required this.meetingToken,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) => CallSession(
        id: (json['id'] as num).toInt(),
        appointmentId: (json['appointmentId'] as num).toInt(),
        status: SessionStatusX.fromApiValue(json['status'] as String),
        meetingToken: json['meetingToken'] as String,
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : null,
        endedAt: json['endedAt'] != null
            ? DateTime.parse(json['endedAt'] as String)
            : null,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      );
}
