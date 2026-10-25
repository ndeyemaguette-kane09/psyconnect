import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/recommendation_models.dart';
import '../services/recommendation_service.dart';

// ecran du psy : gere les recommandations post-seance pour un RDV COMPLETED
// accessible depuis la fiche detail du RDV dans agenda_tab
class SessionRecommendationsScreen extends StatefulWidget {
  const SessionRecommendationsScreen({
    super.key,
    required this.appointmentId,
    this.patientName,
  });

  final int appointmentId;
  final String? patientName;

  @override
  State<SessionRecommendationsScreen> createState() =>
      _SessionRecommendationsScreenState();
}

class _SessionRecommendationsScreenState
    extends State<SessionRecommendationsScreen> {
  final _service = RecommendationService();

  bool _loading = true;
  String? _error;
  List<SessionRecommendation> _recommendations = [];

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
      final list = await _service.getByAppointment(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _recommendations = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Impossible de charger.';
        _loading = false;
      });
    }
  }

  Future<void> _showAddSheet() async {
    final controller = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddRecommendationSheet(controller: controller),
    );
    if (saved != true || controller.text.trim().isEmpty) return;
    try {
      final created = await _service.createRecommendation(
        appointmentId: widget.appointmentId,
        content: controller.text.trim(),
      );
      if (!mounted) return;
      setState(() => _recommendations.insert(0, created));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recommandation ajoutée.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Erreur inattendue.'),
        ),
      );
    }
  }

  Future<void> _delete(SessionRecommendation reco) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text(
            'Cette recommandation sera supprimée définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteRecommendation(reco.id);
      if (!mounted) return;
      setState(
          () => _recommendations.removeWhere((r) => r.id == reco.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Suppression échouée.'),
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
      appBar: AppBar(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            onPressed: _showAddSheet,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Ajouter une recommandation'),
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
                'Après la séance',
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
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 14, 4, 16),
              child: Text(
                'Ce que le patient peut faire d\'ici la prochaine séance.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (_recommendations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Aucune recommandation pour l\'instant.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              )
            else
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final r in _recommendations)
                      _RecoRow(
                        recommendation: r,
                        onDelete: () => _delete(r),
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

const _kMonths = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

class _RecoRow extends StatelessWidget {
  const _RecoRow({required this.recommendation, required this.onDelete});

  final SessionRecommendation recommendation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = recommendation.createdAt;
    final done = recommendation.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: done ? AppColors.teal : AppColors.sand,
              shape: BoxShape.circle,
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 17, color: AppColors.background)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.content,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.45,
                    color: done ? AppColors.muted : AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  done
                      ? 'Faite par le patient'
                      : 'Ajoutée le ${d.day} ${_kMonths[d.month - 1]}',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: done ? AppColors.teal : AppColors.muted,
                    fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.muted),
            onSelected: (v) {
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text('Supprimer',
                    style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// feuille modale pour ecrire une recommandation
class _AddRecommendationSheet extends StatelessWidget {
  const _AddRecommendationSheet({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Text(
              'Nouvelle recommandation',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Une tâche ou un conseil pour le patient avant la prochaine séance.',
              style: TextStyle(color: AppColors.muted, fontSize: 14.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ex : Tenir le journal 10 minutes chaque soir…',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
