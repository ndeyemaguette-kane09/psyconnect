import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messaging/models/messaging_models.dart';
import '../../messaging/screens/chat_screen.dart';
import '../../messaging/services/messaging_service.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/psychologist_service.dart';

// onglet Messages du patient
//
// une conversation existe que si y'a deja eu un RDV avec ce psy
// l'api renvoie que des ids, les noms sont resolus a part
// comme pour AppointmentsTab
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final _messagingService = MessagingService();
  final _appointmentService = AppointmentService();
  final _psychologistService = PsychologistService();

  bool _loading = true;
  String? _error;
  List<Conversation> _conversations = [];
  List<PsychologistProfile> _contactsWithoutConversation = [];
  Map<int, PsychologistProfile> _psychologistsById = {};

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

    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) {
      setState(() {
        _error = 'Profil patient introuvable.';
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        _messagingService.getMyConversations(),
        _appointmentService.getAppointmentsByPatientId(patientId),
        _psychologistService.getAllPsychologists(),
      ]);
      final conversations = results[0] as List<Conversation>;
      final appointments = results[1] as List<Appointment>;
      final psychologists = results[2] as List<PsychologistProfile>;

      final psychologistsById = {for (final p in psychologists) p.id: p};

      final contactIds = {
        for (final a in appointments) a.psychologistId,
      };
      final conversationContactIds = {
        for (final c in conversations) c.psychologistId,
      };
      final contactsWithoutConversation = contactIds
          .where((id) => !conversationContactIds.contains(id))
          .map((id) => psychologistsById[id])
          .whereType<PsychologistProfile>()
          .toList();

      conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _contactsWithoutConversation = contactsWithoutConversation;
        _psychologistsById = psychologistsById;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger vos messages.';
        _loading = false;
      });
    }
  }

  void _openConversation(int conversationId, String otherDisplayName) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherDisplayName: otherDisplayName,
          ),
        ))
        .then((_) => _load());
  }

  Future<void> _startConversation(PsychologistProfile psychologist) async {
    try {
      final conversation =
          await _messagingService.startOrGetConversation(psychologist.id);
      if (!mounted) return;
      _openConversation(conversation.id, psychologist.fullName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de démarrer la conversation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text('Messages',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off,
                            color: AppColors.muted, size: 36),
                        const SizedBox(height: 8),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                ),
              )
            else if (_conversations.isEmpty && _contactsWithoutConversation.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: AppColors.muted, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Aucune conversation pour le moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Vous pourrez échanger avec votre psychologue dès '
                          'votre premier rendez-vous confirmé.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              if (_conversations.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverList.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final conversation = _conversations[i];
                      final psychologist =
                          _psychologistsById[conversation.psychologistId];
                      return _ConversationCard(
                        title: psychologist?.fullName ?? 'Psychologue',
                        lastMessagePreview: conversation.lastMessagePreview,
                        unreadCount: conversation.unreadCount,
                        onTap: () => _openConversation(
                          conversation.id,
                          psychologist?.fullName ?? 'Psychologue',
                        ),
                      );
                    },
                  ),
                ),
              if (_contactsWithoutConversation.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Démarrer une conversation',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: _contactsWithoutConversation.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final psychologist = _contactsWithoutConversation[i];
                      return _ConversationCard(
                        title: psychologist.fullName,
                        lastMessagePreview: null,
                        unreadCount: 0,
                        onTap: () => _startConversation(psychologist),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.title,
    required this.lastMessagePreview,
    required this.unreadCount,
    required this.onTap,
  });

  final String title;
  final String? lastMessagePreview;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.tealMid),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.tealLight,
              child: Icon(Icons.person, color: AppColors.tealDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    lastMessagePreview ?? 'Démarrer la discussion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
