import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../models/medical_history_models.dart';
import '../services/medical_history_service.dart';

// antecedents medicaux structures : ouvert depuis le profil patient (le
// patient consulte/edite les siens) ou depuis la fiche patient cote psy
// (le psy consulte/edite ceux du patient qu'il suit). Meme ecran des deux
// cotes, l'acces est verifie cote backend (psy doit avoir un RDV avec ce
// patient, admin jamais autorise). pas dans la maquette, design libre
class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({
    super.key,
    required this.patientId,
    this.patientName,
  });

  final int patientId;
  final String? patientName;

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  final _service = MedicalHistoryService();

  final _allergies = TextEditingController();
  final _chronicConditions = TextEditingController();
  final _currentTreatments = TextEditingController();
  final _psychiatricHistory = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _error;
  MedicalHistory? _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _allergies.dispose();
    _chronicConditions.dispose();
    _currentTreatments.dispose();
    _psychiatricHistory.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final history = await _service.getMedicalHistory(widget.patientId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _allergies.text = history.allergies ?? '';
        _chronicConditions.text = history.chronicConditions ?? '';
        _currentTreatments.text = history.currentTreatments ?? '';
        _psychiatricHistory.text = history.psychiatricHistory ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : "Impossible de charger les antécédents médicaux.";
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await _service.updateMedicalHistory(
        widget.patientId,
        UpdateMedicalHistoryRequest(
          allergies: _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
          chronicConditions: _chronicConditions.text.trim().isEmpty
              ? null
              : _chronicConditions.text.trim(),
          currentTreatments: _currentTreatments.text.trim().isEmpty
              ? null
              : _currentTreatments.text.trim(),
          psychiatricHistory: _psychiatricHistory.text.trim().isEmpty
              ? null
              : _psychiatricHistory.text.trim(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _history = updated;
        _saving = false;
        _editing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antécédents médicaux enregistrés.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : "Impossible d'enregistrer les modifications.";
        _saving = false;
      });
    }
  }

  String? get _lastUpdatedLabel {
    final history = _history;
    if (history?.updatedAt == null) return null;
    final d = history!.updatedAt!;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    final who = history.lastUpdatedByRole == 'PSYCHOLOGIST'
        ? 'le psychologue'
        : 'le patient';
    return 'Dernière modification le $date par $who';
  }

  void _cancelEditing() {
    final history = _history;
    setState(() {
      _allergies.text = history?.allergies ?? '';
      _chronicConditions.text = history?.chronicConditions ?? '';
      _currentTreatments.text = history?.currentTreatments ?? '';
      _psychiatricHistory.text = history?.psychiatricHistory ?? '';
      _editing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.patientName != null
        ? 'Antécédents de ${widget.patientName}'
        : 'Antécédents médicaux';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving
                  ? null
                  : (_editing
                      ? _cancelEditing
                      : () => setState(() => _editing = true)),
              child: Text(_editing ? 'Annuler' : 'Modifier'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 16, color: AppColors.muted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Visible seulement par le patient et les '
                          'psychologues qui le suivent.',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 14.5),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _section(
                    controller: _allergies,
                    label: 'Allergies',
                    hint: 'Ex : pénicilline, arachides...',
                  ),
                  _section(
                    controller: _chronicConditions,
                    label: 'Maladies chroniques',
                    hint: 'Ex : diabète, hypertension...',
                  ),
                  _section(
                    controller: _currentTreatments,
                    label: 'Traitements en cours',
                    hint: 'Médicaments, posologie...',
                  ),
                  _section(
                    controller: _psychiatricHistory,
                    label: 'Antécédents psychiatriques',
                    hint: 'Hospitalisations, suivis antérieurs...',
                  ),
                  if (_lastUpdatedLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _lastUpdatedLabel!,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 14),
                    ),
                  ],
                  if (_editing) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _section({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    final value = controller.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          if (_editing)
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(fontSize: 16.5),
              decoration: InputDecoration(hintText: hint),
            )
          else
            Text(
              value.isEmpty ? 'Non renseigné' : value,
              style: TextStyle(
                fontSize: 18,
                height: 1.45,
                color: value.isEmpty ? AppColors.muted : AppColors.text,
              ),
            ),
        ],
      ),
    );
  }
}
