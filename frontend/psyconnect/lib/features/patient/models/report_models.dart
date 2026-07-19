// modèles pour le système de signalement psychologue
// le patient signale un psy à l'admin avec motif + description + preuve optionnelle

// motifs disponibles (miroir de l'enum ReportReason côté backend)
class ReportReasonOption {
  const ReportReasonOption({required this.value, required this.label});

  final String value;
  final String label;
}

const reportReasons = [
  ReportReasonOption(value: 'PRIX_ABUSIF', label: 'Tarif abusif'),
  ReportReasonOption(
      value: 'COMPORTEMENT_INAPPROPRIE', label: 'Comportement inapproprié'),
  ReportReasonOption(
      value: 'FAUSSES_INFORMATIONS',
      label: 'Fausses informations (diplômes, expérience)'),
  ReportReasonOption(
      value: 'DEMANDE_PAIEMENT_HORS_APP',
      label: 'Paiement demandé hors application'),
  ReportReasonOption(value: 'AUTRE', label: 'Autre'),
];

// réponse du backend après soumission ou lecture d'un signalement
class ReportModel {
  const ReportModel({
    required this.id,
    required this.patientProfileId,
    required this.psychologistProfileId,
    required this.reason,
    required this.reasonLabel,
    this.description,
    required this.hasEvidence,
    required this.status,
    this.adminNote,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int patientProfileId;
  final int psychologistProfileId;
  final String reason;
  final String reasonLabel;
  final String? description;
  final bool hasEvidence;
  final String status; // PENDING | REVIEWED | DISMISSED
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get statusLabel => switch (status) {
        'PENDING' => 'En attente',
        'REVIEWED' => 'Traité',
        'DISMISSED' => 'Rejeté',
        _ => status,
      };

  factory ReportModel.fromJson(Map<String, dynamic> json) => ReportModel(
        id: json['id'] as int,
        patientProfileId: json['patientProfileId'] as int,
        psychologistProfileId: json['psychologistProfileId'] as int,
        reason: json['reason'] as String,
        reasonLabel: json['reasonLabel'] as String? ?? json['reason'] as String,
        description: json['description'] as String?,
        hasEvidence: json['hasEvidence'] as bool? ?? false,
        status: json['status'] as String,
        adminNote: json['adminNote'] as String?,
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
      );

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw as String);
    } catch (_) {
      return null;
    }
  }
}
