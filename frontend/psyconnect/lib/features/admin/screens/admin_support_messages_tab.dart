import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
    Navigator.of(context).push(MaterialPageRoute(
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('PENDING', 'À traiter'),
      ('RESOLVED', 'Traités'),
      (null, 'Tous'),
    ];

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Messages',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (value, label) in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: label,
                        selected: _statusFilter == value,
                        onTap: () => _applyFilter(value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (_messages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Aucun message pour le moment.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              )
            else
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final m in _messages)
                      _SupportMessageCard(
                        message: m,
                        onTap: () => _showDetail(m),
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

String _fmtDate(DateTime d) => '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

String _senderName(SupportMessageModel m) {
  final name = m.senderName?.trim() ?? '';
  return name.isNotEmpty ? name : '${m.senderRoleLabel} #${m.senderProfileId}';
}

class _SupportMessageCard extends StatelessWidget {
  const _SupportMessageCard({required this.message, required this.onTap});

  final SupportMessageModel message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pending = message.status == 'PENDING';
    final name = _senderName(message);
    final d = message.createdAt;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(name: name, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (d != null)
                        Text(
                          '${d.day} ${_kMonths[d.month - 1]}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                pending ? FontWeight.w800 : FontWeight.w400,
                            color: pending ? AppColors.teal : AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${message.senderRoleLabel} · ${message.subject}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 13.5, color: AppColors.muted),
                  ),
                  Text(
                    message.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: pending ? AppColors.text : AppColors.muted,
                    ),
                  ),
                  if (pending)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'À traiter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
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
    final name = _senderName(_message);
    final hasName = _message.senderName != null &&
        _message.senderName!.trim().isNotEmpty;
    final phone = _message.senderPhone?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _message.subject,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                AppAvatar(name: name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        [
                          _message.senderRoleLabel,
                          if (phone.isNotEmpty) phone,
                          if (_message.createdAt != null)
                            _fmtDate(_message.createdAt!),
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
            child: Text(
              '« ${_message.message.trim()} »',
              style: const TextStyle(
                fontSize: 16,
                height: 1.55,
                color: AppColors.text,
              ),
            ),
          ),
          if (_message.adminReply != null &&
              _message.adminReply!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _message.repliedAt != null
                        ? 'Votre réponse, le ${_fmtDate(_message.repliedAt!)}'
                        : 'Votre réponse',
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _message.adminReply!,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 26, 4, 10),
            child: Text(
              'Répondre',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          TextField(
            controller: _replyController,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Envoyée en notification à '
                  '${hasName ? _message.senderName : 'l\'expéditeur'}',
            ),
          ),
          if (_actionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                _actionError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 14),
              ),
            ),
          if (_message.status == 'RESOLVED')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _reopen,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                ),
                child: const Text(
                  'Rouvrir ce message',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 10, 20, 14 + MediaQuery.of(context).viewInsets.bottom),
          child: FilledButton(
            onPressed: _busy ? null : _sendReply,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : AppColors.sand,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.background : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
