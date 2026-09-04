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
      appBar: AppBar(title: const Text('Contacter l\'administrateur')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.support_agent_outlined,
                        color: AppColors.tealDark, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Une question, un problème technique, un signalement '
                        'qui ne concerne pas un psychologue précis ? '
                        'Écrivez directement à l\'administrateur.',
                        style: TextStyle(
                            color: AppColors.tealDark, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Sujet *', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectController,
                maxLength: 120,
                decoration: InputDecoration(
                  hintText: 'Résumez votre demande en quelques mots',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.tealMid),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),
              Text('Message *',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Décrivez votre demande le plus précisément possible…',
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.tealMid),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
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
                    : const Text('Envoyer le message'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
