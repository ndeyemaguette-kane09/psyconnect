import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../messaging/models/messaging_models.dart';
import '../../messaging/screens/chat_screen.dart';
import '../../messaging/services/messaging_service.dart';
import '../../patient/models/notification_models.dart';
import '../../patient/services/notification_service.dart';
import '../../patient/screens/notifications_screen.dart';
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

class _PsychologistShellState extends State<PsychologistShell>
    with WidgetsBindingObserver {
  int _index = 0;
  final _messagingService = MessagingService();
  final _notificationService = NotificationService();
  final _profileService = ProfileService();

  int _unreadCount = 0;
  Timer? _unreadTimer;

  // Pop-up notifications : suivi des IDs déjà vus dans cette session
  final _seenNotifIds = <int>{};
  bool _notifInitialLoadDone = false;
  OverlayEntry? _notifPopupEntry;
  final Map<int, DateTime> _seenConversationActivity = {};
  bool _conversationsSeeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshUnreadCount();
    _unreadTimer = Timer.periodic(
      const Duration(seconds: 10),
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
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    _notifPopupEntry?.remove();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUnreadCount();
      _pollNotifications();
    }
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final conversations = await _messagingService.getMyConversations();
      final total = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
      if (mounted) setState(() => _unreadCount = total);
      _checkNewMessages(conversations);
    } catch (_) {}
  }

  void _checkNewMessages(List<Conversation> conversations) {
    if (!_conversationsSeeded) {
      for (final c in conversations) {
        _seenConversationActivity[c.id] = c.lastMessageAt;
      }
      _conversationsSeeded = true;
      return;
    }
    Conversation? firstNew;
    for (final c in conversations) {
      final seen = _seenConversationActivity[c.id];
      final isNew = c.unreadCount > 0 &&
          (seen == null || c.lastMessageAt.isAfter(seen));
      _seenConversationActivity[c.id] = c.lastMessageAt;
      firstNew ??= isNew ? c : null;
    }
    if (firstNew != null && mounted) {
      _showMessagePopup(firstNew);
    }
  }

  void _showMessagePopup(Conversation conversation) {
    final synthetic = AppNotification(
      id: -conversation.id,
      userId: 0,
      title: 'Nouveau message',
      message: 'Vous avez reçu un nouveau message.',
      type: AppNotificationType.newMessage,
      createdAt: conversation.lastMessageAt,
      isRead: false,
    );
    _showNotifPopup(
      synthetic,
      0,
      onOpen: () async {
        _dismissNotifPopup();
        String name = 'Patient';
        try {
          final patient = await _profileService
              .getPatientProfileById(conversation.patientId);
          final full = '${patient.firstName} ${patient.lastName}'.trim();
          if (full.isNotEmpty) name = full;
        } catch (_) {}
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversation.id,
              otherDisplayName: name,
            ),
          ),
        );
        if (mounted) _refreshUnreadCount();
      },
    );
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
        _showNotifPopup(newNotifs.first, newNotifs.length - 1);
      }
    } catch (_) {}
  }

  void _showNotifPopup(AppNotification notif, int extraCount, {VoidCallback? onOpen}) {
    _notifPopupEntry?.remove();
    _notifPopupEntry = null;

    HapticFeedback.mediumImpact();

    _notifPopupEntry = OverlayEntry(
      builder: (ctx) => _NotifPopup(
        notification: notif,
        extraCount: extraCount,
        onDismiss: _dismissNotifPopup,
        onOpen: onOpen ??
            () {
              _dismissNotifPopup();
              _openNotificationsScreen();
            },
      ),
    );

    Overlay.of(context).insert(_notifPopupEntry!);

    final shown = _notifPopupEntry;
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && identical(_notifPopupEntry, shown)) _dismissNotifPopup();
    });
  }

  void _dismissNotifPopup() {
    _notifPopupEntry?.remove();
    _notifPopupEntry = null;
  }

  Future<void> _openNotificationsScreen() async {
    final profileId = context.read<AuthProvider>().session?.profileId;
    if (profileId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsScreen(userId: profileId)),
    );
    if (mounted) _pollNotifications();
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
        elevation: 6,
        shape: const CircleBorder(),
        tooltip: 'Patients',
        child: const Icon(Icons.people, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── BottomAppBar : Accueil · Agenda   [FAB]   Messages · Stats ───────
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 9,
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x330B3B34),
        elevation: 14,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 66,
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.tealLight : Colors.transparent,
              ),
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge', style: const TextStyle(fontSize: 10)),
                backgroundColor: AppColors.rose,
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
  const _NotifPopup({
    required this.notification,
    required this.extraCount,
    required this.onDismiss,
    required this.onOpen,
  });

  final AppNotification notification;

  final int extraCount;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

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
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
      case AppNotificationType.session:
        return Icons.videocam_outlined;
      case AppNotificationType.supportReply:
        return Icons.support_agent_outlined;
      case AppNotificationType.newMessage:
        return Icons.chat_bubble_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).viewPadding.top;
    final notif = widget.notification;

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
              color: AppColors.tealDark,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon, color: Colors.white, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              notif.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1.25,
                              ),
                            ),
                            if (notif.message.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                notif.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (widget.extraCount > 0) ...[
                              const SizedBox(height: 5),
                              Text(
                                widget.extraCount == 1
                                    ? '+ 1 autre notification'
                                    : '+ ${widget.extraCount} autres notifications',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onDismiss,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close, size: 17, color: Colors.white70),
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
