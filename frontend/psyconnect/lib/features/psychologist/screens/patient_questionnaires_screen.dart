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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _sendQuestionnaire,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('Envoyer', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
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
                                  size: 32, color: Color(0xFF7C4DFF)),
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
                            FilledButton.icon(
                              onPressed: _sendQuestionnaire,
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C4DFF)),
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Envoyer un questionnaire'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        itemCount: _questionnaires.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _QuestionnaireCard(
                          q: _questionnaires[i],
                          onTap: _questionnaires[i].isPending
                              ? null
                              : () => Navigator.of(ctx).push(
                                    MaterialPageRoute(
                                      builder: (_) => QuestionnaireResultScreen(
                                          questionnaire: _questionnaires[i]),
                                    ),
                                  ),
                        ),
                      ),
                    ),
    );
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              q.isPending ? AppColors.tealMid : _color.withOpacity(0.4),
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
                  : _color.withOpacity(0.12),
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
                            : _color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
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
