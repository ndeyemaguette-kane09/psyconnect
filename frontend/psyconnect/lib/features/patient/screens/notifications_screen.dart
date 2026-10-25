import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../payment/screens/psy_wallet_screen.dart';
import '../../payment/screens/wallet_screen.dart';
import '../../psychologist/screens/agenda_tab.dart';
import '../../psychologist/screens/patients_tab.dart';
import '../../psychologist/screens/psychologist_messages_tab.dart';
import '../models/appointment_models.dart';
import '../models/notification_models.dart';
import '../services/appointment_service.dart';
import '../services/notification_service.dart';
import 'announcements_screen.dart';
import 'appointments_tab.dart';
import 'cancelled_appointment_screen.dart';
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
  final _appointmentService = AppointmentService();

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

  Future<Widget?> _cancelledAppointmentFor(AppNotification n) async {
    final appointmentId = n.appointmentId;
    final role = _role;
    if (appointmentId == null ||
        (role != UserRole.patient && role != UserRole.psychologist)) {
      return null;
    }
    try {
      final appointment =
          await _appointmentService.getAppointmentById(appointmentId);
      if (appointment.status != AppointmentStatus.cancelled) return null;
      return CancelledAppointmentScreen(
        appointment: appointment,
        viewedByPsychologist: role == UserRole.psychologist,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNotification(AppNotification n) async {
    await _markAsRead(n);
    if (!mounted) return;
    final cancelled = await _cancelledAppointmentFor(n);
    if (!mounted) return;
    if (cancelled != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => cancelled),
      );
      return;
    }
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
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                n.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                n.message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.55,
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
                appointmentId: existing.appointmentId,
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

  Future<void> _markAllAsRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    for (final n in unread) {
      await _markAsRead(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentTypes = {
      for (final n in _notifications)
        n.type == AppNotificationType.questionnaireResult
            ? AppNotificationType.questionnaire
            : n.type,
    };

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!_loading && _unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Tout marquer lu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Notifications',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            if (!_loading && _unreadCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  '$_unreadCount non lue${_unreadCount > 1 ? 's' : ''}',
                  style:
                      const TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 16),
            if (!_loading &&
                _error == null &&
                _notifications.isNotEmpty &&
                presentTypes.length > 1) ...[
              _FilterBar(
                types: _FilterBar.ordered
                    .where((t) => presentTypes.contains(t))
                    .toList(),
                selected: _filter,
                onSelected: (t) => setState(() => _filter = t),
              ),
              const SizedBox(height: 16),
            ],
            ..._buildBody(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_error != null) {
      return [AppErrorState(message: _error!, onRetry: _load)];
    }

    if (_notifications.isEmpty || _filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _notifications.isEmpty
                ? 'Rien de nouveau pour l\'instant.'
                : 'Rien dans cette catégorie pour le moment.',
            style: const TextStyle(fontSize: 15.5, color: AppColors.muted),
          ),
        ),
      ];
    }

    return [
      for (final group in _groups) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            group.key,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final n in group.value)
                _NotificationRow(
                  notification: n,
                  onTap: () => _openNotification(n),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    ];
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

  (Color, Color) get _tint {
    switch (notification.type) {
      case AppNotificationType.appointment:
      case AppNotificationType.reminder:
      case AppNotificationType.session:
        return (AppColors.tealLight, AppColors.teal);
      case AppNotificationType.payment:
      case AppNotificationType.questionnaire:
      case AppNotificationType.questionnaireResult:
        return (AppColors.goldLight, AppColors.goldDark);
      default:
        return (AppColors.sand, AppColors.text);
    }
  }

  String get _shortDate {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    final d = notification.createdAt;
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final (bg, ink) = _tint;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(_icon, size: 19, color: ink),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.3,
                            color: AppColors.text,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _shortDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: unread ? AppColors.teal : AppColors.muted,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(left: 10, top: 6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.types,
    required this.selected,
    required this.onSelected,
  });

  final List<AppNotificationType> types;
  final AppNotificationType? selected;
  final ValueChanged<AppNotificationType?> onSelected;

  static const ordered = [
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
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _TypeChip(
            label: 'Tout',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final type in types) ...[
            const SizedBox(width: 8),
            _TypeChip(
              label: type.label,
              selected: _isSelected(type),
              onTap: () => onSelected(type),
            ),
          ],
        ],
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
      color: selected ? AppColors.teal : AppColors.sand,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.background : AppColors.text,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
