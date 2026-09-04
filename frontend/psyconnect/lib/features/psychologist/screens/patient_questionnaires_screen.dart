import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
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
    final type = await showDialog<QuestionnaireType>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envoyer un questionnaire'),
        content: const Text(
            'Quel questionnaire souhaitez-vous envoyer à ce patient ?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(QuestionnaireType.PHQ9),
            child: const Text('PHQ-9 — Dépression'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(QuestionnaireType.GAD7),
            child: const Text('GAD-7 — Anxiété'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
        ],
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
      cards.add(const SizedBox(height: 12));
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.patientName?.isNotEmpty == true
        ? widget.patientName!
        : 'Patient';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Questionnaires',
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            Text(name,
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      // Barre d'action fixe : le bouton d'envoi reste atteignable quel que soit
      // le nombre de questionnaires déjà présents dans la liste.
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton.icon(
            onPressed: _sendQuestionnaire,
            icon: const Icon(Icons.send_outlined, size: 19),
            label: const Text('Envoyer un questionnaire'),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: _load,
                            child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : _questionnaires.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEDE7F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.assignment_outlined,
                                  size: 32, color: AppColors.teal),
                            ),
                            const SizedBox(height: 16),
                            const Text('Aucun questionnaire',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 6),
                            const Text(
                              'Envoyez un PHQ-9 ou GAD-7 pour suivre '
                              "l'évolution de votre patient.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _sendQuestionnaire,
                              icon: const Icon(Icons.send_outlined, size: 19),
                              label:
                                  const Text('Envoyer un questionnaire'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          ..._trendCards(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'HISTORIQUE',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.muted,
                                    letterSpacing: 0.9,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          for (var i = 0; i < _questionnaires.length; i++) ...[
                            _QuestionnaireCard(
                              q: _questionnaires[i],
                              onTap: _questionnaires[i].isPending
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              QuestionnaireResultScreen(
                                            questionnaire: _questionnaires[i],
                                          ),
                                        ),
                                      ),
                            ),
                            if (i != _questionnaires.length - 1)
                              const SizedBox(height: 10),
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

// Carte de suivi d'un questionnaire dans le temps. Une carte par type : les
// échelles diffèrent (27 pour le PHQ-9, 21 pour le GAD-7) et superposer deux
// axes sur un même graphique fausserait la lecture.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.entries});

  // Du plus ancien au plus récent, uniquement des mesures complétées.
  final List<Questionnaire> entries;

  static const double _chartHeight = 56;
  static const int _maxBars = 8;

  List<Questionnaire> get _shown => entries.length <= _maxBars
      ? entries
      : entries.sublist(entries.length - _maxBars);

  DateTime _dateOf(Questionnaire q) => q.completedAt ?? q.sentAt;

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final first = shown.first;
    final last = shown.last;
    final maxScore = last.maxScore;
    final diff = (last.score ?? 0) - (first.score ?? 0);

    // Sur le PHQ-9 comme sur le GAD-7, un score qui baisse signifie des
    // symptômes qui diminuent : une flèche descendante est une amélioration.
    final Color deltaColor;
    final IconData deltaIcon;
    final String deltaLabel;
    if (diff < 0) {
      deltaColor = AppColors.success;
      deltaIcon = Icons.arrow_downward_rounded;
      deltaLabel = '${-diff} point${-diff > 1 ? 's' : ''} de moins '
          'qu\'au ${_shortDate(_dateOf(first))}';
    } else if (diff > 0) {
      deltaColor = AppColors.warning;
      deltaIcon = Icons.arrow_upward_rounded;
      deltaLabel = '$diff point${diff > 1 ? 's' : ''} de plus '
          'qu\'au ${_shortDate(_dateOf(first))}';
    } else {
      deltaColor = AppColors.muted;
      deltaIcon = Icons.remove_rounded;
      deltaLabel = 'Stable depuis le ${_shortDate(_dateOf(first))}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${last.typeName} · ${last.typeDescription}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
              ),
              Text(
                '${entries.length} mesures',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${last.score}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tealDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $maxScore',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  last.severity ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(deltaIcon, size: 15, color: deltaColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  deltaLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: deltaColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Colonnes : une par mesure, la plus récente en teal plein, les
          // précédentes atténuées. Une seule teinte — la hauteur porte déjà
          // l'information, la colorer par sévérité la doublerait.
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  Container(
                    width: 14,
                    height: _barHeight(shown[i].score ?? 0, maxScore),
                    decoration: BoxDecoration(
                      color: i == shown.length - 1
                          ? AppColors.teal
                          : AppColors.tealMid,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  if (i != shown.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 7),
          Text(
            'du ${_shortDate(_dateOf(first))} au ${_shortDate(_dateOf(last))}',
            style: const TextStyle(color: AppColors.faint, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  double _barHeight(int score, int maxScore) {
    if (maxScore <= 0) return 3;
    final h = (score / maxScore) * _chartHeight;
    return h < 3 ? 3 : h;
  }
}

class _QuestionnaireCard extends StatelessWidget {
  const _QuestionnaireCard({required this.q, this.onTap});

  final Questionnaire q;
  final VoidCallback? onTap;

  Color get _color {
    if (q.score == null) return AppColors.muted;
    final ratio = q.score! / q.maxScore;
    if (ratio < 0.2) return const Color(0xFF2E7D32);
    if (ratio < 0.4) return const Color(0xFF66BB6A);
    if (ratio < 0.6) return const Color(0xFFFF9800);
    if (ratio < 0.8) return const Color(0xFFF44336);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    final sent = q.sentAt;
    final sentLabel =
        '${sent.day.toString().padLeft(2, '0')}/${sent.month.toString().padLeft(2, '0')}/${sent.year}';

    return InkWell(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: q.signalsImmediateRisk
              ? AppColors.emergency
              : q.isPending
                  ? AppColors.tealMid
                  : _color.withValues(alpha: 0.4),
          width: q.signalsImmediateRisk ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          // cercle de score ou "en attente"
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: q.isPending
                  ? AppColors.background
                  : _color.withValues(alpha: 0.12),
              border: Border.all(
                color: q.isPending ? AppColors.tealMid : _color,
                width: 2,
              ),
            ),
            child: q.isPending
                ? const Icon(Icons.hourglass_empty,
                    color: AppColors.muted, size: 22)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${q.score}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _color,
                        ),
                      ),
                      Text(
                        '/${q.maxScore}',
                        style: TextStyle(
                            color: _color,
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      q.typeName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: q.isPending
                            ? AppColors.background
                            : _color.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        q.isPending ? 'En attente' : 'Complété',
                        style: TextStyle(
                          color: q.isPending ? AppColors.muted : _color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  q.isPending
                      ? 'Envoyé le $sentLabel · en attente de réponse'
                      : '${q.severity} · envoyé le $sentLabel',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12),
                ),
                // Item 9 du PHQ-9 : signalé quel que soit le score total.
                if (q.signalsImmediateRisk) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.priority_high_rounded,
                          size: 14, color: AppColors.emergency),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Idées suicidaires signalées (item 9) — à traiter en '
                          'priorité',
                          style: const TextStyle(
                            color: AppColors.emergency,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!q.isPending)
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
        ],
      ),
    ),
    );
  }
}
