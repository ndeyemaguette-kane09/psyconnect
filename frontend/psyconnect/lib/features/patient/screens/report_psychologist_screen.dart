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
      appBar: AppBar(title: const Text('Signaler un psychologue')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // bannière d'info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.tealDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vous signalez ${widget.psychologistName}. '
                        'Votre signalement sera examiné par l\'administrateur. '
                        'Vous resterez anonyme.',
                        style: const TextStyle(
                            color: AppColors.tealDark, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // motif
              Text('Motif *', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<ReportReasonOption>(
                initialValue: _selectedReason,
                hint: const Text('Choisir un motif'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.tealMid),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                items: reportReasons
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedReason = v;
                  _error = null;
                }),
                isExpanded: true,
              ),
              const SizedBox(height: 20),

              // description (optionnelle)
              Text('Détails (optionnel)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText:
                      'Décrivez les faits avec le plus de précision possible…',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.tealMid),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),

              // pièce jointe (photo ou PDF)
              Text('Preuve (optionnel)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Vous pouvez joindre une capture d\'écran ou un document '
                '(JPG, PNG, PDF – max 20 Mo).',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),

              if (_fileName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.tealMid),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file,
                          color: AppColors.teal, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fileName!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.muted, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _removeFile,
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Joindre un fichier'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.tealMid),
                    ),
                  ),
                ),

              const SizedBox(height: 28),

              // erreur
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.rose, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],

              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
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
      ),
    );
  }
}
