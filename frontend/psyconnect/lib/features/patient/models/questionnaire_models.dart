
enum QuestionnaireType {
  PHQ9('PHQ-9', 'Dépression'),
  GAD7('GAD-7', 'Anxiété généralisée'),
  PSS10('PSS-10', 'Stress perçu'),
  EPDS('EPDS', 'Dépression post-natale');

  const QuestionnaireType(this.label, this.description);

  final String label;
  final String description;
}

enum QuestionnaireStatus { SENT, COMPLETED }

class QuestionnaireItem {
  const QuestionnaireItem({
    required this.id,
    required this.question,
    this.answers,
    this.reversed = false,
  });
  final int id;
  final String question;
  final List<String>? answers;
  final bool reversed;
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

// PSS-10 (Cohen, 1983) : au cours du dernier mois...
const kPss10Questions = [
  QuestionnaireItem(id: 0, question: 'Combien de fois avez-vous été dérangé(e) par un événement inattendu ?'),
  QuestionnaireItem(id: 1, question: 'Combien de fois vous a-t-il semblé difficile de contrôler les choses importantes de votre vie ?'),
  QuestionnaireItem(id: 2, question: 'Combien de fois vous êtes-vous senti(e) nerveux(se) et stressé(e) ?'),
  QuestionnaireItem(id: 3, question: 'Combien de fois vous êtes-vous senti(e) confiant(e) pour prendre en main vos problèmes personnels ?', reversed: true),
  QuestionnaireItem(id: 4, question: 'Combien de fois avez-vous senti que les choses allaient comme vous le vouliez ?', reversed: true),
  QuestionnaireItem(id: 5, question: 'Combien de fois avez-vous pensé que vous ne pouviez pas assumer toutes les choses que vous deviez faire ?'),
  QuestionnaireItem(id: 6, question: 'Combien de fois avez-vous été capable de maîtriser votre énervement ?', reversed: true),
  QuestionnaireItem(id: 7, question: 'Combien de fois avez-vous senti que vous dominiez la situation ?', reversed: true),
  QuestionnaireItem(id: 8, question: 'Combien de fois vous êtes-vous senti(e) irrité(e) parce que les événements échappaient à votre contrôle ?'),
  QuestionnaireItem(id: 9, question: 'Combien de fois avez-vous trouvé que les difficultés s\'accumulaient à tel point que vous ne pouviez les contrôler ?'),
];

const kPss10AnswerLabels = [
  'Jamais',
  'Presque jamais',
  'Parfois',
  'Assez souvent',
  'Très souvent',
];

// EPDS (Cox, Holden et Sagovsky, 1987 ; traduction Guedeney et Fermanian, 1998)
// chaque item a ses propres reponses
const kEpdsQuestions = [
  QuestionnaireItem(id: 0, question: 'J\'ai pu rire et prendre les choses du bon côté', answers: [
    'Aussi souvent que d\'habitude',
    'Pas tout à fait autant',
    'Vraiment beaucoup moins souvent ces jours-ci',
    'Absolument pas',
  ]),
  QuestionnaireItem(id: 1, question: 'Je me suis sentie confiante et joyeuse en pensant à l\'avenir', answers: [
    'Autant que d\'habitude',
    'Plutôt moins que d\'habitude',
    'Vraiment moins que d\'habitude',
    'Pratiquement pas',
  ]),
  QuestionnaireItem(id: 2, question: 'Je me suis reproché, sans raison, d\'être responsable quand les choses allaient mal', reversed: true, answers: [
    'Oui, la plupart du temps',
    'Oui, parfois',
    'Pas très souvent',
    'Non, jamais',
  ]),
  QuestionnaireItem(id: 3, question: 'Je me suis sentie inquiète ou soucieuse sans motif', answers: [
    'Non, pas du tout',
    'Presque jamais',
    'Oui, parfois',
    'Oui, très souvent',
  ]),
  QuestionnaireItem(id: 4, question: 'Je me suis sentie effrayée ou paniquée sans vraiment de raison', reversed: true, answers: [
    'Oui, vraiment souvent',
    'Oui, parfois',
    'Non, pas très souvent',
    'Non, pas du tout',
  ]),
  QuestionnaireItem(id: 5, question: 'J\'ai eu tendance à me sentir dépassée par les événements', reversed: true, answers: [
    'Oui, la plupart du temps, je me suis sentie incapable de faire face aux situations',
    'Oui, parfois, je ne me suis pas sentie aussi capable d\'y faire face que d\'habitude',
    'Non, j\'ai pu faire face à la plupart des situations',
    'Non, je me suis sentie aussi efficace que d\'habitude',
  ]),
  QuestionnaireItem(id: 6, question: 'Je me suis sentie si malheureuse que j\'ai eu des problèmes de sommeil', reversed: true, answers: [
    'Oui, la plupart du temps',
    'Oui, parfois',
    'Pas très souvent',
    'Non, pas du tout',
  ]),
  QuestionnaireItem(id: 7, question: 'Je me suis sentie triste ou peu heureuse', reversed: true, answers: [
    'Oui, la plupart du temps',
    'Oui, très souvent',
    'Pas très souvent',
    'Non, pas du tout',
  ]),
  QuestionnaireItem(id: 8, question: 'Je me suis sentie si malheureuse que j\'en ai pleuré', reversed: true, answers: [
    'Oui, la plupart du temps',
    'Oui, très souvent',
    'Seulement de temps en temps',
    'Non, jamais',
  ]),
  QuestionnaireItem(id: 9, question: 'Il m\'est arrivé de penser à me faire du mal', reversed: true, answers: [
    'Oui, très souvent',
    'Parfois',
    'Presque jamais',
    'Jamais',
  ]),
];

const int kPhq9RiskItemIndex = 8;
const int kRiskThreshold = 2;
const int kEpdsRiskItemIndex = 9;
const int kEpdsRiskThreshold = 1;

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

