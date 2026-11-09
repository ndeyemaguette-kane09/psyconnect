import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../call/models/session_models.dart';
import '../../call/services/session_service.dart';
import '../models/psychologist_models.dart';
import '../services/psychologist_service.dart';

// écran SOS patient : liste des psys disponibles pour urgence maintenant.
// affiche un bouton "Appeler" pour chaque psy, lance un appel Jitsi direct
// sans passer par le workflow RDV / paiement.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _psychologistService = PsychologistService();
  final _sessionService = SessionService();

  bool _loading = true;
  String? _error;
  List<PsychologistProfile> _available = [];
  // ID du psy sur lequel le patient est en train de cliquer (pour le loader)
  int? _callingPsyId;

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
      final list = await _psychologistService.getEmergencyPsychologists();
      if (!mounted) return;
      setState(() {
        _available = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la liste. Vérifiez votre connexion.';
        _loading = false;
      });
    }
  }

  Future<void> _callPsychologist(PsychologistProfile psy) async {
    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) return;

    setState(() => _callingPsyId = psy.id);
    try {
      final session = await _sessionService.startEmergencySession(
        patientId: patientId,
        psychologistId: psy.id,
      );
      if (!mounted) return;
      setState(() => _callingPsyId = null);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _EmergencyJitsiLauncher(
            session: session,
            peerName: psy.fullName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _callingPsyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Impossible de démarrer l\'appel. Réessayez dans un instant.'),
          backgroundColor: AppColors.emergency,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.emergency,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            Text(
              'Aide immédiate',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Vous n\'êtes pas seul(e). Ces psychologues peuvent vous '
              'écouter maintenant, sans rendez-vous.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'En cas de danger immédiat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  _EmergencyNumber(number: '1515', label: 'SAMU'),
                  Divider(height: 1, color: AppColors.sand),
                  _EmergencyNumber(number: '17', label: 'Police'),
                  Divider(height: 1, color: AppColors.sand),
                  _EmergencyNumber(number: '18', label: 'Pompiers'),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Disponibles maintenant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            _buildList(),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: AppLoadingState(label: 'Recherche de psychologues disponibles…'),
      );
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_available.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_search_outlined,
        title: 'Aucun psychologue disponible pour l\'instant',
        message: 'Nos psychologues activent leur disponibilité manuellement. '
            'Revenez dans quelques minutes ou prenez rendez-vous.',
        accent: AppColors.emergency,
        actionLabel: 'Actualiser',
        onAction: _load,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final psy in _available)
            _PsychologistSosRow(
              psychologist: psy,
              isCalling: _callingPsyId == psy.id,
              onCall: () => _callPsychologist(psy),
            ),
        ],
      ),
    );
  }
}

class _PsychologistSosRow extends StatelessWidget {
  const _PsychologistSosRow({
    required this.psychologist,
    required this.isCalling,
    required this.onCall,
  });

  final PsychologistProfile psychologist;
  final bool isCalling;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AppAvatar(name: psychologist.fullName, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  psychologist.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  psychologist.specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                if (psychologist.offersFreeSessions) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Consultation solidaire, gratuite',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: isCalling ? null : onCall,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergency,
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: isCalling
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.call, size: 16),
            label: Text(isCalling ? '...' : 'Appeler',
                style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// lance directement Jitsi pour une session d'urgence déjà créée côté backend.
// pas besoin de passer par la logique startSession (session déjà IN_PROGRESS).
class _EmergencyJitsiLauncher extends StatefulWidget {
  const _EmergencyJitsiLauncher({
    required this.session,
    required this.peerName,
  });

  final CallSession session;
  final String peerName;

  @override
  State<_EmergencyJitsiLauncher> createState() =>
      _EmergencyJitsiLauncherState();
}

class _EmergencyJitsiLauncherState extends State<_EmergencyJitsiLauncher> {
  final _jitsi = JitsiMeet();
  final _sessionService = SessionService();
  bool _joining = true;
  bool _ended = false;
  int? _durationSeconds;

  @override
  void initState() {
    super.initState();
    _launchJitsi();
  }

  Future<void> _launchJitsi() async {
    final userName =
        context.read<AuthProvider>().session?.pseudo ?? 'Patient';

    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.ffmuc.net',
      room: widget.session.meetingToken,
      configOverrides: {
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
        'subject': 'PsyConnect SOS',
        'enableWelcomePage': false,
        'disableInviteFunctions': true,
        'disableReactions': true,
        'prejoinPageEnabled': false,
        'lobby.enabled': false,
        'enableLobbyChat': false,
        'disableLobbyPassword': true,
      },
      featureFlags: {
        'add-people.enabled': false,
        'calendar.enabled': false,
        'call-integration.enabled': false,
        'invite.enabled': false,
        'live-streaming.enabled': false,
        'meeting-name.enabled': false,
        'meeting-password.enabled': false,
        'pip.enabled': true,
        'raise-hand.enabled': false,
        'recording.enabled': false,
        'tile-view.enabled': true,
        'toolbox.alwaysVisible': false,
        'chat.enabled': false,
        'lobby-enabled': false,
      },
      userInfo: JitsiMeetUserInfo(displayName: userName, email: ''),
    );

    final listener = JitsiMeetEventListener(
      conferenceTerminated: (url, error) async {
        await _onEnded();
      },
      conferenceWillJoin: (url) {
        if (mounted) setState(() => _joining = false);
      },
      participantLeft: (id) {},
    );

    await _jitsi.join(options, listener);
  }

  Future<void> _onEnded() async {
    if (!mounted || _ended) return;
    final start = widget.session.startedAt;
    final end = DateTime.now();
    final dur = start != null ? end.difference(start).inSeconds : 0;

    try {
      await _sessionService.endSession(widget.session.id);
    } catch (_) {
      // l'autre participant a peut-être déjà appelé endSession
    }

    if (!mounted) return;
    setState(() {
      _ended = true;
      _durationSeconds = dur;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ended) {
      final d = Duration(seconds: _durationSeconds ?? 0);
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');

      return Scaffold(
        backgroundColor: AppColors.tealDark,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.white70, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Session terminée',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  if ((_durationSeconds ?? 0) > 0) ...[
                    const SizedBox(height: 8),
                    Text('Durée : $m:$s',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Prenez soin de vous. Vous n\'êtes pas seul(e).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context)
                      ..pop()
                      ..pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                    child: const Text('Retour à l\'accueil'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.tealDark,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _joining
                    ? 'Connexion à ${widget.peerName}…'
                    : 'Appel en cours…',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyNumber extends StatelessWidget {
  const _EmergencyNumber({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 15.5, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
