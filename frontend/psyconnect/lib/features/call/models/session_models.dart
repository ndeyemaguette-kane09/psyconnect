// reflete l'enum SessionStatus cote appointment-service
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

// session simulee cote backend (pas de vrai SDK Agora/WebRTC) :
// meetingToken c'est juste un texte SIM-AGORA-<uuid> genere au demarrage,
// jamais utilise par un vrai service de visio
class CallSession {
  final int id;
  // null pour les sessions d'urgence (pas de RDV associé)
  final int? appointmentId;
  final SessionStatus status;
  final String meetingToken;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final bool emergencyMode;

  CallSession({
    required this.id,
    this.appointmentId,
    required this.status,
    required this.meetingToken,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.emergencyMode = false,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) => CallSession(
        id: (json['id'] as num).toInt(),
        appointmentId: (json['appointmentId'] as num?)?.toInt(),
        status: SessionStatusX.fromApiValue(json['status'] as String),
        meetingToken: json['meetingToken'] as String,
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : null,
        endedAt: json['endedAt'] != null
            ? DateTime.parse(json['endedAt'] as String)
            : null,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        emergencyMode: json['emergencyMode'] as bool? ?? false,
      );
}
