import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/session_models.dart';
import '../services/session_service.dart';

// etats internes de l'ecran d'appel
enum _CallPhase { loading, preCall, joining, ended }

// ecran d'appel Jitsi Meet : patient et psy rejoignent le meme salon,
// renvoye par le backend pour ce rendez-vous
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
  // affiche un message informatif apres un raccrochage volontaire ou une
  // coupure, tant que la seance reste rejoignable (cf. _onConferenceTerminated)
  String? _info;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // au chargement : session en cours -> rejoindre, terminee -> recap, aucune -> demarrer
  Future<void> _init() async {
    setState(() {
      _phase = _CallPhase.loading;
      _error = null;
    });
    try {
      final sessions =
          await _sessionService.getSessionsByAppointment(widget.appointmentId);
      // la plus recente en premier (startedAt manquant = tres ancienne)
      sessions.sort((a, b) => (b.startedAt ?? DateTime(0))
          .compareTo(a.startedAt ?? DateTime(0)));
      final inProgress =
          sessions.where((s) => s.status == SessionStatus.inProgress).toList();

      if (!mounted) return;
      if (inProgress.isNotEmpty) {
        setState(() {
          _session = inProgress.first;
          _phase = _CallPhase.preCall;
        });
      } else if (sessions.isNotEmpty &&
          sessions.first.status == SessionStatus.completed) {
        setState(() {
          _session = sessions.first;
          _phase = _CallPhase.ended;
        });
      } else {
        setState(() {
          _session = null;
          _phase = _CallPhase.preCall;
        });
      }
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
      _info = null;
    });
    try {
      final session = await _sessionService.startSession(widget.appointmentId);

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

  // appele par Jitsi quand l'utilisateur raccroche (bouton rouge natif) OU
  // en cas de coupure reseau. Volontairement NE FERME PLUS la session cote
  // backend : la seance reste active jusqu'a la fin du creneau du rendez-vous
  // (cloturee automatiquement cote serveur), justement pour qu'une sortie
  // accidentelle d'un des deux participants ne compromette pas la seance de
  // l'autre. On revient simplement a l'ecran pre-appel, d'ou il est possible
  // de rejoindre a nouveau le meme salon a tout moment.
  Future<void> _onConferenceTerminated() async {
    if (!mounted || _phase == _CallPhase.ended) return;
    setState(() {
      _phase = _CallPhase.preCall;
      _info = 'Vous avez quitté l\'appel. Vous pouvez le rejoindre à '
          'nouveau tant que le rendez-vous est en cours.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: switch (_phase) {
          _CallPhase.loading || _CallPhase.joining => const Center(
              child: CircularProgressIndicator(),
            ),
          _CallPhase.ended => _buildEndedView(),
          _CallPhase.preCall => _buildPreCallView(),
        },
      ),
    );
  }

  Widget _reassurance(IconData icon, Color tint, Color ink, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreCallView() {
    final sessionAlreadyOpen = _session?.status == SessionStatus.inProgress;
    final name = widget.peerName.isNotEmpty ? widget.peerName : 'Patient';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          const Spacer(),
          AppAvatar(name: name, size: 110),
          const SizedBox(height: 18),
          Text(
            widget.isVideo ? 'Consultation en visio' : 'Consultation par téléphone',
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          if (sessionAlreadyOpen)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'La séance a déjà commencé',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ),
          const SizedBox(height: 30),
          _reassurance(
            widget.isVideo ? Icons.videocam_outlined : Icons.call_outlined,
            AppColors.tealLight,
            AppColors.teal,
            widget.isVideo
                ? 'Caméra et micro seront demandés à l\'ouverture.'
                : 'Le micro sera demandé à l\'ouverture.',
          ),
          _reassurance(
            Icons.lock_outline,
            AppColors.sand,
            AppColors.text,
            'Salle privée, réservée à ce rendez-vous.',
          ),
          if (_info != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _info!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, color: AppColors.danger),
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: _startCall,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              sessionAlreadyOpen
                  ? 'Rejoindre la séance'
                  : widget.isVideo
                      ? 'Rejoindre la visio'
                      : 'Démarrer l\'appel',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedView() {
    final duration = _session?.durationSeconds != null
        ? Duration(seconds: _session!.durationSeconds!)
        : Duration.zero;
    final name = widget.peerName.isNotEmpty ? widget.peerName : 'Patient';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          const Spacer(),
          AppAvatar(name: name, size: 90),
          const SizedBox(height: 18),
          const Text(
            'Appel terminé',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            duration.inSeconds > 0
                ? 'Avec $name · ${_formatDuration(duration)}'
                : 'Avec $name',
            style: const TextStyle(
                fontSize: 16, color: AppColors.textSecondary),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
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
