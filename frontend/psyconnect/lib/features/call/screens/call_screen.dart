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
//         → retour a preCall (PAS de endSession ici, voir _onConferenceTerminated)
// les deux participants (patient ET psy) ouvrent le meme room Jitsi via le
// meetingToken retourne par le backend (psyconnect-{rdvId}-{uuid8}). Le
// backend garantit desormais qu'un seul et meme salon existe par rendez-vous
// tant qu'une session y est IN_PROGRESS (voir SessionServiceImpl.startSession,
// devenu "get-or-create" et verrouille pour eviter la course entre les deux
// participants qui rejoignent en meme temps).
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

  // determine l'etat de la seance pour ce RDV au chargement de l'ecran :
  // - une session IN_PROGRESS existe -> on propose de la rejoindre (l'autre
  //   participant l'a peut-etre deja demarree, ou on l'avait nous-meme
  //   quittee sans qu'elle se termine)
  // - la session la plus recente est COMPLETED -> la seance a deja eu lieu,
  //   on affiche le recap directement (plus de bouton pour en demarrer une
  //   nouvelle : un rendez-vous ne donne lieu qu'a un seul appel)
  // - aucune session -> premier demarrage possible
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
      // Le backend est get-or-create : meme si _session est perime (l'autre
      // participant a demarre entre-temps, ou on rejoint apres une coupure),
      // startSession renvoie toujours LA session IN_PROGRESS existante pour
      // ce rendez-vous plutot que d'en creer une seconde. On peut donc
      // toujours rappeler startSession sans risque de dupliquer le salon.
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
          if (_info != null) ...[
            Text(
              _info!,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
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
