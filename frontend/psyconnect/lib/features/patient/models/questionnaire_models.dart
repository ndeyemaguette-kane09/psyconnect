// Questionnaires standardises PHQ-9 (depression) et GAD-7 (anxiete)
// Publie par Kroenke, Spitzer et al. — domaine public, utilise par l'OMS,
// MSF et des centaines d'applications de sante mentale dans le monde.
// Reference : Kroenke K, Spitzer RL, Williams JB. J Gen Intern Med. 2001;16(9):606-13.

enum QuestionnaireType { PHQ9, GAD7 }

enum QuestionnaireStatus { SENT, COMPLETED }

class QuestionnaireItem {
  const QuestionnaireItem({required this.id, required this.question});
  final int id;
  final String question;
}

// PHQ-9 : sur les 2 dernieres semaines, combien de jours avez-vous ete gené(e) par...
const kPhq9Questions = [
  QuestionnaireItem(id: 0, question: 'Peu d\'intérêt ou de plaisir à faire les choses'),
  QuestionnaireItem(id: 1, question: 'Se sentir déprimé(e), désespéré(e)'),
  QuestionnaireItem(id: 2, question: 'Difficultés à s\'endormir, dormir trop ou pas assez'),
  QuestionnaireItem(id: 3, question: 'Se sentir fatigué(e) ou manquer d\'énergie'),
  QuestionnaireItem(id: 4, question: 'Mauvais appétit ou trop manger'),
  QuestionnaireItem(id: 5, question: 'Mauvaise opinion de soi-même, ou sentiment d\'être une mauvaise personne'),
  QuestionnaireItem(id: 6, question: 'Difficultés à se concentrer (lire, regarder la télévision…)'),
  QuestionnaireItem(id: 7, question: 'Bouger ou parler lentement, ou au contraire être très agité(e)'),
  QuestionnaireItem(id: 8, question: 'Pensées que vous seriez mieux mort(e) ou idées de vous faire du mal'),
];

// GAD-7 : au cours des 2 dernières semaines, combien de jours avez-vous été gêné(e) par...
const kGad7Questions = [
  QuestionnaireItem(id: 0, question: 'Se sentir nerveux(se), anxieux(se) ou à bout'),
  QuestionnaireItem(id: 1, question: 'Ne pas être capable d\'arrêter de s\'inquiéter ou de contrôler ses inquiétudes'),
  QuestionnaireItem(id: 2, question: 'S\'inquiéter à propos de choses très diverses'),
  QuestionnaireItem(id: 3, question: 'Difficulté à se relaxer'),
  QuestionnaireItem(id: 4, question: 'Être tellement agité(e) qu\'il est difficile de rester assis(e) tranquille'),
  QuestionnaireItem(id: 5, question: 'Devenir facilement irritable ou irrité(e)'),
  QuestionnaireItem(id: 6, question: 'Avoir peur que quelque chose de terrible puisse arriver'),
];

// Options identiques pour les deux questionnaires (echelle de Likert 0-3)
const kAnswerLabels = [
  'Jamais',
  'Plusieurs jours',
  'Plus de la moitié des jours',
  'Presque tous les jours',
];

class Questionnaire {
  const Questionnaire({
    required this.id,
    required this.type,
    required this.status,
    required this.psychologistId,
    required this.patientId,
    this.appointmentId,
    this.answers,
    this.score,
    this.severity,
    required this.sentAt,
    this.completedAt,
  });

  final int id;
  final QuestionnaireType type;
  final QuestionnaireStatus status;
  final int psychologistId;
  final int patientId;
  final int? appointmentId;
  final List<int>? answers;
  final int? score;
  final String? severity;
  final DateTime sentAt;
  final DateTime? completedAt;

  bool get isPending => status == QuestionnaireStatus.SENT;

  // max possible selon le type
  int get maxScore => type == QuestionnaireType.PHQ9 ? 27 : 21;

  List<QuestionnaireItem> get questions =>
      type == QuestionnaireType.PHQ9 ? kPhq9Questions : kGad7Questions;

  String get typeName =>
      type == QuestionnaireType.PHQ9 ? 'PHQ-9' : 'GAD-7';

  String get typeDescription => type == QuestionnaireType.PHQ9
      ? 'Dépression'
      : 'Anxiété généralisée';

  factory Questionnaire.fromJson(Map<String, dynamic> json) {
    return Questionnaire(
      id: json['id'] as int,
      type: json['type'] == 'PHQ9'
          ? QuestionnaireType.PHQ9
          : QuestionnaireType.GAD7,
      status: json['status'] == 'COMPLETED'
          ? QuestionnaireStatus.COMPLETED
          : QuestionnaireStatus.SENT,
      psychologistId: json['psychologistId'] as int,
      patientId: json['patientId'] as int,
      appointmentId: json['appointmentId'] as int?,
      answers: (json['answers'] as List?)?.map((e) => e as int).toList(),
      score: json['score'] as int?,
      severity: json['severity'] as String?,
      sentAt: DateTime.parse(json['sentAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}
