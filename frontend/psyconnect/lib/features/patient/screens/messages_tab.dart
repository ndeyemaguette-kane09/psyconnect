import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/loading_state.dart';
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
        const SnackBar(
            content: Text('Impossible de démarrer la conversation.')),
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
                child:
                    AppLoadingState(label: 'Chargement de vos conversations…'),
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
            else if (_conversations.isEmpty &&
                _contactsWithoutConversation.isEmpty)
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
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              if (_conversations.isNotEmpty)
                SliverList.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, i) {
                    final conversation = _conversations[i];
                    final psychologist =
                        _psychologistsById[conversation.psychologistId];
                    final name = psychologist?.fullName ?? 'Psychologue';
                    return _ConversationRow(
                      title: name,
                      preview: conversation.lastMessagePreview,
                      time: conversation.lastMessageAt,
                      unreadCount: conversation.unreadCount,
                      showDivider: i != _conversations.length - 1,
                      onTap: () => _openConversation(conversation.id, name),
                    );
                  },
                ),
              if (_contactsWithoutConversation.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'DÉMARRER UNE CONVERSATION',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: _contactsWithoutConversation.length,
                  itemBuilder: (context, i) {
                    final psychologist = _contactsWithoutConversation[i];
                    return _ConversationRow(
                      title: psychologist.fullName,
                      preview: null,
                      time: null,
                      unreadCount: 0,
                      showDivider:
                          i != _contactsWithoutConversation.length - 1,
                      onTap: () => _startConversation(psychologist),
                    );
                  },
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.title,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.showDivider,
    required this.onTap,
  });

  final String title;
  final String? preview;
  final DateTime? time;
  final int unreadCount;
  final bool showDivider;
  final VoidCallback onTap;

  static const _weekdays = [
    'lun.',
    'mar.',
    'mer.',
    'jeu.',
    'ven.',
    'sam.',
    'dim.',
  ];

  String get _timeLabel {
    final t = time;
    if (t == null) return '';
    final now = DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;

    if (diff <= 0) {
      return '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return 'Hier';
    if (diff < 7) return _weekdays[t.weekday - 1];
    return '${t.day.toString().padLeft(2, '0')}/'
        '${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = unreadCount > 0;
    final timeLabel = _timeLabel;

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  AppAvatar(name: title, size: 48, showRing: false),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preview ?? 'Démarrer la discussion',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: unread
                                ? AppColors.textSecondary
                                : AppColors.muted,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                            color: unread ? AppColors.teal : AppColors.faint,
                          ),
                        ),
                      if (unread) ...[
                        const SizedBox(height: 7),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (showDivider)
              const Padding(
                padding: EdgeInsets.only(left: 82),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
