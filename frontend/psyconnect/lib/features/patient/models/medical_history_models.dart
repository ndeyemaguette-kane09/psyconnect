// antecedents medicaux structures (cf MedicalHistoryResponse cote user-service)
// editable par le patient ET par un psy qui le suit, jamais visible par l'admin
class MedicalHistory {
  final int patientId;
  final String? allergies;
  final String? chronicConditions;
  final String? currentTreatments;
  final String? psychiatricHistory;
  final DateTime? updatedAt;
  final String? lastUpdatedByRole;

  MedicalHistory({
    required this.patientId,
    this.allergies,
    this.chronicConditions,
    this.currentTreatments,
    this.psychiatricHistory,
    this.updatedAt,
    this.lastUpdatedByRole,
  });

  // tout est vide quand rien n'a encore ete renseigne
  bool get isEmpty =>
      (allergies == null || allergies!.trim().isEmpty) &&
      (chronicConditions == null || chronicConditions!.trim().isEmpty) &&
      (currentTreatments == null || currentTreatments!.trim().isEmpty) &&
      (psychiatricHistory == null || psychiatricHistory!.trim().isEmpty);

  factory MedicalHistory.fromJson(Map<String, dynamic> json) => MedicalHistory(
        patientId: (json['patientId'] as num).toInt(),
        allergies: json['allergies'] as String?,
        chronicConditions: json['chronicConditions'] as String?,
        currentTreatments: json['currentTreatments'] as String?,
        psychiatricHistory: json['psychiatricHistory'] as String?,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        lastUpdatedByRole: json['lastUpdatedByRole'] as String?,
      );
}

// corps pour PUT /patients/{id}/medical-history
class UpdateMedicalHistoryRequest {
  final String? allergies;
  final String? chronicConditions;
  final String? currentTreatments;
  final String? psychiatricHistory;

  UpdateMedicalHistoryRequest({
    this.allergies,
    this.chronicConditions,
    this.currentTreatments,
    this.psychiatricHistory,
  });

  Map<String, dynamic> toJson() => {
        'allergies': allergies,
        'chronicConditions': chronicConditions,
        'currentTreatments': currentTreatments,
        'psychiatricHistory': psychiatricHistory,
      };
}
