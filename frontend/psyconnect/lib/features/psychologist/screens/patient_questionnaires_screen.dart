import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
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
      cards.add(const SizedBox(height: 26));
    }
    return cards;
  }

  bool get _hasTrend => QuestionnaireType.values
      .any((type) => _completedOfType(type).length >= 2);

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
                          if (_hasTrend) ...[
                            _EvolutionLink(onTap: () => _openEvolution(name)),
                            const SizedBox(height: 22),
                          ],
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
                          Container(height: 1, color: AppColors.border),
                          for (var i = 0; i < _questionnaires.length; i++)
                            _QuestionnaireCard(
                              q: _questionnaires[i],
                              onTap: _questionnaires[i].isPending
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              QuestionnaireResultScreen(
                                            questionnaire: _questionnaires[i],
                                            viewedByPsychologist: true,
                                          ),
                                        ),
                                      ),
                            ),
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
class _EvolutionLink extends StatelessWidget {
  const _EvolutionLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.borderStrong),
      ),
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.bar_chart_outlined, size: 20, color: AppColors.teal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Voir l'évolution des scores",
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
            ],
          ),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Évolution des scores',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Text(
              patientName,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: cards,
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
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          summary,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: AppColors.border),
        for (var i = 0; i < shown.length; i++)
          _TrendRow(
            q: shown[i],
            date: _shortDate(_dateOf(shown[i])),
            latest: i == shown.length - 1,
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: latest ? FontWeight.w600 : FontWeight.w400,
                  color: latest ? AppColors.text : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Container(
                  height: 6,
                  color: const Color(0xFFEEEBE5),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * ratio,
                    height: 6,
                    color: latest ? AppColors.tealDark : AppColors.tealMid,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 22,
              child: Text(
                '$score',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: latest ? FontWeight.w800 : FontWeight.w600,
                  color: latest ? AppColors.text : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 74,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: latest ? FontWeight.w600 : FontWeight.w400,
                  color: latest ? AppColors.text : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionnaireCard extends StatelessWidget {
  const _QuestionnaireCard({required this.q, this.onTap});

  final Questionnaire q;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = _shortDate(q.isPending ? q.sentAt : (q.completedAt ?? q.sentAt));

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  child: q.isPending
                      ? const Text(
                          '—',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.faint,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${q.score ?? 0}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '/ ${q.maxScore}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.isPending
                            ? '${q.typeName} · envoyé le $date'
                            : '${q.typeName} · $date',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        q.isPending
                            ? 'En attente de réponse'
                            : (q.severity ?? ''),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                      // Item 9 du PHQ-9 : signalé quel que soit le score total.
                      if (q.signalsImmediateRisk) ...[
                        const SizedBox(height: 6),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E3B2A),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!q.isPending)
                  const Icon(Icons.chevron_right,
                      color: AppColors.faint, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
