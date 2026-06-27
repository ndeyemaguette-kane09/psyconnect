import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../messaging/services/messaging_service.dart';
import 'appointments_tab.dart';
import 'messages_tab.dart';
import 'patient_home_screen.dart';
import 'profile_tab.dart';
import 'psychologist_search_screen.dart';

/// Conteneur principal du parcours patient : un `Scaffold` avec une barre
/// de navigation en bas, fidèle à la maquette v2 (classe CSS `.bnav`/`.ni`,
/// 5 items : Accueil, Chercher, RDV, Messages, Profil — cf.
/// `docs/PsyConnect Maquettes v2.html`).
///
/// Utilise `IndexedStack` pour garder chaque onglet en mémoire (état des
/// formulaires/scroll préservé) plutôt que de recréer le widget à chaque
/// changement d'onglet.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

// Index 3 = onglet "Messages" (cf. NavigationDestination ci-dessous).
const _messagesTabIndex = 3;

class _PatientShellState extends State<PatientShell> {
  int _index = 0;
  final _messagingService = MessagingService();
  int _unreadCount = 0;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
    // Même logique de polling que le reste de la messagerie (cf.
    // chat_screen.dart, pas de WebSocket) : on rafraîchit le badge
    // périodiquement pour qu'il reste à jour même sans interaction.
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

  void _goToSearch() => setState(() => _index = 1);

  // Index 4 = onglet "Profil" (cf. NavigationDestination ci-dessous) :
  // utilisé par le bandeau "Complétez votre profil" de PatientHomeScreen.
  void _goToProfile() => setState(() => _index = 4);

  void _onDestinationSelected(int i) {
    final leavingMessages = _index == _messagesTabIndex;
    setState(() => _index = i);
    // En quittant l'onglet Messages, les conversations consultées ont été
    // marquées lues (cf. ChatScreen.markConversationRead) : on rafraîchit
    // le badge tout de suite plutôt que d'attendre le prochain tick du
    // Timer périodique.
    if (leavingMessages) _refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      PatientHomeScreen(onOpenSearch: _goToSearch, onOpenProfile: _goToProfile),
      const PsychologistSearchScreen(),
      const AppointmentsTab(),
      const MessagesTab(),
      const ProfileTab(),
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
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: AppColors.teal),
            label: 'Chercher',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: AppColors.teal),
            label: 'RDV',
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.teal),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
