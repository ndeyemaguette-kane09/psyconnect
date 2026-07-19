// note clinique privee (cf ClinicalNoteResponse cote user-service) :
// jamais visible par le patient ni par l'admin, et jamais par un autre
// psychologue meme s'il suit aussi ce patient - cf CDC section 6
class ClinicalNote {
  final int id;
  final int patientProfileId;
  final int? appointmentId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClinicalNote({
    required this.id,
    required this.patientProfileId,
    this.appointmentId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClinicalNote.fromJson(Map<String, dynamic> json) => ClinicalNote(
        id: (json['id'] as num).toInt(),
        patientProfileId: (json['patientProfileId'] as num).toInt(),
        appointmentId: json['appointmentId'] != null
            ? (json['appointmentId'] as num).toInt()
            : null,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

// corps pour POST/PUT note clinique
class CreateOrUpdateClinicalNoteRequest {
  final String content;
  final int? appointmentId;

  CreateOrUpdateClinicalNoteRequest({required this.content, this.appointmentId});

  Map<String, dynamic> toJson() => {
        'content': content,
        'appointmentId': appointmentId,
      };
}
