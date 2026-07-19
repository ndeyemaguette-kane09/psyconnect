import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messaging/services/messaging_service.dart';
import '../../patient/models/notification_models.dart';
import '../../patient/services/notification_service.dart';
import 'agenda_tab.dart';
import 'patients_tab.dart';
import 'psychologist_home_tab.dart';
import 'psychologist_messages_tab.dart';
import 'psychologist_stats_tab.dart';

// conteneur principal du parcours psy — navigation style Lyynk :
// BottomAppBar avec 4 items (2 gauche, 2 droite) + FAB central (Patients)
//
// Layout : Accueil · Agenda   [FAB Patients]   Messages · Stats
class PsychologistShell extends StatefulWidget {
  const PsychologistShell({super.key});

  @override
  State<PsychologistShell> createState() => _PsychologistShellState();
}

// index 2 = Patients (FAB), index 3 = Messages
const _fabTabIndex = 2;
const _messagesTabIndex = 3;

class _PsychologistShellState extends State<PsychologistShell> {
  int _index = 0;
  final _messagingService = MessagingService();
  final _notificationService = NotificationService();

  int _unreadCount = 0;
  Timer? _unreadTimer;

  // Pop-up notifications : suivi des IDs déjà vus dans cette session
  final _seenNotifIds = <int>{};
  bool _notifInitialLoadDone = false;
  OverlayEntry? _notifPopupEntry;

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
    _unreadTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        _refreshUnreadCount();
        _pollNotifications();
      },
    );
    // Premier chargement : initialise la liste des IDs vus (sans pop-up)
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollNotifications());
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _notifPopupEntry?.remove();
    super.dispose();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final conversations = await _messagingService.getMyConversations();
      final total = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
      if (mounted) setState(() => _unreadCount = total);
    } catch (_) {}
  }

  Future<void> _pollNotifications() async {
    final profileId = context.read<AuthProvider>().session?.profileId;
    if (profileId == null) return;
    try {
      final notifs =
          await _notificationService.getNotificationsByUserId(profileId);
      if (!_notifInitialLoadDone) {
        _seenNotifIds.addAll(notifs.map((n) => n.id));
        _notifInitialLoadDone = true;
        return;
      }
      final newNotifs =
          notifs.where((n) => !_seenNotifIds.contains(n.id)).toList();
      _seenNotifIds.addAll(notifs.map((n) => n.id));
      if (newNotifs.isNotEmpty && mounted) {
        _showNotifPopup(newNotifs.first);
      }
    } catch (_) {}
  }

  void _showNotifPopup(AppNotification notif) {
    _notifPopupEntry?.remove();
    _notifPopupEntry = null;

    _notifPopupEntry = OverlayEntry(
      builder: (ctx) => _NotifPopup(
        notification: notif,
        onDismiss: () {
          _notifPopupEntry?.remove();
          _notifPopupEntry = null;
        },
      ),
    );

    Overlay.of(context).insert(_notifPopupEntry!);

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _notifPopupEntry?.remove();
        _notifPopupEntry = null;
      }
    });
  }

  void _selectTab(int i) {
    final leavingMessages = _index == _messagesTabIndex;
    setState(() => _index = i);
    if (leavingMessages) _refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      PsychologistHomeTab(),
      AgendaTab(),
      PatientsTab(),
      PsychologistMessagesTab(),
      PsychologistStatsTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),

      // ── FAB central : Mes patients ───────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectTab(_fabTabIndex),
        backgroundColor:
            _index == _fabTabIndex ? AppColors.tealDark : AppColors.teal,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Patients',
        child: const Icon(Icons.people, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── BottomAppBar : Accueil · Agenda   [FAB]   Messages · Stats ───────
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.white,
        elevation: 8,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                index: 0,
                selectedIndex: _index,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Accueil',
                onTap: () => _selectTab(0),
              ),
              _NavItem(
                index: 1,
                selectedIndex: _index,
                icon: Icons.calendar_today_outlined,
                selectedIcon: Icons.calendar_today,
                label: 'Agenda',
                onTap: () => _selectTab(1),
              ),
              const Spacer(), // espace pour le FAB
              _NavItem(
                index: 3,
                selectedIndex: _index,
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: 'Messages',
                badge: _unreadCount,
                onTap: () => _selectTab(3),
              ),
              _NavItem(
                index: 4,
                selectedIndex: _index,
                icon: Icons.bar_chart_outlined,
                selectedIcon: Icons.bar_chart,
                label: 'Stats',
                onTap: () => _selectTab(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget item de navigation ────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final color = selected ? AppColors.teal : AppColors.muted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.tealLight,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge', style: const TextStyle(fontSize: 10)),
              backgroundColor: AppColors.rose,
              child: Icon(
                selected ? selectedIcon : icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner pop-up animé ──────────────────────────────────────────────────────

class _NotifPopup extends StatefulWidget {
  const _NotifPopup({required this.notification, required this.onDismiss});

  final AppNotification notification;
  final VoidCallback onDismiss;

  @override
  State<_NotifPopup> createState() => _NotifPopupState();
}

class _NotifPopupState extends State<_NotifPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.notification.type) {
      case AppNotificationType.appointment:
        return Icons.calendar_today_outlined;
      case AppNotificationType.reminder:
        return Icons.alarm_outlined;
      case AppNotificationType.payment:
        return Icons.account_balance_wallet_outlined;
      case AppNotificationType.questionnaire:
      case AppNotificationType.questionnaireResult:
        return Icons.assignment_outlined;
      case AppNotificationType.system:
        return Icons.info_outline;
      case AppNotificationType.announcement:
        return Icons.campaign_outlined;
    }
  }

  Color get _accent {
    switch (widget.notification.type) {
      case AppNotificationType.appointment:
        return AppColors.teal;
      case AppNotificationType.reminder:
        return AppColors.gold;
      case AppNotificationType.payment:
        return AppColors.tealDark;
      case AppNotificationType.questionnaire:
      case AppNotificationType.questionnaireResult:
        return AppColors.rose;
      case AppNotificationType.system:
        return AppColors.muted;
      case AppNotificationType.announcement:
        return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.black26,
            child: InkWell(
              onTap: widget.onDismiss,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: _accent.withValues(alpha: 0.10),
                      child: Icon(_icon, color: _accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.notification.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.text,
                            ),
                          ),
                          if (widget.notification.message.isNotEmpty)
                            Text(
                              widget.notification.message,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
