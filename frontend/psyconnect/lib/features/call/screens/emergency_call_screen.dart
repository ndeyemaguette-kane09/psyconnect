import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/session_models.dart';
import '../services/session_service.dart';

class EmergencyCallScreen extends StatefulWidget {
  const EmergencyCallScreen({
    super.key,
    required this.session,
    required this.peerName,
    this.forPsychologist = false,
  });

  final CallSession session;
  final String peerName;
  final bool forPsychologist;

  @override
  State<EmergencyCallScreen> createState() =>
      _EmergencyCallScreenState();
}

class _EmergencyCallScreenState extends State<EmergencyCallScreen> {
  final _jitsi = JitsiMeet();
  final _sessionService = SessionService();
  bool _started = false;
  bool _joining = true;
  bool _ended = false;
  bool _closedByOther = false;
  bool _leaving = false;
  String? _endedByOtherMessage;
  int? _durationSeconds;
  Timer? _watch;

  @override
  void initState() {
    super.initState();
    if (!widget.forPsychologist) _startWatching();
  }

  @override
  void dispose() {
    _watch?.cancel();
    if (!_started && !_closedByOther && !widget.forPsychologist) {
      _cancelUnjoined();
    }
    super.dispose();
  }

  void _startWatching() {
    _watch?.cancel();
    _watch = Timer.periodic(const Duration(seconds: 5), (_) => _checkSession());
  }

  Future<void> _checkSession() async {
    if (_ended || _closedByOther || _leaving) return;
    CallSession session;
    try {
      session = await _sessionService.getSession(widget.session.id);
    } catch (_) {
      return;
    }
    if (!mounted || _ended || _closedByOther || _leaving) return;
    if (session.status == SessionStatus.inProgress) return;

    _closedByOther = true;
    _watch?.cancel();
    if (_started) {
      try {
        await _jitsi.hangUp();
      } catch (_) {}
    }
    if (!mounted) return;

    if (session.declinedByPsychologist) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Psychologue indisponible'),
          content: Text(
            '${widget.peerName} n\'est pas disponible pour le moment. '
            'Choisissez un autre psychologue dans la liste.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Choisir un autre psychologue'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final start = widget.session.startedAt;
    setState(() {
      _ended = true;
      _durationSeconds =
          start != null ? DateTime.now().difference(start).inSeconds : 0;
      _endedByOtherMessage = widget.forPsychologist
          ? 'Le patient a quitté l\'appel.'
          : 'Votre psychologue a quitté l\'appel.';
    });
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appel terminé'),
        content: Text(_endedByOtherMessage!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelUnjoined() async {
    try {
      await _sessionService.cancelEmergencySession(widget.session.id);
    } catch (_) {}
  }

  Future<void> _join() async {
    if (widget.forPsychologist) {
      try {
        await _sessionService.joinEmergencySession(widget.session.id);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cet appel d\'urgence n\'est plus en cours.'),
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      if (!mounted) return;
    }
    setState(() {
      _started = true;
      _joining = true;
    });
    if (widget.forPsychologist) _startWatching();
    _launchJitsi();
  }

  Future<void> _launchJitsi() async {
    final userName =
        context.read<AuthProvider>().session?.pseudo ??
            (widget.forPsychologist ? 'Psychologue' : 'Patient');

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
    if (!mounted || _ended || _closedByOther) return;
    _leaving = true;
    _watch?.cancel();
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
                  Text(
                    widget.forPsychologist
                        ? 'Merci d\'avoir répondu à cet appel.'
                        : 'Prenez soin de vous. Vous n\'êtes pas seul(e).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () {
                      final navigator = Navigator.of(context)..pop();
                      if (!widget.forPsychologist) navigator.pop();
                    },
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

    if (!_started) return _buildPreCall();

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
                !_joining
                    ? 'Appel en cours…'
                    : widget.forPsychologist
                        ? 'Connexion à l\'appel…'
                        : 'Connexion à ${widget.peerName}…',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 21, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.4,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreCall() {
    final name = widget.peerName.isNotEmpty
        ? widget.peerName
        : (widget.forPsychologist ? 'Un patient' : 'Psychologue');

    return Scaffold(
      backgroundColor: AppColors.tealDark,
      appBar: AppBar(
        backgroundColor: AppColors.tealDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              AppAvatar(name: name, size: 110, color: AppColors.tealBright),
              const SizedBox(height: 18),
              const Text(
                'Appel d\'urgence',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              _line(
                widget.forPsychologist
                    ? Icons.person_outline
                    : Icons.notifications_active_outlined,
                widget.forPsychologist
                    ? 'Le patient vous attend dans le salon.'
                    : 'Votre psychologue a été prévenu et va vous rejoindre.',
              ),
              _line(
                Icons.videocam_outlined,
                'Caméra et micro seront demandés à l\'ouverture.',
              ),
              _line(Icons.lock_outline, 'Salle privée, réservée à cet appel.'),
              if (!widget.forPsychologist)
                _line(
                  Icons.call_outlined,
                  'En cas de danger immédiat, appelez le SAMU au 1515.',
                ),
              const Spacer(),
              FilledButton(
                onPressed: _join,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.tealDark,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(widget.forPsychologist
                    ? 'Rejoindre l\'appel'
                    : 'Démarrer l\'appel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
