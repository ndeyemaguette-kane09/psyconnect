import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../messaging/services/messaging_service.dart';
import 'agenda_tab.dart';
import 'patients_tab.dart';
import 'psychologist_home_tab.dart';
import 'psychologist_messages_tab.dart';
import 'psychologist_stats_tab.dart';

/// Conteneur principal du parcours psychologue : un `Scaffold` avec une
/// barre de navigation en bas, fidèle à la maquette v2 ("Tableau de Bord
/// Psychologue", 5 items : Accueil, Agenda, Patients, Messages, Stats —
/// distincts de la nav patient, cf. `docs/PsyConnect Maquettes v2.html`).
///
/// Même architecture que `PatientShell` : `IndexedStack` pour garder l'état
/// de chaque onglet, et même badge "messages non lus" sur l'onglet Messages
/// (cf. PatientShell pour le détail du polling).
class PsychologistShell extends StatefulWidget {
  const PsychologistShell({super.key});

  @override
  State<PsychologistShell> createState() => _PsychologistShellState();
}

// Index 3 = onglet "Messages" (cf. NavigationDestination ci-dessous).
const _messagesTabIndex = 3;

class _PsychologistShellState extends State<PsychologistShell> {
  int _index = 0;
  final _messagingService = MessagingService();
  int _unreadCount = 0;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
    _unreadTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshUnreadCount(),
    );
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final conversations = await _messagingService.getMyConversations();
      final total = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
      if (mounted) setState(() => _unreadCount = total);
    } catch (_) {
      // Échec silencieux : le badge garde sa dernière valeur connue plutôt
      // que de planter la nav, comme les autres compteurs de l'app.
    }
  }

  void _onDestinationSelected(int i) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.tealLight,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.teal),
            label: 'Accueil',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: AppColors.teal),
            label: 'Agenda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppColors.teal),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.chat_bubble, color: AppColors.teal),
            ),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.teal),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
