import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../patient/models/questionnaire_models.dart';
import '../../patient/screens/questionnaire_fill_screen.dart';
import '../../patient/services/questionnaire_service.dart';

// ecran psy : historique des questionnaires PHQ-9/GAD-7 d'un patient,
// avec envoi d'un nouveau questionnaire
class PatientQuestionnairesScreen extends StatefulWidget {
  const PatientQuestionnairesScreen({
    super.key,
    required this.patientId,
    this.patientName,
  });

  final int patientId;
  final String? patientName;

  @override
  State<PatientQuestionnairesScreen> createState() =>
      _PatientQuestionnairesScreenState();
}

class _PatientQuestionnairesScreenState
    extends State<PatientQuestionnairesScreen> {
  final _service = QuestionnaireService();

  bool _loading = true;
  String? _error;
  List<Questionnaire> _questionnaires = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await _service.getPatientQuestionnaires(widget.patientId);
      if (!mounted) return;
      setState(() {
        _questionnaires = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Chargement échoué.';
        _loading = false;
      });
    }
  }

  Future<void> _sendQuestionnaire() async {
    final type = await showModalBottomSheet<QuestionnaireType>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Text(
                  'Quel questionnaire envoyer ?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _TypeOption(
                      type: QuestionnaireType.PHQ9,
                      title: 'PHQ-9 · Dépression',
                      subtitle: '9 questions, environ 3 minutes',
                      onTap: () =>
                          Navigator.of(ctx).pop(QuestionnaireType.PHQ9),
                    ),
                    _TypeOption(
                      type: QuestionnaireType.GAD7,
                      title: 'GAD-7 · Anxiété',
                      subtitle: '7 questions, environ 2 minutes',
                      onTap: () =>
                          Navigator.of(ctx).pop(QuestionnaireType.GAD7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (type == null) return;

    try {
      await _service.sendQuestionnaire(
        type: type,
        patientId: widget.patientId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${type == QuestionnaireType.PHQ9 ? 'PHQ-9' : 'GAD-7'} envoyé.'),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Envoi échoué.'),
        ),
      );
    }
  }

  // Mesures complétées d'un type, du plus ancien au plus récent.
  List<Questionnaire> _completedOfType(QuestionnaireType type) {
    final list = _questionnaires
        .where((q) => q.type == type && !q.isPending && q.score != null)
        .toList();
    list.sort((a, b) =>
        (a.completedAt ?? a.sentAt).compareTo(b.completedAt ?? b.sentAt));
    return list;
  }

  // Une carte de suivi par type, à partir de deux mesures.
  List<Widget> _trendCards() {
    final cards = <Widget>[];
    for (final type in QuestionnaireType.values) {
      final entries = _completedOfType(type);
      if (entries.length < 2) continue;
      cards.add(_TrendCard(entries: entries));
      cards.add(const SizedBox(height: 26));
    }
    return cards;
  }

  void _openEvolution(String patientName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EvolutionScreen(
          patientName: patientName,
          cards: _trendCards(),
        ),
      ),
    );
  }

  String _trendSentence(List<Questionnaire> entries) {
    final first = entries.first;
    final last = entries.last;
    final diff = (last.score ?? 0) - (first.score ?? 0);
    final since = _shortDate(first.completedAt ?? first.sentAt);
    final head = '${last.typeName} : ${last.score ?? 0}';
    if (diff < 0) {
      return '$head, soit ${-diff} point${-diff > 1 ? 's' : ''} de moins '
          'depuis le $since.';
    }
    if (diff > 0) {
      return '$head, soit $diff point${diff > 1 ? 's' : ''} de plus '
          'depuis le $since.';
    }
    return '$head, stable depuis le $since.';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.patientName?.isNotEmpty == true
        ? widget.patientName!
        : 'Patient';
    final risky = _questionnaires.where((q) => q.signalsImmediateRisk).toList()
      ..sort((a, b) =>
          (b.completedAt ?? b.sentAt).compareTo(a.completedAt ?? a.sentAt));
    final trends = [
      for (final type in QuestionnaireType.values)
        if (_completedOfType(type).length >= 2) _completedOfType(type),
    ];

    return Scaffold(
      appBar: AppBar(),
      // Barre d'action fixe : le bouton d'envoi reste atteignable quel que soit
      // le nombre de questionnaires déjà présents dans la liste.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            onPressed: _sendQuestionnaire,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Envoyer un questionnaire'),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Questionnaires',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                name,
                style: const TextStyle(fontSize: 15.5, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (_questionnaires.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Aucun questionnaire pour l\'instant. Envoyez un PHQ-9 ou '
                  'un GAD-7 pour suivre l\'évolution de votre patient.',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
              )
            else ...[
              // Item 9 du PHQ-9 : signalé quel que soit le score total.
              if (risky.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Question 9 : idées suicidaires signalées',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${risky.first.typeName} du '
                        '${_shortDate(risky.first.completedAt ?? risky.first.sentAt)}. '
                        'À aborder en priorité lors de la prochaine séance.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],
              if (trends.isNotEmpty) ...[
                const _Heading('Évolution'),
                for (final t in trends)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: Text(
                      _trendSentence(t),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _openEvolution(name),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                    ),
                    child: const Text(
                      "Voir l'évolution des scores",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const _Heading('Historique'),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final q in _questionnaires)
                      _QuestionnaireRow(
                        q: q,
                        onTap: q.isPending
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => QuestionnaireResultScreen(
                                      questionnaire: q,
                                      viewedByPsychologist: true,
                                    ),
                                  ),
                                ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _kShortMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _shortDate(DateTime d) => '${d.day} ${_kShortMonths[d.month - 1]}';

Color _levelColor(Questionnaire q) {
  final score = q.score ?? 0;
  final ratio = q.maxScore <= 0 ? 0.0 : score / q.maxScore;
  if (ratio < 0.35) return AppColors.teal;
  if (ratio < 0.6) return AppColors.goldDark;
  return AppColors.danger;
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final QuestionnaireType type;

  @override
  Widget build(BuildContext context) {
    final phq = type == QuestionnaireType.PHQ9;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: phq ? AppColors.goldLight : AppColors.tealLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        phq ? 'PHQ' : 'GAD',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: phq ? AppColors.goldDark : AppColors.teal,
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final QuestionnaireType type;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            _TypeBadge(type: type),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(fontSize: 13.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _EvolutionScreen extends StatelessWidget {
  const _EvolutionScreen({required this.patientName, required this.cards});

  final String patientName;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        children: [
          const Text(
            'Évolution des scores',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            patientName,
            style: const TextStyle(fontSize: 15.5, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          ...cards,
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.entries});

  // Du plus ancien au plus récent, uniquement des mesures complétées.
  final List<Questionnaire> entries;

  static const int _maxRows = 8;

  List<Questionnaire> get _shown => entries.length <= _maxRows
      ? entries
      : entries.sublist(entries.length - _maxRows);

  DateTime _dateOf(Questionnaire q) => q.completedAt ?? q.sentAt;

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final first = shown.first;
    final last = shown.last;
    final diff = (last.score ?? 0) - (first.score ?? 0);
    final since = _shortDate(_dateOf(first));

    final String summary;
    if (diff < 0) {
      summary = '${-diff} point${-diff > 1 ? 's' : ''} de moins depuis le '
          '$since.';
    } else if (diff > 0) {
      summary = '$diff point${diff > 1 ? 's' : ''} de plus depuis le $since.';
    } else {
      summary = 'Stable depuis le $since.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${last.typeName} · ${last.typeDescription}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          summary,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++)
                _TrendRow(
                  q: shown[i],
                  date: _shortDate(_dateOf(shown[i])),
                  latest: i == shown.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.q,
    required this.date,
    required this.latest,
  });

  final Questionnaire q;
  final String date;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final score = q.score ?? 0;
    final ratio = q.maxScore <= 0 ? 0.0 : (score / q.maxScore).clamp(0.0, 1.0);
    final band = severityBandOf(q.type, score);
    final label =
        band.label == 'Modérément sévère' ? 'Mod. sévère' : band.label;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              date,
              style: TextStyle(
                fontSize: 14,
                fontWeight: latest ? FontWeight.w700 : FontWeight.w400,
                color: latest ? AppColors.text : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * ratio,
                  height: 8,
                  decoration: BoxDecoration(
                    color: latest ? AppColors.teal : AppColors.tealMid,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 24,
            child: Text(
              '$score',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: latest ? FontWeight.w800 : FontWeight.w600,
                color: latest ? AppColors.text : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: latest ? FontWeight.w700 : FontWeight.w400,
                color: latest ? AppColors.text : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionnaireRow extends StatelessWidget {
  const _QuestionnaireRow({required this.q, this.onTap});

  final Questionnaire q;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date =
        _shortDate(q.isPending ? q.sentAt : (q.completedAt ?? q.sentAt));
    final band = q.isPending ? null : severityBandOf(q.type, q.score ?? 0);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            _TypeBadge(type: q.type),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${q.typeName} · ${q.typeDescription}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    q.isPending ? 'Envoyé le $date' : date,
                    style:
                        const TextStyle(fontSize: 13.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (q.isPending)
              const _SolidLabel('En attente', AppColors.gold, dark: true)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${q.score ?? 0}'),
                        TextSpan(
                          text: ' / ${q.maxScore}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _SolidLabel(
                    band!.label == 'Modérément sévère'
                        ? 'Mod. sévère'
                        : band.label,
                    _levelColor(q),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SolidLabel extends StatelessWidget {
  const _SolidLabel(this.text, this.color, {this.dark = false});

  final String text;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: dark ? AppColors.text : Colors.white,
        ),
      ),
    );
  }
}
