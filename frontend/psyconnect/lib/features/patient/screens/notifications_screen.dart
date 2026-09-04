import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../payment/screens/psy_wallet_screen.dart';
import '../../payment/screens/wallet_screen.dart';
import '../../psychologist/screens/agenda_tab.dart';
import '../../psychologist/screens/patients_tab.dart';
import '../../psychologist/screens/psychologist_messages_tab.dart';
import '../models/notification_models.dart';
import '../services/notification_service.dart';
import 'announcements_screen.dart';
import 'appointments_tab.dart';
import 'messages_tab.dart';
import 'questionnaire_history_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.userId});

  final int userId;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();

  bool _loading = true;
  String? _error;
  List<AppNotification> _notifications = [];
  AppNotificationType? _filter;
  UserRole? _role;

  @override
  void initState() {
    super.initState();
    _role = context.read<AuthProvider>().session?.role;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications =
          await _notificationService.getNotificationsByUserId(widget.userId);
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les notifications.';
        _loading = false;
      });
    }
  }

  Widget? _destinationFor(AppNotification n) {
    switch (n.type) {
      case AppNotificationType.questionnaire:
        return _role == UserRole.patient
            ? const QuestionnaireHistoryScreen()
            : null;
      case AppNotificationType.questionnaireResult:
        return _role == UserRole.psychologist
            ? Scaffold(
                appBar: AppBar(title: const Text('Mes patients')),
                body: const PatientsTab(),
              )
            : null;
      case AppNotificationType.announcement:
        return const AnnouncementsScreen();
      case AppNotificationType.appointment:
      case AppNotificationType.reminder:
      case AppNotificationType.session:
        if (_role == UserRole.patient) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rendez-vous')),
            body: const AppointmentsTab(),
          );
        }
        if (_role == UserRole.psychologist) {
          return Scaffold(
            appBar: AppBar(title: const Text('Agenda')),
            body: const AgendaTab(),
          );
        }
        return null;
      case AppNotificationType.payment:
        if (_role == UserRole.patient) {
          return Scaffold(
            appBar: AppBar(title: const Text('Portefeuille')),
            body: WalletScreen(patientId: widget.userId),
          );
        }
        if (_role == UserRole.psychologist) {
          return Scaffold(
            appBar: AppBar(title: const Text('Portefeuille')),
            body: PsyWalletScreen(psychologistId: widget.userId),
          );
        }
        return null;
      case AppNotificationType.newMessage:
        if (_role == UserRole.patient) {
          return Scaffold(
            appBar: AppBar(title: const Text('Messages')),
            body: const MessagesTab(),
          );
        }
        if (_role == UserRole.psychologist) {
          return Scaffold(
            appBar: AppBar(title: const Text('Messages')),
            body: const PsychologistMessagesTab(),
          );
        }
        return null;
      case AppNotificationType.system:
      case AppNotificationType.supportReply:
        return null;
    }
  }

  Future<void> _openNotification(AppNotification n) async {
    await _markAsRead(n);
    if (!mounted) return;
    final destination = _destinationFor(n);
    if (destination != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => destination),
      );
      return;
    }
    await _showDetailSheet(n);
  }

  Future<void> _showDetailSheet(AppNotification n) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                n.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                n.message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await _notificationService.markAsRead(n.id);
      if (!mounted) return;
      setState(() {
        _notifications = [
          for (final existing in _notifications)
            if (existing.id == n.id)
              AppNotification(
                id: existing.id,
                userId: existing.userId,
                title: existing.title,
                message: existing.message,
                type: existing.type,
                createdAt: existing.createdAt,
                isRead: true,
              )
            else
              existing,
        ];
      });
    } catch (_) {}
  }

  List<AppNotification> get _filtered {
    if (_filter == null) return _notifications;
    if (_filter == AppNotificationType.questionnaire) {
      return _notifications
          .where((n) =>
              n.type == AppNotificationType.questionnaire ||
              n.type == AppNotificationType.questionnaireResult)
          .toList();
    }
    return _notifications.where((n) => n.type == _filter).toList();
  }

  List<MapEntry<String, List<AppNotification>>> get _groups {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<AppNotification>>{};

    for (final n in _filtered) {
      final day =
          DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final diff = today.difference(day).inDays;
      final key = diff <= 0
          ? 'Aujourd\'hui'
          : diff == 1
              ? 'Hier'
              : diff < 7
                  ? 'Cette semaine'
                  : 'Plus ancien';
      groups.putIfAbsent(key, () => []).add(n);
    }

    const order = ['Aujourd\'hui', 'Hier', 'Cette semaine', 'Plus ancien'];
    return [
      for (final key in order)
        if (groups[key] != null) MapEntry(key, groups[key]!),
    ];
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 17),
            ),
            if (!_loading && _unreadCount > 0)
              Text(
                '$_unreadCount non lue${_unreadCount > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_loading && _error == null && _notifications.isNotEmpty)
              _FilterBar(
                selected: _filter,
                onSelected: (t) => setState(() => _filter = t),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.teal,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppListSkeleton(itemHeight: 84);
    }

    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: AppErrorState(message: _error!, onRetry: _load),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: AppEmptyState(
              icon: Icons.notifications_none,
              title: 'Rien de nouveau',
              message: 'Vos notifications apparaîtront ici.',
            ),
          ),
        ],
      );
    }

    if (_filtered.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: AppEmptyState(
              icon: Icons.filter_list,
              title: 'Aucune notification',
              message: 'Rien dans cette catégorie pour le moment.',
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final group in _groups) ...[
          _GroupHeader(label: group.key),
          for (var i = 0; i < group.value.length; i++) ...[
            _NotificationRow(
              notification: group.value[i],
              onTap: () => _openNotification(group.value[i]),
            ),
            if (i < group.value.length - 1)
              const Divider(height: 1, indent: 68, endIndent: 16),
          ],
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon {
    switch (notification.type) {
      case AppNotificationType.appointment:
        return Icons.calendar_today_outlined;
      case AppNotificationType.reminder:
        return Icons.alarm_outlined;
      case AppNotificationType.payment:
        return Icons.account_balance_wallet_outlined;
      case AppNotificationType.questionnaire:
        return Icons.assignment_outlined;
      case AppNotificationType.questionnaireResult:
        return Icons.assignment_turned_in_outlined;
      case AppNotificationType.system:
        return Icons.info_outline;
      case AppNotificationType.announcement:
        return Icons.campaign_outlined;
      case AppNotificationType.session:
        return Icons.videocam_outlined;
      case AppNotificationType.supportReply:
        return Icons.support_agent_outlined;
      case AppNotificationType.newMessage:
        return Icons.chat_bubble_outline;
    }
  }

  String get _shortDate {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    final d = notification.createdAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return Material(
      color: unread ? AppColors.tealSoft : AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: unread ? AppColors.tealLight : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  size: 18,
                  color: unread ? AppColors.tealDark : AppColors.muted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.25,
                              color: AppColors.text,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            _shortDate,
                            style: const TextStyle(
                              color: AppColors.faint,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: unread
                            ? AppColors.textSecondary
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unread ? AppColors.teal : Colors.transparent,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 2),
                child: Icon(Icons.chevron_right,
                    size: 18, color: AppColors.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final AppNotificationType? selected;
  final ValueChanged<AppNotificationType?> onSelected;

  static const _filters = [
    AppNotificationType.appointment,
    AppNotificationType.reminder,
    AppNotificationType.payment,
    AppNotificationType.questionnaire,
    AppNotificationType.system,
    AppNotificationType.announcement,
    AppNotificationType.supportReply,
  ];

  bool _isSelected(AppNotificationType type) =>
      selected == type ||
      (type == AppNotificationType.questionnaire &&
          selected == AppNotificationType.questionnaireResult);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            _TypeChip(
              label: 'Tous',
              selected: selected == null,
              onTap: () => onSelected(null),
            ),
            for (final type in _filters) ...[
              const SizedBox(width: 8),
              _TypeChip(
                label: type.label,
                selected: _isSelected(type),
                onTap: () => onSelected(type),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
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
      color: selected ? AppColors.teal : AppColors.white,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
