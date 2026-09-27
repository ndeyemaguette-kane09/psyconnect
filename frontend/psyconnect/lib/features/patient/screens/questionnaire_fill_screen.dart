import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../models/questionnaire_models.dart';
import '../services/questionnaire_service.dart';
import 'emergency_screen.dart';

// patient remplit un questionnaire PHQ-9 ou GAD-7
// une question par ecran, reponses 0-3
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
  int _index = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _answers = List<int>.filled(widget.questionnaire.questions.length, -1);
  }

  bool get _isLast => _index == widget.questionnaire.questions.length - 1;

  void _next() {
    if (_submitting || _answers[_index] < 0) return;
    if (_isLast) {
      _submit();
      return;
    }
    setState(() => _index++);
  }

  void _previous() {
    if (_index == 0) return;
    setState(() => _index--);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await _service.answerQuestionnaire(
          widget.questionnaire.id, _answers);
      if (!mounted) return;
      _openResult(result);
    } catch (e) {
      final completed = await _findCompleted();
      if (!mounted) return;
      if (completed != null) {
        _openResult(completed);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Envoi échoué.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<Questionnaire?> _findCompleted() async {
    try {
      final all = await _service.getMyQuestionnaires();
      for (final q in all) {
        if (q.id == widget.questionnaire.id && !q.isPending) return q;
      }
    } catch (_) {}
    return null;
  }

  void _openResult(Questionnaire result) {
    final atRisk = result.signalsImmediateRisk ||
        (widget.questionnaire.type == QuestionnaireType.PHQ9 &&
            _answers[kPhq9RiskItemIndex] >= kRiskThreshold);
    // remplacer cet ecran par l'ecran de resultats
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => atRisk
            ? _CareScreen(result: result)
            : QuestionnaireResultScreen(questionnaire: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questionnaire;
    final total = q.questions.length;
    final item = q.questions[_index];
    final selected = _answers[_index];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          q.typeName,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${_index + 1} sur $total',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < total; i++) ...[
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _index
                                  ? AppColors.teal
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (i != total - 1) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                children: [
                  const Text(
                    'Au cours des deux dernières semaines, à quelle fréquence '
                    'avez-vous été gêné(e) par…',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.question,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 26),
                  for (var i = 0; i < kAnswerLabels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AnswerOption(
                        label: kAnswerLabels[i],
                        selected: selected == i,
                        onTap: _submitting
                            ? null
                            : () => setState(() => _answers[_index] = i),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  if (_index > 0) ...[
                    TextButton(
                      onPressed: _submitting ? null : _previous,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                      ),
                      child: const Text('Précédent'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: (_submitting || selected < 0) ? null : _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isLast ? 'Voir mon résultat' : 'Continuer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: BorderSide(
        color: selected ? AppColors.teal : AppColors.borderStrong,
        width: selected ? 1.5 : 1,
      ),
    );
    return Material(
      color: selected ? AppColors.tealSoft : AppColors.white,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.tealDark : AppColors.text,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_outline,
                    color: AppColors.teal, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Proposition d'aide immédiate, affichée lorsqu'un patient signale des idées
// suicidaires à l'item 9 du PHQ-9. Volontairement non bloquante : c'est une
// porte ouverte, pas une alerte.
class _CareScreen extends StatelessWidget {
  const _CareScreen({required this.result});

  final Questionnaire result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.tealSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_border,
                      color: AppColors.teal, size: 26),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ce que vous vivez compte',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Des pensées comme celles-là sont lourdes à porter. Vous '
                "n'avez pas à attendre votre prochain rendez-vous pour en "
                'parler.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Parler à un psychologue maintenant'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Ou appelez le SAMU au 1515, gratuit, 24h/24.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        QuestionnaireResultScreen(questionnaire: result),
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text(
                  'Continuer vers mon résultat',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SeverityBand {
  const SeverityBand(
    this.label,
    this.phrase,
    this.min,
    this.max,
    this.color,
    this.textColor,
  );

  final String label;
  final String phrase;
  final int min;
  final int max;
  final Color color;
  final Color textColor;
}

const _kPhq9Bands = [
  SeverityBand('Minimale', 'minimale', 0, 4, Color(0xFF7FA88B),
      Color(0xFF4E7A5C)),
  SeverityBand('Légère', 'légère', 5, 9, Color(0xFFD8C08A),
      Color(0xFF9A7B3A)),
  SeverityBand('Modérée', 'modérée', 10, 14, Color(0xFFC98F3E),
      Color(0xFF9A6A2A)),
  SeverityBand('Modérément sévère', 'modérément sévère', 15, 19,
      Color(0xFFB8613F), Color(0xFFA04F30)),
  SeverityBand('Sévère', 'sévère', 20, 27, Color(0xFF8E3B2A),
      Color(0xFF8E3B2A)),
];

const _kGad7Bands = [
  SeverityBand('Minimale', 'minimale', 0, 4, Color(0xFF7FA88B),
      Color(0xFF4E7A5C)),
  SeverityBand('Légère', 'légère', 5, 9, Color(0xFFD8C08A),
      Color(0xFF9A7B3A)),
  SeverityBand('Modérée', 'modérée', 10, 14, Color(0xFFC98F3E),
      Color(0xFF9A6A2A)),
  SeverityBand('Sévère', 'sévère', 15, 21, Color(0xFF8E3B2A),
      Color(0xFF8E3B2A)),
];

List<SeverityBand> severityBandsFor(QuestionnaireType type) =>
    type == QuestionnaireType.PHQ9 ? _kPhq9Bands : _kGad7Bands;

SeverityBand severityBandOf(QuestionnaireType type, int score) {
  final bands = severityBandsFor(type);
  for (final b in bands) {
    if (score >= b.min && score <= b.max) return b;
  }
  return bands.last;
}

// ======================================================
// ecran de resultats (apres soumission par le patient)
// ======================================================
class QuestionnaireResultScreen extends StatelessWidget {
  const QuestionnaireResultScreen({
    super.key,
    required this.questionnaire,
    this.viewedByPsychologist = false,
  });

  final Questionnaire questionnaire;
  final bool viewedByPsychologist;

  @override
  Widget build(BuildContext context) {
    final score = questionnaire.score ?? 0;
    final max = questionnaire.maxScore;
    final bands = severityBandsFor(questionnaire.type);
    final active = severityBandOf(questionnaire.type, score);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text(
          questionnaire.typeName,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                children: [
                  Text(
                    viewedByPsychologist
                        ? 'Résultat du ${questionnaire.typeName}'
                        : "Merci d'avoir répondu.",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: viewedByPsychologist
                              ? 'Les réponses montrent des difficultés '
                              : 'Vos réponses montrent des difficultés ',
                        ),
                        TextSpan(
                          text: "d'intensité ${active.phrase}",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: active.textColor,
                          ),
                        ),
                        TextSpan(
                          text: viewedByPsychologist
                              ? ' sur les deux semaines précédant la réponse.'
                              : ' ces deux dernières semaines. Votre '
                                  'psychologue les a reçues et pourra en '
                                  'parler avec vous à votre prochaine '
                                  'séance.',
                        ),
                      ],
                    ),
                  ),
                  if (questionnaire.signalsImmediateRisk) ...[
                    const SizedBox(height: 18),
                    if (viewedByPsychologist)
                      Container(
                        padding: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                                color: Color(0xFF8E3B2A), width: 2),
                          ),
                        ),
                        child: const Text(
                          'Question 9 : idées suicidaires signalées. À '
                          'aborder en priorité.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8E3B2A),
                            height: 1.35,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        decoration: BoxDecoration(
                          color: AppColors.tealSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Si ces pensées sont toujours là, vous pouvez '
                              "en parler à quelqu'un dès maintenant.",
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const EmergencyScreen()),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.tealDark,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Parler à un psychologue maintenant',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 30),
                  _ScoreBar(bands: bands, score: score, max: max),
                  const SizedBox(height: 22),
                  Container(height: 1, color: AppColors.border),
                  for (final b in bands)
                    _BandRow(band: b, active: identical(b, active)),
                  const SizedBox(height: 18),
                  const Text(
                    'Ce résultat est un repère, pas un diagnostic.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: FilledButton(
                onPressed: viewedByPsychologist
                    ? () => Navigator.of(context).pop()
                    : () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  viewedByPsychologist ? 'Retour' : "Retour à l'accueil",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.bands,
    required this.score,
    required this.max,
  });

  final List<SeverityBand> bands;
  final int score;
  final int max;

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, max);
    final ratio = (clamped + 0.5) / (max + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment(ratio * 2 - 1, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 3),
              Container(width: 2, height: 10, color: AppColors.text),
            ],
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < bands.length; i++) ...[
              Expanded(
                flex: bands[i].max - bands[i].min + 1,
                child: Container(height: 10, color: bands[i].color),
              ),
              if (i != bands.length - 1) const SizedBox(width: 3),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('0',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            const Spacer(),
            Text('$max',
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({required this.band, required this.active});

  final SeverityBand band;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13.5,
      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      color: active ? AppColors.text : AppColors.muted,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: band.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(band.label, style: style)),
            Text('${band.min} – ${band.max}', style: style),
          ],
        ),
      ),
    );
  }
}
