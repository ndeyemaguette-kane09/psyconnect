import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../messaging/models/messaging_models.dart';
import '../../messaging/screens/chat_screen.dart';
import '../../messaging/services/messaging_service.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/services/appointment_service.dart';
import '../utils/patient_name.dart';

// onglet "Messages" cote psy, meme principe que cote patient
// une conversation existe que si y'a deja eu un RDV avec ce patient
// noms resolus a part, comme dans PatientsTab
class PsychologistMessagesTab extends StatefulWidget {
  const PsychologistMessagesTab({super.key});

  @override
  State<PsychologistMessagesTab> createState() =>
      _PsychologistMessagesTabState();
}

class _PsychologistMessagesTabState extends State<PsychologistMessagesTab> {
  final _messagingService = MessagingService();
  final _appointmentService = AppointmentService();
  final _profileService = ProfileService();

  bool _loading = true;
  String? _error;
  List<Conversation> _conversations = [];
  List<PatientProfile> _contactsWithoutConversation = [];
  Map<int, PatientProfile> _patientsById = {};

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

    final psychologistId = context.read<AuthProvider>().session?.profileId;
    if (psychologistId == null) {
      setState(() {
        _error = 'Profil psychologue introuvable.';
        _loading = false;
      });
      return;
    }

    try {
      final conversations = await _messagingService.getMyConversations();
      final List<Appointment> appointments = await _appointmentService
          .getAppointmentsByPsychologistId(psychologistId);

      final patientIds = {
        for (final a in appointments) a.patientId,
      };

      final profiles = await Future.wait(patientIds.map(_safeGetPatientProfile));
      final patientsById = {
        for (final p in profiles)
          if (p != null) p.id: p,
      };

      final conversationContactIds = {
        for (final c in conversations) c.patientId,
      };
      final contactsWithoutConversation = patientIds
          .where((id) => !conversationContactIds.contains(id))
          .map((id) => patientsById[id])
          .whereType<PatientProfile>()
          .toList();

      conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _contactsWithoutConversation = contactsWithoutConversation;
        _patientsById = patientsById;
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

  Future<PatientProfile?> _safeGetPatientProfile(int patientId) async {
    try {
      return await _profileService.getPatientProfileById(patientId);
    } catch (_) {
      return null;
    }
  }

  String _displayName(PatientProfile? profile) => patientDisplayName(profile);

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

  Future<void> _startConversation(PatientProfile patient) async {
    try {
      final conversation =
          await _messagingService.startOrGetConversation(patient.id);
      if (!mounted) return;
      _openConversation(conversation.id, _displayName(patient));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de démarrer la conversation.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnonymous = [
      ..._conversations.map((c) => _patientsById[c.patientId]),
      ..._contactsWithoutConversation,
    ].any((p) => p?.anonymousMode == true);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Messages',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (_conversations.isEmpty &&
                _contactsWithoutConversation.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  // pas "confirme" : un RDV suffit quel que soit son
                  // statut cote backend
                  'Pas encore de patients. La messagerie s\'ouvre avec un '
                  'patient dès sa première demande de rendez-vous.',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
              )
            else ...[
              if (_conversations.isNotEmpty)
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      for (final conversation in _conversations)
                        _ConversationRow(
                          title: _displayName(
                              _patientsById[conversation.patientId]),
                          preview: conversation.lastMessagePreview,
                          time: conversation.lastMessageAt,
                          unreadCount: conversation.unreadCount,
                          onTap: () => _openConversation(
                            conversation.id,
                            _displayName(
                                _patientsById[conversation.patientId]),
                          ),
                        ),
                    ],
                  ),
                ),
              if (_contactsWithoutConversation.isNotEmpty) ...[
                if (_conversations.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Text(
                      'Pas encore de discussion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      for (final patient in _contactsWithoutConversation)
                        _ConversationRow(
                          title: _displayName(patient),
                          preview: patient.anonymousMode
                              ? 'Patient anonyme · aucun message'
                              : null,
                          time: null,
                          unreadCount: 0,
                          onTap: () => _startConversation(patient),
                        ),
                    ],
                  ),
                ),
              ],
              if (hasAnonymous)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                  child: Text(
                    'Les patients en mode anonyme apparaissent sous leur '
                    'pseudonyme.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

const _kMonthShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.title,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.onTap,
  });

  final String title;
  final String? preview;
  final DateTime? time;
  final int unreadCount;
  final VoidCallback onTap;

  static const _weekdays = [
    'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.',
  ];

  String get _timeLabel {
    final t = time;
    if (t == null) return '';
    final now = DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;

    if (diff <= 0) {
      return '${t.hour} h ${t.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return 'Hier';
    if (diff < 7) return _weekdays[t.weekday - 1];
    return '${t.day} ${_kMonthShort[t.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = unreadCount > 0;
    final timeLabel = _timeLabel;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            AppAvatar(name: title, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w400,
                            color: unread ? AppColors.teal : AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview ?? 'Démarrer la discussion',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: unread ? AppColors.text : AppColors.muted,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: AppColors.background,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
