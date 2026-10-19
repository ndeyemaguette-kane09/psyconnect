import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/models/psychologist_models.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../../patient/models/report_models.dart';
import '../../patient/models/support_message_models.dart';
import 'admin_config_tab.dart';

// Onglet tableau de bord administrateur : KPIs, validations en attente et
// répartition des séances par type. Ces données sont calculées côté client
// depuis la liste des RDV, aucun endpoint dédié n'existe pour l'instant.
class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key, required this.onSeeAllValidations});

  final VoidCallback onSeeAllValidations;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final _adminService = AdminService();

  bool _loading = true;
  String? _error;
  AdminProfileStats? _profileStats;
  List<PsychologistProfile> _pendingPsychologists = [];
  List<Appointment> _appointments = [];
  List<ReportModel> _pendingReports = [];
  List<SupportMessageModel> _pendingMessages = [];

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
      final results = await Future.wait([
        _adminService.getProfileStats(),
        _adminService.listPsychologists(),
        _adminService.listAppointments(),
      ]);
      if (!mounted) return;
      final psychologists = results[1] as List<PsychologistProfile>;
      setState(() {
        _profileStats = results[0] as AdminProfileStats;
        _pendingPsychologists = psychologists
            .where((p) => !p.profileVerified && !p.rejected)
            .toList();
        _appointments = results[2] as List<Appointment>;
        _loading = false;
      });
      _loadInbox();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Impossible de charger le dashboard. Vérifiez que l'API "
            'Gateway et les services auth/user/appointment tournent.';
        _loading = false;
      });
    }
  }

  Future<void> _loadInbox() async {
    try {
      final reports = await _adminService.listReports(status: 'PENDING');
      if (mounted) setState(() => _pendingReports = reports);
    } catch (_) {}
    try {
      final messages =
          await _adminService.listSupportMessages(status: 'PENDING');
      if (mounted) setState(() => _pendingMessages = messages);
    } catch (_) {}
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadInbox();
  }

  int get _appointmentsThisMonth {
    final now = DateTime.now();
    return _appointments
        .where((a) =>
            a.startTime.year == now.year && a.startTime.month == now.month)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bonjour'
        : now.hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';
    final pending = _pendingPsychologists;
    final stats = _profileStats;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_kWeekdays[now.weekday - 1]} ${now.day} '
                    '${_kMonths[now.month - 1]}',
                    style:
                        const TextStyle(fontSize: 15, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    greeting,
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Administration PsyConnect',
                    style: TextStyle(fontSize: 15, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else ...[
              _ValidationsPanel(
                pending: pending,
                onOpen: widget.onSeeAllValidations,
              ),
              if (_pendingReports.isNotEmpty || _pendingMessages.isNotEmpty) ...[
                const SizedBox(height: 26),
                const _Heading('À traiter'),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      if (_pendingReports.isNotEmpty)
                        _InboxRow(
                          icon: Icons.flag_outlined,
                          tint: AppColors.goldLight,
                          ink: AppColors.goldDark,
                          title: 'Signalements',
                          subtitle:
                              '${_pendingReports.length} en attente',
                          count: _pendingReports.length,
                          onTap: () => _openPage(const AdminReportsPage()),
                        ),
                      if (_pendingMessages.isNotEmpty)
                        _InboxRow(
                          icon: Icons.chat_bubble_outline,
                          tint: AppColors.sand,
                          ink: AppColors.text,
                          title: 'Messages des utilisateurs',
                          subtitle: '${_pendingMessages.length} en attente · '
                              '${_pendingMessages.first.subject}',
                          count: _pendingMessages.length,
                          onTap: () =>
                              _openPage(const AdminSupportMessagesPage()),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 26),
              const _Heading('La plateforme'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      _bold('${stats?.totalPatients ?? 0} patients'),
                      const TextSpan(text: ' actifs et '),
                      _bold('${stats?.verifiedPsychologists ?? 0} '
                          'psychologues'),
                      const TextSpan(text: ' vérifiés. '),
                      _bold('$_appointmentsThisMonth séance'
                          '${_appointmentsThisMonth > 1 ? 's' : ''}'),
                      const TextSpan(text: ' ce mois-ci.'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextSpan _bold(String text) => TextSpan(
        text: text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      );
}

const _kWeekdays = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
];

const _kMonths = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

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

class _ValidationsPanel extends StatelessWidget {
  const _ValidationsPanel({
    required this.pending,
    required this.onOpen,
  });

  final List<PsychologistProfile> pending;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Aucun psychologue en attente de validation.',
          style: TextStyle(fontSize: 16, color: AppColors.muted),
        ),
      );
    }
    final count = pending.length;
    final names = pending.take(2).map((p) => p.fullName).join(', ');

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Validations en attente',
            style: TextStyle(color: Color(0xFFC9DCD2), fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            count == 1
                ? '1 psychologue attend votre réponse'
                : '$count psychologues attendent votre réponse',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final p in pending.take(4))
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: AppAvatar(name: p.fullName, size: 40),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count > 2 ? '$names…' : names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFFE3EDE7), fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.teal,
            ),
            child: const Text('Examiner les profils'),
          ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    required this.subtitle,
    required this.count,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            ),
          ],
        ),
      ),
    );
  }
}
