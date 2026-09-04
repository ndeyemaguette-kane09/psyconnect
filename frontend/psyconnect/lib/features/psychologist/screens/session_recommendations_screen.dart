import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
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
            child:
                const Text('Supprimer', style: TextStyle(color: AppColors.rose)),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommandations post-séance',
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            Text(name,
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 12,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
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
                            onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : _recommendations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.assignment_outlined,
                                  size: 32, color: AppColors.teal),
                            const SizedBox(height: 16),
                            const Text('Aucune recommandation',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 6),
                            const Text(
                              'Ajoutez des tâches ou conseils que vous souhaitez '
                              'que le patient réalise avant la prochaine séance.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 13,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _recommendations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final r = _recommendations[i];
                          return _RecoCard(
                            recommendation: r,
                            onDelete: () => _delete(r),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _RecoCard extends StatelessWidget {
  const _RecoCard({required this.recommendation, required this.onDelete});

  final SessionRecommendation recommendation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = recommendation.createdAt;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: recommendation.completed
              ? AppColors.tealMid
              : AppColors.tealMid,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            recommendation.completed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            color: recommendation.completed ? AppColors.teal : AppColors.muted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: recommendation.completed
                        ? AppColors.muted
                        : AppColors.text,
                    decoration: recommendation.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                    if (recommendation.completed) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '· Accomplie ✓',
                        style: TextStyle(
                            color: AppColors.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.rose, size: 20),
            onPressed: onDelete,
            tooltip: 'Supprimer',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
          color: AppColors.white,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.tealMid),
              ),
            ),
            const Text(
              'Nouvelle recommandation',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tâche ou conseil à réaliser par le patient avant la prochaine séance.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex : Tenir le journal 10 minutes chaque soir…',
                hintStyle: const TextStyle(color: AppColors.muted),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.tealMid),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal),
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
