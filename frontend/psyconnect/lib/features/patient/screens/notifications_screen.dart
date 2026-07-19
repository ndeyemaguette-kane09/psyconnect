import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/notification_models.dart';
import '../services/notification_service.dart';

// Écran de notifications, partagé entre patient et psychologue.
// userId correspond au PatientProfile.id ou au PsychologistProfile.id selon l'appelant.
// Les notifications sont regroupées par période et colorées par type.
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
  // null = "Tous" ; sinon filtre actif (cf. _FilterChips)
  AppNotificationType? _filter;

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
      // Échec silencieux : l'utilisateur peut retapper la notification pour réessayer.
    }
  }

  // Notifications après filtrage par catégorie, avant regroupement par période.
  // Le filtre "questionnaire" inclut aussi "questionnaireResult" : patient
  // (questionnaires à remplir) et psychologue (résultats) voient tous deux
  // leur contenu sous le même chip "Questionnaires".
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

  // Regroupe les notifications par période ("Aujourd'hui", "Hier", etc.).
  List<MapEntry<String, List<AppNotification>>> get _groups {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<AppNotification>>{};

    for (final n in _filtered) {
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
        child: Column(
          children: [
            // Les filtres sont affichés dès qu'il y a des notifications, quel que soit
            // le type présent : patient et psychologue voient toujours les mêmes chips.
            if (!_loading && _error == null && _notifications.isNotEmpty)
              _FilterChips(
                selected: _filter,
                onSelected: (t) => setState(() => _filter = t),
              ),
            Expanded(
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
                                  OutlinedButton(
                                      onPressed: _load, child: const Text('Réessayer')),
                                ],
                              ),
                            ),
                          )
                        : _notifications.isEmpty
                            ? ListView(
                                // ListView et pas Center, pour garder le pull-to-refresh
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
                                              style:
                                                  TextStyle(color: AppColors.muted, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _filtered.isEmpty
                                ? ListView(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 80),
                                        child: Center(
                                          child: Text(
                                            'Aucune notification dans cette catégorie.',
                                            style: const TextStyle(color: AppColors.muted),
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
          ],
        ),
      ),
    );
  }
}

// Chips horizontales de filtrage par catégorie. "Questionnaires" regroupe
// questionnaire et questionnaireResult pour que patient et psychologue partagent le même chip.
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelected,
  });

  final AppNotificationType? selected;
  final ValueChanged<AppNotificationType?> onSelected;

  // Catégories disponibles dans les filtres. Le type questionnaireResult est
  // exclu pour éviter le doublon : il est couvert par le filtre questionnaire.
  static const _filters = [
    AppNotificationType.appointment,
    AppNotificationType.reminder,
    AppNotificationType.payment,
    AppNotificationType.questionnaire, // Représente aussi questionnaireResult.
    AppNotificationType.system,
    AppNotificationType.announcement,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Tous'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final t in _filters) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(t.label),
                // actif si le filtre = ce type OU son pendant (questionnaire ↔ result)
                selected: selected == t ||
                    (t == AppNotificationType.questionnaire &&
                        selected == AppNotificationType.questionnaireResult),
                onSelected: (_) => onSelected(t),
              ),
            ],
          ],
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
    }
  }

  Color get _accent {
    switch (notification.type) {
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
        return const Color(0xFF7C3AED); // violet
    }
  }

  Color get _accentBg {
    switch (notification.type) {
      case AppNotificationType.appointment:
        return AppColors.tealLight;
      case AppNotificationType.reminder:
        return AppColors.goldLight;
      case AppNotificationType.payment:
        return AppColors.tealLight;
      case AppNotificationType.questionnaire:
      case AppNotificationType.questionnaireResult:
        return AppColors.errorBg;
      case AppNotificationType.system:
        return AppColors.scaffoldOuter;
      case AppNotificationType.announcement:
        return const Color(0xFFEDE9FE); // violet clair
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
