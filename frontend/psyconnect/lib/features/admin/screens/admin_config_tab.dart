import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/splash_screen.dart';
import '../services/admin_service.dart';
import 'admin_reports_tab.dart';
import 'admin_support_messages_tab.dart';

// onglet "Paramètres", 3 sections :
//   1. Réglages plateforme (taux commission)
//   2. Modération (accès aux signalements)
//   3. Communication (broadcast annonce admin -> utilisateurs)
class AdminConfigTab extends StatefulWidget {
  const AdminConfigTab({super.key});

  @override
  State<AdminConfigTab> createState() => _AdminConfigTabState();
}

class _AdminConfigTabState extends State<AdminConfigTab> {
  final _adminService = AdminService();

  // --- commission ---
  bool _loadingRate = true;
  bool _savingRate = false;
  double _commissionRate = 20;
  final _rateController = TextEditingController();

  int _pendingReports = 0;
  int _pendingMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadRate();
    _loadInbox();
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  // commission

  Future<void> _loadRate() async {
    setState(() => _loadingRate = true);
    try {
      final settings = await _adminService.getPlatformSettings();
      if (!mounted) return;
      setState(() {
        _commissionRate = settings.commissionRatePercent;
        _rateController.text = _commissionRate.toStringAsFixed(0);
        _loadingRate = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRate = false);
    }
  }

  Future<void> _loadInbox() async {
    try {
      final reports = await _adminService.listReports(status: 'PENDING');
      if (mounted) setState(() => _pendingReports = reports.length);
    } catch (_) {}
    try {
      final messages =
          await _adminService.listSupportMessages(status: 'PENDING');
      if (mounted) setState(() => _pendingMessages = messages.length);
    } catch (_) {}
  }

  Future<void> _saveRate() async {
    final parsed = double.tryParse(_rateController.text.replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un pourcentage entre 0 et 100.')),
      );
      return;
    }
    setState(() => _savingRate = true);
    try {
      final updated = await _adminService.setCommissionRate(parsed);
      if (!mounted) return;
      setState(() {
        _commissionRate = updated.commissionRatePercent;
        _savingRate = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taux de commission mis à jour.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingRate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de mettre à jour le taux.')),
      );
    }
  }

  Future<void> _editRate() async {
    _rateController.text = _commissionRate.toStringAsFixed(0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Commission de la plateforme'),
        content: TextField(
          controller: _rateController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            suffixText: '%',
            hintText: 'Entre 0 et 100',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _saveRate();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _loadInbox();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
            'Vous devrez vous reconnecter pour accéder à l\'administration.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  // build

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final pseudo = session?.pseudo ?? '';
    final rate = _commissionRate.toStringAsFixed(0);
    final rest = (100 - _commissionRate).toStringAsFixed(0);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadRate(), _loadInbox()]);
        },
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Réglages',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  AppAvatar(name: pseudo.isEmpty ? 'admin' : pseudo, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pseudo,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          session?.role.label ?? '',
                          style: const TextStyle(
                              fontSize: 14.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // SECTION 1 : Réglages plateforme
            const _Heading('Commission'),
            Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prélevée sur chaque paiement réussi',
                            style: TextStyle(
                                fontSize: 15, color: AppColors.muted),
                          ),
                          _loadingRate
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : Text(
                                  '$rate %',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed:
                          _loadingRate || _savingRate ? null : _editRate,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sand,
                        foregroundColor: AppColors.text,
                      ),
                      child: _savingRate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Modifier'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Le reste, $rest %, revient au psychologue.',
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 26),

            // SECTION 2 : Modération
            const _Heading('Modération'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.flag_outlined,
                    tint: AppColors.goldLight,
                    ink: AppColors.goldDark,
                    title: 'Signalements',
                    subtitle: 'Plaintes de patients contre un psy',
                    count: _pendingReports,
                    onTap: () => _open(const AdminReportsPage()),
                  ),
                  _MenuRow(
                    icon: Icons.chat_bubble_outline,
                    tint: AppColors.sand,
                    ink: AppColors.text,
                    title: 'Messages des utilisateurs',
                    subtitle: 'Écrits depuis « Écrire à l\'équipe »',
                    count: _pendingMessages,
                    onTap: () => _open(const AdminSupportMessagesPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // SECTION 3 : Communication
            const _Heading('Communication'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _MenuRow(
                icon: Icons.campaign_outlined,
                tint: AppColors.tealLight,
                ink: AppColors.teal,
                title: 'Envoyer une annonce',
                subtitle: 'À tout le monde, aux patients ou aux psys',
                onTap: () => _open(const _BroadcastPage()),
              ),
            ),
            const SizedBox(height: 18),

            // déconnexion
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _logout,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                child: const Text(
                  'Se déconnecter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastPage extends StatefulWidget {
  const _BroadcastPage();

  @override
  State<_BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<_BroadcastPage> {
  final _adminService = AdminService();

  // --- broadcast ---
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  // audience : 'ALL' | 'PATIENTS' | 'PSYCHOLOGISTS'
  String _audience = 'ALL';
  bool _sending = false;
  String? _sendError;
  String? _sendSuccess;

  static const _audiences = [
    ('ALL', 'Tout le monde'),
    ('PATIENTS', 'Patients'),
    ('PSYCHOLOGISTS', 'Psychologues'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      setState(
          () => _sendError = 'Le titre et le message sont obligatoires.');
      return;
    }

    setState(() {
      _sending = true;
      _sendError = null;
      _sendSuccess = null;
    });

    try {
      final sent = await _adminService.broadcastNotification(
        title: title,
        message: message,
        audience: _audience,
      );
      if (!mounted) return;
      setState(() {
        _sendSuccess = 'Annonce envoyée à $sent destinataire(s).';
        _titleController.clear();
        _messageController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Envoi échoué : $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _clearFeedback() {
    if (_sendError == null && _sendSuccess == null) return;
    setState(() {
      _sendError = null;
      _sendSuccess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Nouvelle annonce',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              'Elle apparaîtra dans « Annonces » chez les personnes choisies.',
              style: TextStyle(fontSize: 15.5, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 22),
          const _Heading('Pour qui ?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in _audiences)
                _AudienceChip(
                  label: label,
                  selected: _audience == value,
                  onTap: () => setState(() => _audience = value),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            maxLength: 80,
            decoration: const InputDecoration(
              hintText: 'Titre de l\'annonce',
            ),
            onChanged: (_) => _clearFeedback(),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _messageController,
            maxLines: 6,
            maxLength: 400,
            decoration: const InputDecoration(
              hintText: 'Votre message…',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => _clearFeedback(),
          ),
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                _sendError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 14.5),
              ),
            ),
          if (_sendSuccess != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                _sendSuccess!,
                style: const TextStyle(
                  color: AppColors.teal,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            onPressed: _sending ? null : _sendBroadcast,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Envoyer l\'annonce'),
          ),
        ),
      ),
    );
  }
}

// page plein écran signalements accessible depuis la section Modération
class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const AdminReportsTab(),
    );
  }
}

// page plein écran messages "Contacter l'administrateur", accessible depuis
// la section Modération
class AdminSupportMessagesPage extends StatelessWidget {
  const AdminSupportMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const AdminSupportMessagesTab(),
    );
  }
}

// widgets locaux

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    required this.subtitle,
    this.count = 0,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right,
                  color: AppColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppColors.background : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
