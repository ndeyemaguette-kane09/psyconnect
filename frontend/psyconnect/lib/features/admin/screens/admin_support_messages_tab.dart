import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../patient/models/support_message_models.dart';
import '../services/admin_service.dart';

class AdminSupportMessagesTab extends StatefulWidget {
  const AdminSupportMessagesTab({super.key});

  @override
  State<AdminSupportMessagesTab> createState() =>
      _AdminSupportMessagesTabState();
}

class _AdminSupportMessagesTabState extends State<AdminSupportMessagesTab> {
  final _service = AdminService();

  bool _loading = true;
  String? _error;
  List<SupportMessageModel> _messages = [];
  String? _statusFilter;

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
      final list = await _service.listSupportMessages(status: _statusFilter);
      if (!mounted) return;
      setState(() => _messages = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger les messages.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _load();
  }

  void _showDetail(SupportMessageModel message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupportMessageDetailSheet(
        message: message,
        adminService: _service,
        onUpdated: (updated) {
          setState(() {
            _messages = [
              for (final m in _messages) if (m.id == updated.id) updated else m,
            ];
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Messages',
                      style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Tous',
                          selected: _statusFilter == null,
                          onTap: () => _applyFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'En attente',
                          selected: _statusFilter == 'PENDING',
                          onTap: () => _applyFilter('PENDING'),
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Traités',
                          selected: _statusFilter == 'RESOLVED',
                          onTap: () => _applyFilter('RESOLVED'),
                          color: AppColors.teal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.muted)),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                      onPressed: _load,
                                      child: const Text('Réessayer')),
                                ],
                              ),
                            ),
                          ],
                        )
                      : _messages.isEmpty
                          ? ListView(
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(
                                    child: Text(
                                      'Aucun message pour le moment.',
                                      style:
                                          TextStyle(color: AppColors.muted),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                              itemCount: _messages.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _SupportMessageCard(
                                message: _messages[i],
                                onTap: () => _showDetail(_messages[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportMessageCard extends StatelessWidget {
  const _SupportMessageCard({required this.message, required this.onTap});

  final SupportMessageModel message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        message.status == 'PENDING' ? Colors.orange : AppColors.teal;
    final hasName = message.senderName != null &&
        message.senderName!.trim().isNotEmpty;
    final senderLine = hasName
        ? '${message.senderName} · ${message.senderRoleLabel}'
        : '${message.senderRoleLabel} #${message.senderProfileId}';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: AppColors.tealMid,
      shadow: const [],
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.support_agent,
                  color: AppColors.tealDark, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.subject,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          message.statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    senderLine,
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.message,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(message.createdAt!),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
          ],
        ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _SupportMessageDetailSheet extends StatefulWidget {
  const _SupportMessageDetailSheet({
    required this.message,
    required this.adminService,
    required this.onUpdated,
  });

  final SupportMessageModel message;
  final AdminService adminService;
  final ValueChanged<SupportMessageModel> onUpdated;

  @override
  State<_SupportMessageDetailSheet> createState() =>
      _SupportMessageDetailSheetState();
}

class _SupportMessageDetailSheetState
    extends State<_SupportMessageDetailSheet> {
  final _replyController = TextEditingController();
  bool _busy = false;
  String? _actionError;
  late SupportMessageModel _message;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    if (_message.adminReply != null) {
      _replyController.text = _message.adminReply!;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) {
      setState(() =>
          _actionError = 'Écrivez une réponse avant de l\'envoyer.');
      return;
    }
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final updated = await widget.adminService.replyToSupportMessage(
        _message.id,
        reply: text,
      );
      if (!mounted) return;
      setState(() => _message = updated);
      widget.onUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réponse envoyée à l\'expéditeur.')),
      );
    } catch (e) {
      setState(() => _actionError = 'Envoi impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopen() async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final updated = await widget.adminService.resolveSupportMessage(
        _message.id,
        status: 'PENDING',
      );
      if (!mounted) return;
      setState(() => _message = updated);
      widget.onUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message rouvert.')),
      );
    } catch (e) {
      setState(() => _actionError = 'Action impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasName = _message.senderName != null &&
        _message.senderName!.trim().isNotEmpty;
    final senderLine = hasName
        ? '${_message.senderName} (${_message.senderRoleLabel})'
        : '${_message.senderRoleLabel} #${_message.senderProfileId}';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.tealMid,
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.support_agent,
                    color: AppColors.tealDark, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _message.subject,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow('Expéditeur', senderLine),
            if (_message.senderPhone != null &&
                _message.senderPhone!.trim().isNotEmpty)
              _InfoRow('Téléphone', _message.senderPhone!),
            _InfoRow('Statut', _message.statusLabel),
            if (_message.createdAt != null)
              _InfoRow('Envoyé le', _fmtDate(_message.createdAt!)),
            const SizedBox(height: 12),
            Text('Message', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(_message.message,
                style: Theme.of(context).textTheme.bodyMedium),
            if (_message.adminReply != null &&
                _message.adminReply!.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _message.repliedAt != null
                          ? 'Votre réponse (${_fmtDate(_message.repliedAt!)})'
                          : 'Votre réponse',
                      style: const TextStyle(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(_message.adminReply!,
                        style: const TextStyle(
                            color: AppColors.tealDark, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Répondre à l\'expéditeur',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _replyController,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Votre réponse sera envoyée en notification à '
                    '${hasName ? _message.senderName : 'l\'expéditeur'}…',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.tealMid),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_actionError != null) ...[
              const SizedBox(height: 12),
              Text(_actionError!,
                  style: const TextStyle(color: AppColors.rose, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _sendReply,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    minimumSize: const Size.fromHeight(44)),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Envoyer la réponse'),
              ),
            ),
            if (_message.status == 'RESOLVED') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _reopen,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
),
                  child: const Text('Rouvrir ce message'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.teal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.white,
          border: Border.all(
              color: selected ? activeColor : AppColors.tealMid),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? activeColor : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
