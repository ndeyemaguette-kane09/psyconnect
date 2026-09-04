class SupportMessageModel {
  const SupportMessageModel({
    required this.id,
    required this.senderProfileId,
    required this.senderRole,
    required this.subject,
    required this.message,
    required this.status,
    this.senderName,
    this.senderPhone,
    this.adminNote,
    this.adminReply,
    this.repliedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int senderProfileId;
  final String senderRole;
  final String subject;
  final String message;
  final String status;
  final String? senderName;
  final String? senderPhone;
  final String? adminNote;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get statusLabel => switch (status) {
        'PENDING' => 'En attente',
        'RESOLVED' => 'Traité',
        _ => status,
      };

  String get senderRoleLabel => switch (senderRole) {
        'PATIENT' => 'Patient',
        'PSYCHOLOGIST' => 'Psychologue',
        _ => senderRole,
      };

  String get senderDisplayName =>
      senderName != null && senderName!.trim().isNotEmpty
          ? senderName!
          : '$senderRoleLabel #$senderProfileId';

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) =>
      SupportMessageModel(
        id: json['id'] as int,
        senderProfileId: json['senderProfileId'] as int,
        senderRole: json['senderRole'] as String,
        subject: json['subject'] as String,
        message: json['message'] as String,
        status: json['status'] as String,
        senderName: json['senderName'] as String?,
        senderPhone: json['senderPhone'] as String?,
        adminNote: json['adminNote'] as String?,
        adminReply: json['adminReply'] as String?,
        repliedAt: _parseDate(json['repliedAt']),
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
