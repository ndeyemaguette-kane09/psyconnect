import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../models/questionnaire_models.dart';
import '../services/questionnaire_service.dart';

// patient remplit un questionnaire PHQ-9 ou GAD-7
// toutes les questions sur un ecran scrollable, radio buttons 0-3
class QuestionnaireFillScreen extends StatefulWidget {
  const QuestionnaireFillScreen({super.key, required this.questionnaire});

  final Questionnaire questionnaire;

  @override
  State<QuestionnaireFillScreen> createState() =>
      _QuestionnaireFillScreenState();
}

class _QuestionnaireFillScreenState extends State<QuestionnaireFillScreen> {
  final _service = QuestionnaireService();

  // reponses initialisees a -1 (non repondu)
  late List<int> _answers;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _answers = List<int>.filled(widget.questionnaire.questions.length, -1);
  }

  bool get _allAnswered => _answers.every((a) => a >= 0);

  Future<void> _submit() async {
    if (!_allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez répondre à toutes les questions.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _service.answerQuestionnaire(
          widget.questionnaire.id, _answers);
      if (!mounted) return;
      // remplacer cet ecran par l'ecran de resultats
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuestionnaireResultScreen(questionnaire: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Envoi échoué.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questionnaire;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q.typeName,
              style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
            Text(
              q.typeDescription,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // barre de progression
          LinearProgressIndicator(
            value: _answers.where((a) => a >= 0).length /
                q.questions.length,
            backgroundColor: AppColors.tealMid,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
            minHeight: 3,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Au cours des 2 dernières semaines, combien de jours avez-vous '
                    'été gêné(e) par les problèmes suivants ?',
                    style: TextStyle(
                        color: AppColors.tealDark,
                        fontSize: 13,
                        height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                ...q.questions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return _QuestionCard(
                    index: idx,
                    question: item.question,
                    selectedAnswer: _answers[idx],
                    onAnswerSelected: (v) =>
                        setState(() => _answers[idx] = v),
                  );
                }),
              ],
            ),
          ),
          // bouton fixe en bas
          Container(
            color: AppColors.white,
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_submitting || !_allAnswered) ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _allAnswered
                            ? 'Soumettre mes réponses'
                            : '${_answers.where((a) => a < 0).length} question(s) restante(s)',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedAnswer,
    required this.onAnswerSelected,
  });

  final int index;
  final String question;
  final int selectedAnswer;
  final ValueChanged<int> onAnswerSelected;

  @override
  Widget build(BuildContext context) {
    final answered = selectedAnswer >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: answered ? AppColors.teal : AppColors.tealMid,
          width: answered ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      answered ? AppColors.teal : AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: answered ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(kAnswerLabels.length, (i) {
            final selected = selectedAnswer == i;
            return GestureDetector(
              onTap: () => onAnswerSelected(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.teal
                              : AppColors.tealMid,
                          width: selected ? 5 : 2,
                        ),
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$i — ${kAnswerLabels[i]}',
                        style: TextStyle(
                          color:
                              selected ? AppColors.teal : AppColors.text,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ======================================================
// ecran de resultats (apres soumission par le patient)
// ======================================================
class QuestionnaireResultScreen extends StatelessWidget {
  const QuestionnaireResultScreen({super.key, required this.questionnaire});

  final Questionnaire questionnaire;

  // couleur selon la severite
  Color _severityColor() {
    final s = questionnaire.score ?? 0;
    final max = questionnaire.maxScore;
    final ratio = s / max;
    if (ratio < 0.2) return const Color(0xFF2E7D32); // vert fonce
    if (ratio < 0.4) return const Color(0xFF66BB6A); // vert
    if (ratio < 0.6) return const Color(0xFFFF9800); // orange
    if (ratio < 0.8) return const Color(0xFFF44336); // rouge
    return const Color(0xFFB71C1C); // rouge fonce
  }

  @override
  Widget build(BuildContext context) {
    final score = questionnaire.score ?? 0;
    final max = questionnaire.maxScore;
    final severity = questionnaire.severity ?? '';
    final color = _severityColor();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text(
          'Résultats ${questionnaire.typeName}',
          style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 15),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // cercle de score
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color, width: 4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: color),
                  ),
                  Text(
                    '/ $max',
                    style: TextStyle(color: color, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              severity,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              questionnaire.typeDescription,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 32),
            // echelle de reference
            _ScaleReference(type: questionnaire.type, score: score),
            const Spacer(),
            const Text(
              'Vos réponses ont été transmises à votre psychologue. '
              'Ces résultats sont un outil d\'évaluation, pas un diagnostic.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Retour à l\'accueil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// barre d'echelle de reference
class _ScaleReference extends StatelessWidget {
  const _ScaleReference({required this.type, required this.score});

  final QuestionnaireType type;
  final int score;

  @override
  Widget build(BuildContext context) {
    final bands = type == QuestionnaireType.PHQ9
        ? const [
            _Band('Minimal', 0, 4, Color(0xFF2E7D32)),
            _Band('Léger', 5, 9, Color(0xFF66BB6A)),
            _Band('Modéré', 10, 14, Color(0xFFFF9800)),
            _Band('Mod. sévère', 15, 19, Color(0xFFF44336)),
            _Band('Sévère', 20, 27, Color(0xFFB71C1C)),
          ]
        : const [
            _Band('Minimal', 0, 4, Color(0xFF2E7D32)),
            _Band('Léger', 5, 9, Color(0xFF66BB6A)),
            _Band('Modéré', 10, 14, Color(0xFFFF9800)),
            _Band('Sévère', 15, 21, Color(0xFFB71C1C)),
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Échelle d\'interprétation',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          ...bands.map((b) {
            final isActive = score >= b.min && score <= b.max;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: b.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${b.label}  (${b.min}–${b.max})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isActive ? b.color : AppColors.muted,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_left, color: b.color, size: 16),
                    Text(
                      'votre score',
                      style: TextStyle(
                          fontSize: 11,
                          color: b.color,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Band {
  const _Band(this.label, this.min, this.max, this.color);
  final String label;
  final int min;
  final int max;
  final Color color;
}
