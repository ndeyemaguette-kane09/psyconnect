// tache ou conseil post-seance ecrit par le psy, visible par le patient
class SessionRecommendation {
  final int id;
  final int appointmentId;
  final int psychologistId;
  final int patientId;
  final String content;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  SessionRecommendation({
    required this.id,
    required this.appointmentId,
    required this.psychologistId,
    required this.patientId,
    required this.content,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SessionRecommendation.fromJson(Map<String, dynamic> json) =>
      SessionRecommendation(
        id: (json['id'] as num).toInt(),
        appointmentId: (json['appointmentId'] as num).toInt(),
        psychologistId: (json['psychologistId'] as num).toInt(),
        patientId: (json['patientId'] as num).toInt(),
        content: json['content'] as String,
        completed: json['completed'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
