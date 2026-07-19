import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/session_models.dart';
import '../services/session_service.dart';

// etats internes de l'ecran d'appel
enum _CallPhase { loading, preCall, joining, ended }

// ecran d'appel Jitsi Meet — remplace la simulation Agora
// flux : preCall → startSession (backend) → jitsi.join() → conferenceTerminated
//         → endSession (backend) → ended
// les deux participants (patient ET psy) ouvrent le meme room Jitsi via le
// meetingToken retourne par le backend (psyconnect-{rdvId}-{uuid8})
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.appointmentId,
    required this.peerName,
    this.isVideo = true,
  });

  final int appointmentId;
  final String peerName;
  final bool isVideo;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _sessionService = SessionService();
  final _jitsi = JitsiMeet();

  _CallPhase _phase = _CallPhase.loading;
  String? _error;
  CallSession? _session;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // verifie si une session IN_PROGRESS existe deja pour ce RDV
  // (l'autre participant a peut-etre deja demarre l'appel)
  Future<void> _init() async {
    setState(() {
      _phase = _CallPhase.loading;
      _error = null;
    });
    try {
      final sessions =
          await _sessionService.getSessionsByAppointment(widget.appointmentId);
      final inProgress =
          sessions.where((s) => s.status == SessionStatus.inProgress).toList();
      if (!mounted) return;
      setState(() {
        _session = inProgress.isNotEmpty ? inProgress.first : null;
        _phase = _CallPhase.preCall;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CallPhase.preCall;
        _error = e is ApiException
            ? e.message
            : 'Impossible de charger la session.';
      });
    }
  }

  Future<void> _startCall() async {
    setState(() {
      _phase = _CallPhase.loading;
      _error = null;
    });
    try {
      // si l'autre participant a deja demarre, on rejoint sans appeler startSession
      final session = _session?.status == SessionStatus.inProgress
          ? _session!
          : await _sessionService.startSession(widget.appointmentId);

      if (!mounted) return;
      setState(() {
        _session = session;
        _phase = _CallPhase.joining;
      });

      // lance l'interface Jitsi native (retourne immediatement, l'evenement
      // conferenceTerminated arrive quand l'utilisateur raccroche)
      await _launchJitsi(session.meetingToken);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CallPhase.preCall;
        _error = e is ApiException
            ? e.message
            : "Impossible de démarrer l'appel.";
      });
    }
  }

  Future<void> _launchJitsi(String roomName) async {
    // nom affiché pour l'utilisateur courant dans la conference Jitsi
    final userName =
        context.read<AuthProvider>().session?.pseudo ?? 'Utilisateur';

    final options = JitsiMeetConferenceOptions(
      // meet.jit.si impose un lobby obligatoire pour les utilisateurs anonymes
      // (politique côté serveur, non modifiable côté client).
      // meet.ffmuc.net est un serveur Jitsi public sans cette contrainte.
      serverURL: 'https://meet.ffmuc.net',
      room: roomName,
      configOverrides: {
        'startWithAudioMuted': false,
        'startWithVideoMuted': !widget.isVideo,
        'subject': 'PsyConnect',
        'enableWelcomePage': false,
        'disableInviteFunctions': true,
        'disableReactions': true,
        'prejoinPageEnabled': false,
        // désactiver la salle d'attente (lobby) : sans ça, Jitsi bloque
        // les participants jusqu'à ce qu'un "hôte" les admette
        'lobby.enabled': false,
        'enableLobbyChat': false,
        'disableLobbyPassword': true,
      },
      featureFlags: {
        'add-people.enabled': false,
        'calendar.enabled': false,
        'call-integration.enabled': false,
        'car-mode.enabled': false,
        'close-captions.enabled': false,
        'invite.enabled': false,
        'live-streaming.enabled': false,
        'meeting-name.enabled': false,
        'meeting-password.enabled': false,
        'pip.enabled': true,
        'raise-hand.enabled': false,
        'recording.enabled': false,
        'server-url-change.enabled': false,
        'tile-view.enabled': true,
        'toolbox.alwaysVisible': false,
        'welcomepage.enabled': false,
        'chat.enabled': false,
        'lobby-enabled': false,  // featureFlag pour désactiver le lobby
      },
      userInfo: JitsiMeetUserInfo(
        displayName: userName,
        email: '',
      ),
    );

    final listener = JitsiMeetEventListener(
      conferenceTerminated: (url, error) async {
        await _onConferenceTerminated();
      },
      conferenceWillJoin: (url) {},
      participantLeft: (participantId) {},
    );

    await _jitsi.join(options, listener);
  }

  // appele par Jitsi quand l'utilisateur raccroche (bouton rouge natif)
  Future<void> _onConferenceTerminated() async {
    if (!mounted || _phase == _CallPhase.ended) return;

    final session = _session;
    if (session != null && session.status == SessionStatus.inProgress) {
      try {
        final ended = await _sessionService.endSession(session.id);
        if (!mounted) return;
        setState(() {
          _session = ended;
          _phase = _CallPhase.ended;
        });
      } catch (_) {
        // l'autre participant a peut-etre deja appele endSession, c'est ok
        if (!mounted) return;
        setState(() => _phase = _CallPhase.ended);
      }
    } else {
      if (mounted) setState(() => _phase = _CallPhase.ended);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealDark,
      body: SafeArea(
        child: switch (_phase) {
          _CallPhase.loading || _CallPhase.joining => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          _CallPhase.ended => _buildEndedView(),
          _CallPhase.preCall => _buildPreCallView(),
        },
      ),
    );
  }

  Widget _buildPreCallView() {
    final sessionAlreadyOpen = _session?.status == SessionStatus.inProgress;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.white24,
            child: Text(
              widget.peerName.isNotEmpty
                  ? widget.peerName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.peerName,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isVideo ? 'Appel vidéo' : 'Appel audio',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (sessionAlreadyOpen) ...[
            const SizedBox(height: 4),
            const Text(
              'Session en cours — rejoindre',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 32),
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: AppColors.rose),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            onPressed: _startCall,
            icon: Icon(
                sessionAlreadyOpen ? Icons.video_call : Icons.call),
            label: Text(
              sessionAlreadyOpen
                  ? 'Rejoindre l\'appel en cours'
                  : "Démarrer l'appel",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedView() {
    final duration = _session?.durationSeconds != null
        ? Duration(seconds: _session!.durationSeconds!)
        : Duration.zero;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.call_end, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Appel terminé',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (duration.inSeconds > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Durée : ${_formatDuration(duration)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
