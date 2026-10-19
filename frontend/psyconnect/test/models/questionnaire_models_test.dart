import 'package:flutter_test/flutter_test.dart';
import 'package:psyconnect/features/patient/models/questionnaire_models.dart';

Questionnaire questionnaire(QuestionnaireType type, List<int>? answers) {
  return Questionnaire(
    id: 1,
    type: type,
    status: answers == null
        ? QuestionnaireStatus.SENT
        : QuestionnaireStatus.COMPLETED,
    psychologistId: 7,
    patientId: 4,
    answers: answers,
    sentAt: DateTime(2026, 9, 20),
  );
}

void main() {
  group('Questionnaire.signalsImmediateRisk', () {
    test('alerte quand l\'item 9 du PHQ-9 vaut 2', () {
      final q = questionnaire(
        QuestionnaireType.PHQ9,
        [0, 0, 0, 0, 0, 0, 0, 0, 2],
      );

      expect(q.signalsImmediateRisk, isTrue);
    });

    test('alerte même quand le score total est faible', () {
      final q = questionnaire(
        QuestionnaireType.PHQ9,
        [0, 0, 0, 0, 0, 0, 0, 0, 3],
      );

      expect(q.answers!.reduce((a, b) => a + b), 3);
      expect(q.signalsImmediateRisk, isTrue);
    });

    test('n\'alerte pas quand l\'item 9 vaut 1', () {
      final q = questionnaire(
        QuestionnaireType.PHQ9,
        [3, 3, 3, 3, 3, 3, 3, 3, 1],
      );

      expect(q.signalsImmediateRisk, isFalse);
    });

    test('n\'alerte jamais sur un GAD-7', () {
      final q = questionnaire(QuestionnaireType.GAD7, [3, 3, 3, 3, 3, 3, 3]);

      expect(q.signalsImmediateRisk, isFalse);
    });

    test('n\'alerte pas sur un questionnaire pas encore rempli', () {
      final q = questionnaire(QuestionnaireType.PHQ9, null);

      expect(q.isPending, isTrue);
      expect(q.signalsImmediateRisk, isFalse);
    });

    test('ne plante pas sur une liste de réponses incomplète', () {
      final q = questionnaire(QuestionnaireType.PHQ9, [3, 3]);

      expect(q.signalsImmediateRisk, isFalse);
    });
  });

  group('Questionnaire, structure des échelles', () {
    test('le PHQ-9 a 9 questions et un maximum de 27', () {
      final q = questionnaire(QuestionnaireType.PHQ9, null);

      expect(q.questions, hasLength(9));
      expect(q.maxScore, 27);
      expect(q.maxScore, q.questions.length * (kAnswerLabels.length - 1));
      expect(q.typeName, 'PHQ-9');
    });

    test('le GAD-7 a 7 questions et un maximum de 21', () {
      final q = questionnaire(QuestionnaireType.GAD7, null);

      expect(q.questions, hasLength(7));
      expect(q.maxScore, 21);
      expect(q.maxScore, q.questions.length * (kAnswerLabels.length - 1));
      expect(q.typeName, 'GAD-7');
    });

    test('l\'item surveillé est bien celui des idées suicidaires', () {
      expect(kPhq9Questions[kPhq9RiskItemIndex].question, contains('mort'));
    });
  });

  group('Questionnaire.fromJson', () {
    test('lit un PHQ-9 rempli avec son score', () {
      final q = Questionnaire.fromJson({
        'id': 5,
        'type': 'PHQ9',
        'status': 'COMPLETED',
        'psychologistId': 7,
        'patientId': 4,
        'appointmentId': 21,
        'answers': [1, 1, 1, 1, 1, 1, 1, 1, 0],
        'score': 8,
        'severity': 'MILD',
        'sentAt': '2026-09-20T10:00:00',
        'completedAt': '2026-09-21T19:30:00',
      });

      expect(q.type, QuestionnaireType.PHQ9);
      expect(q.status, QuestionnaireStatus.COMPLETED);
      expect(q.isPending, isFalse);
      expect(q.answers, hasLength(9));
      expect(q.score, 8);
      expect(q.severity, 'MILD');
      expect(q.completedAt, DateTime(2026, 9, 21, 19, 30));
    });

    test('lit un GAD-7 envoyé mais pas encore rempli', () {
      final q = Questionnaire.fromJson({
        'id': 6,
        'type': 'GAD7',
        'status': 'SENT',
        'psychologistId': 7,
        'patientId': 4,
        'sentAt': '2026-09-20T10:00:00',
      });

      expect(q.type, QuestionnaireType.GAD7);
      expect(q.isPending, isTrue);
      expect(q.answers, isNull);
      expect(q.appointmentId, isNull);
      expect(q.completedAt, isNull);
    });
  });
}
