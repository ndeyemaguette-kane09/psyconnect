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

  @override
  Widget build(BuildContext context) {
    final title = widget.patientName != null
        ? 'Antécédents – ${widget.patientName}'
        : 'Antécédents médicaux';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 18, color: AppColors.tealDark),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Visible uniquement par le patient et le(s) psychologue(s) '
                              'qui le suivent.',
                              style: TextStyle(color: AppColors.tealDark, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!, style: const TextStyle(color: AppColors.rose)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _field(
                      controller: _allergies,
                      label: 'Allergies',
                      hint: 'Ex : pénicilline, arachides...',
                      icon: Icons.warning_amber_outlined,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _chronicConditions,
                      label: 'Maladies chroniques',
                      hint: 'Ex : diabète, hypertension...',
                      icon: Icons.monitor_heart_outlined,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _currentTreatments,
                      label: 'Traitements en cours',
                      hint: 'Médicaments, posologie...',
                      icon: Icons.medication_outlined,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _psychiatricHistory,
                      label: 'Antécédents psychiatriques',
                      hint: 'Hospitalisations, suivis antérieurs...',
                      icon: Icons.psychology_outlined,
                    ),
                    if (_lastUpdatedLabel != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _lastUpdatedLabel!,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
