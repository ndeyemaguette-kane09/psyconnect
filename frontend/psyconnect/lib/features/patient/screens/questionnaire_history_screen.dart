import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/questionnaire_models.dart';
import '../services/psychologist_service.dart';
import '../services/questionnaire_service.dart';
import 'questionnaire_fill_screen.dart';

// historique complet des questionnaires du patient (pending + completed)
// accessible depuis la home patient
class QuestionnaireHistoryScreen extends StatefulWidget {
  const QuestionnaireHistoryScreen({super.key});

  @override
  State<QuestionnaireHistoryScreen> createState() =>
      _QuestionnaireHistoryScreenState();
}

class _QuestionnaireHistoryScreenState
    extends State<QuestionnaireHistoryScreen> {
  final _service = QuestionnaireService();
  final _psychologistService = PsychologistService();
  Map<int, String> _psychologistNames = {};

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
      final list = await _service.getMyQuestionnaires();
      final names = <int, String>{};
      try {
        final psychologists = await _psychologistService.getAllPsychologists();
        for (final p in psychologists) {
          names[p.id] = p.fullName;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _psychologistNames = names;
        _questionnaires = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les questionnaires.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 100),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  style: const TextStyle(
                                      color: AppColors.muted)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                  onPressed: _load,
                                  child: const Text('Réessayer')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _questionnaires.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 100),
                            child: Center(
                              child: Text(
                                'Aucun questionnaire pour l\'instant.\n'
                                'Votre psychologue vous en enverra un.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppColors.muted, height: 1.5),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                            child: Text(
                              'Mes questionnaires',
                              style:
                                  Theme.of(context).textTheme.displayMedium,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(4, 0, 4, 20),
                            child: Text(
                              'Envoyés par votre psychologue pour suivre '
                              'votre évolution.',
                              style: TextStyle(
                                fontSize: 15.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                for (final q in _questionnaires)
                                  _QuestionnaireCard(
                                    questionnaire: q,
                                    psychologistName:
                                        _psychologistNames[q.psychologistId],
                                    onTap: () => _openDetail(q),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  void _openDetail(Questionnaire q) {
    if (q.isPending) {
      // questionnaire non encore rempli -> ouvrir l'écran de remplissage
      Navigator.of(context)
          .push(MaterialPageRoute(
        builder: (_) => QuestionnaireFillScreen(questionnaire: q),
      ))
          .then((_) => _load()); // rafraîchir après retour
    } else {
      // questionnaire complété -> afficher les résultats
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuestionnaireResultScreen(questionnaire: q),
      ));
    }
  }
}

class _QuestionnaireCard extends StatelessWidget {
  const _QuestionnaireCard({
    required this.questionnaire,
    required this.onTap,
    this.psychologistName,
  });

  final Questionnaire questionnaire;
  final VoidCallback onTap;
  final String? psychologistName;

  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  bool get _isPhq => questionnaire.type == QuestionnaireType.PHQ9;

  @override
  Widget build(BuildContext context) {
    final q = questionnaire;
    final completed = !q.isPending;
    final date = completed ? q.completedAt : q.sentAt;
    final dateLabel = date != null
        ? '${date.day} ${_months[date.month - 1]} ${date.year}'
        : '';
    final ink = _isPhq ? AppColors.goldDark : AppColors.teal;
    final soft = _isPhq ? AppColors.goldLight : AppColors.tealLight;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: soft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                q.typeName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.typeDescription,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      color: AppColors.text,
                    ),
                  ),
                  if (psychologistName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Envoyé par $psychologistName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    completed
                        ? [
                            if (q.severity != null) q.severity!,
                            'rempli le $dateLabel',
                          ].join(' · ')
                        : 'Reçu le $dateLabel',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (completed && q.score != null)
              Text(
                '${q.score}/${q.maxScore}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppColors.text,
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.goldDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'À remplir',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}
