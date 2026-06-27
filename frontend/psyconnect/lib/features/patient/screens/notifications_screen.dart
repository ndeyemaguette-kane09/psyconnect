import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/notification_models.dart';
import '../services/notification_service.dart';

/// Écran "Notifications", partagé patient + psychologue — pas dans la
/// maquette v2, mais rendu possible par un vrai backend
/// (`notification-service`, vérifié en lisant `NotificationController.java`) :
/// GET /notifications/user/{userId} et PUT /notifications/{id}/read.
/// `userId` est un PatientProfile.id ou un PsychologistProfile.id selon
/// l'appelant (cf. `NotificationService`/`OwnershipResolver` côté backend).
///
/// Notifications existantes aujourd'hui : RDV (création, confirmation,
/// refus, annulation) côté patient/psychologue, et décision admin de
/// validation/refus de profil côté psychologue.
///
/// Design libre par rapport à la maquette v2 (qui ne couvre pas cet écran) :
/// regroupement par période + accent de couleur selon le type, pour une
/// hiérarchie plus lisible qu'une simple liste plate.
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
    } catch (_) {
      // Best-effort : si le marquage échoue, l'utilisateur peut retenter en
      // retouchant la notification — pas besoin d'interrompre la navigation.
    }
  }

  /// Regroupe les notifications par période relative pour une lecture plus
  /// naturelle qu'une longue liste plate ("Aujourd'hui", "Cette semaine"...).
  List<MapEntry<String, List<AppNotification>>> get _groups {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<AppNotification>>{};

    for (final n in _notifications) {
      final day = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications',
                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
            if (!_loading && _unreadCount > 0)
              Text(
                '$_unreadCount non lue${_unreadCount > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                          ],
                        ),
                      ),
                    )
                  : _notifications.isEmpty
                      ? ListView(
                          // ListView (pas Center) pour garder le pull-to-refresh.
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 100),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: const BoxDecoration(
                                        color: AppColors.tealLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.notifications_none,
                                          size: 32, color: AppColors.teal),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Rien de nouveau',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    const Text('Vos notifications apparaîtront ici.',
                                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            for (final group in _groups) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                                child: Text(
                                  group.key,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              for (final n in group.value) ...[
                                _NotificationCard(
                                  notification: n,
                                  onTap: () => _markAsRead(n),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ],
                        ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  IconData get _icon {
    switch (notification.type) {
      case AppNotificationType.appointment:
        return Icons.calendar_today_outlined;
      case AppNotificationType.reminder:
        return Icons.alarm_outlined;
      case AppNotificationType.system:
        return Icons.info_outline;
    }
  }

  Color get _accent {
    switch (notification.type) {
      case AppNotificationType.appointment:
        return AppColors.teal;
      case AppNotificationType.reminder:
        return AppColors.gold;
      case AppNotificationType.system:
        return AppColors.muted;
    }
  }

  Color get _accentBg {
    switch (notification.type) {
      case AppNotificationType.appointment:
        return AppColors.tealLight;
      case AppNotificationType.reminder:
        return AppColors.goldLight;
      case AppNotificationType.system:
        return AppColors.scaffoldOuter;
    }
  }

  String get _relativeDate {
    final now = DateTime.now();
    final diff = now.difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    final d = notification.createdAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: notification.isRead ? Colors.transparent : _accent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: _accentBg,
                          child: Icon(_icon, size: 18, color: _accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification.title,
                                  style: TextStyle(
                                    fontWeight:
                                        notification.isRead ? FontWeight.w600 : FontWeight.w700,
                                  )),
                              const SizedBox(height: 4),
                              Text(notification.message,
                                  style: const TextStyle(fontSize: 13, color: AppColors.text)),
                              const SizedBox(height: 6),
                              Text(_relativeDate,
                                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
