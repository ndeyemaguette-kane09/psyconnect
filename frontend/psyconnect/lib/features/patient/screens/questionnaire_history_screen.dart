import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/questionnaire_models.dart';
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
      if (!mounted) return;
      setState(() {
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
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: const Text(
          'Mes questionnaires',
          style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 15),
        ),
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
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: _questionnaires.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _QuestionnaireCard(
                          questionnaire: _questionnaires[i],
                          onTap: () => _openDetail(_questionnaires[i]),
                        ),
                      ),
      ),
    );
  }

  void _openDetail(Questionnaire q) {
    if (q.isPending) {
      // questionnaire non encore rempli → ouvrir l'écran de remplissage
      Navigator.of(context)
          .push(MaterialPageRoute(
        builder: (_) => QuestionnaireFillScreen(questionnaire: q),
      ))
          .then((_) => _load()); // rafraîchir après retour
    } else {
      // questionnaire complété → afficher les résultats
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
  });

  final Questionnaire questionnaire;
  final VoidCallback onTap;

  Color get _typeColor =>
      questionnaire.type == QuestionnaireType.PHQ9
          ? const Color(0xFF5C6BC0) // indigo — dépression
          : const Color(0xFF26A69A); // teal — anxiété

  Color get _typeBg =>
      questionnaire.type == QuestionnaireType.PHQ9
          ? const Color(0xFFE8EAF6)
          : AppColors.tealLight;

  @override
  Widget build(BuildContext context) {
    final q = questionnaire;
    final completed = !q.isPending;
    final date = completed ? q.completedAt : q.sentAt;
    final dateLabel = date != null
        ? '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/'
            '${date.year}'
        : '';

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // badge type
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _typeBg,
                ),
                child: Center(
                  child: Text(
                    q.typeName,
                    style: TextStyle(
                      color: _typeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
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
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    if (completed && q.severity != null)
                      Text(
                        q.severity!,
                        style: TextStyle(
                            color: _typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      )
                    else
                      const Text(
                        'En attente de réponse',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      completed ? 'Complété le $dateLabel' : 'Reçu le $dateLabel',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // score ou icône en attente
              if (completed && q.score != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${q.score}/${q.maxScore}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: _typeColor,
                      ),
                    ),
                    const Text('score',
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 10)),
                  ],
                ),
              ] else
                const Icon(Icons.edit_outlined,
                    color: AppColors.gold, size: 20),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