  bool get signalsImmediateRisk {
    final a = answers;
    return a != null && hasRiskIn(a);
  }

  bool hasRiskIn(List<int> a) {
    final i = riskItemIndex;
    if (i == null || a.length <= i || a[i] < 0) return false;
    final threshold =
        type == QuestionnaireType.EPDS ? kEpdsRiskThreshold : kRiskThreshold;
    return pointsFor(i, a[i]) >= threshold;
  }

  int? get riskItemIndex => switch (type) {
        QuestionnaireType.PHQ9 => kPhq9RiskItemIndex,
        QuestionnaireType.EPDS => kEpdsRiskItemIndex,
        _ => null,
      };

  int get riskItemNumber => (riskItemIndex ?? 0) + 1;

  String get riskLabel => type == QuestionnaireType.EPDS
      ? 'pensées de se faire du mal'
      : 'idées suicidaires';

  int get maxAnswer => type == QuestionnaireType.PSS10 ? 4 : 3;

  // max possible selon le type
  int get maxScore => questions.length * maxAnswer;

  int pointsFor(int index, int answer) =>
      questions[index].reversed ? maxAnswer - answer : answer;

  List<QuestionnaireItem> get questions => switch (type) {
        QuestionnaireType.PHQ9 => kPhq9Questions,
        QuestionnaireType.GAD7 => kGad7Questions,
        QuestionnaireType.PSS10 => kPss10Questions,
        QuestionnaireType.EPDS => kEpdsQuestions,
      };

  List<String> answerLabelsFor(int index) =>
      questions[index].answers ??
      (type == QuestionnaireType.PSS10 ? kPss10AnswerLabels : kAnswerLabels);

  String get intro => switch (type) {
        QuestionnaireType.PSS10 => 'Au cours du dernier mois :',
        QuestionnaireType.EPDS => 'Au cours des sept derniers jours :',
        _ => 'Au cours des deux dernières semaines, à quelle fréquence '
            'avez-vous été gêné(e) par…',
      };

  String get periodRecent => switch (type) {
        QuestionnaireType.PSS10 => 'ce dernier mois',
        QuestionnaireType.EPDS => 'ces sept derniers jours',
        _ => 'ces deux dernières semaines',
      };

  String get periodBefore => switch (type) {
        QuestionnaireType.PSS10 => 'sur le mois précédant la réponse',
        QuestionnaireType.EPDS => 'sur les sept jours précédant la réponse',
        _ => 'sur les deux semaines précédant la réponse',
      };

  String get typeName => type.label;

  String get typeDescription => type.description;

  factory Questionnaire.fromJson(Map<String, dynamic> json) {
    return Questionnaire(
      id: json['id'] as int,
      type: QuestionnaireType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => QuestionnaireType.GAD7,
      ),
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
