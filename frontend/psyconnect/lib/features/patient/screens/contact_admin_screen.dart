import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/user_role.dart';
import '../services/support_message_service.dart';

class ContactAdminScreen extends StatefulWidget {
  const ContactAdminScreen({
    super.key,
    required this.profileId,
    required this.role,
  });

  final int profileId;
  final UserRole role;

  @override
  State<ContactAdminScreen> createState() => _ContactAdminScreenState();
}

class _ContactAdminScreenState extends State<ContactAdminScreen> {
  final _service = SupportMessageService();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty) {
      setState(() => _error = 'Veuillez indiquer un sujet.');
      return;
    }
    if (message.isEmpty) {
      setState(() => _error = 'Veuillez décrire votre demande.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _service.submitMessage(
        profileId: widget.profileId,
        role: widget.role,
        subject: subject,
        message: message,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Message envoyé'),
          content: const Text(
            'Votre message a bien été transmis à l\'administrateur. '
            'Il vous recontactera si nécessaire.',
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
              'Écrire à l\'équipe',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Une question, un souci technique, ou un problème qui ne '
              'concerne pas un psychologue précis ? L\'équipe PsyConnect vous '
              'répond ici.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Sujet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              maxLength: 120,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'En quelques mots',
                contentPadding: EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 7,
              maxLength: 1000,
              style: const TextStyle(fontSize: 16, height: 1.45),
              decoration: const InputDecoration(
                hintText: 'Expliquez votre demande le plus précisément possible',
                contentPadding: EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
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
                  : const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}
