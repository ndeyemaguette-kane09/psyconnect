import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/report_models.dart';
import '../services/report_service.dart';

// écran de signalement d'un psychologue par un patient.
// accessible depuis le profil du psy via le bouton drapeau en AppBar.
// champs : motif (dropdown), description (optionnel), pièce jointe (optionnel)
class ReportPsychologistScreen extends StatefulWidget {
  const ReportPsychologistScreen({
    super.key,
    required this.psychologistId,
    required this.psychologistName,
  });

  final int psychologistId;
  final String psychologistName;

  @override
  State<ReportPsychologistScreen> createState() =>
      _ReportPsychologistScreenState();
}

class _ReportPsychologistScreenState extends State<ReportPsychologistScreen> {
  final _service = ReportService();
  final _descController = TextEditingController();

  ReportReasonOption? _selectedReason;
  String? _filePath;
  String? _fileName;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
    });
  }

  void _removeFile() => setState(() {
        _filePath = null;
        _fileName = null;
      });

  Future<void> _submit() async {
    if (_selectedReason == null) {
      setState(() => _error = 'Veuillez choisir un motif.');
      return;
    }

    final session = context.read<AuthProvider>().session;
    final patientId = session?.profileId;
    if (patientId == null) {
      setState(
          () => _error = 'Profil patient introuvable. Reconnectez-vous.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _service.submitReport(
        patientId: patientId,
        psychologistId: widget.psychologistId,
        reason: _selectedReason!.value,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        filePath: _filePath,
        fileNameOverride: _fileName,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Signalement envoyé'),
          content: const Text(
            'Votre signalement a bien été transmis à l\'administrateur. '
            'Il sera examiné dans les meilleurs délais.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Signaler un psychologue',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Vous signalez ${widget.psychologistName}. L\'équipe PsyConnect '
              'examinera votre signalement, et vous resterez anonyme.',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Que s\'est-il passé ?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  for (final r in reportReasons)
                    InkWell(
                      onTap: () => setState(() {
                        _selectedReason = r;
                        _error = null;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.label,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: _selectedReason == r
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              _selectedReason == r
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _selectedReason == r
                                  ? AppColors.teal
                                  : AppColors.borderStrong,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Racontez si vous le souhaitez',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              maxLines: 5,
              maxLength: 500,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Les faits, avec le plus de précision possible',
                contentPadding: EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Une preuve ? (facultatif)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Une capture d\'écran ou un document : JPG, PNG ou PDF, '
              '20 Mo maximum.',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_fileName != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.tealLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.attach_file,
                          color: AppColors.teal, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _fileName!,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.muted, size: 20),
                      tooltip: 'Retirer',
                      onPressed: _removeFile,
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Joindre un fichier'),
              ),
            const SizedBox(height: 28),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 14.5),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Envoyer le signalement'),
            ),
          ],
        ),
      ),
    );
  }
}
