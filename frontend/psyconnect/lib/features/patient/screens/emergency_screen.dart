import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
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
          backgroundColor: Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.emergency_outlined, size: 20),
            SizedBox(width: 8),
            Text('Aide immédiate',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // en-tête rassurant
            Container(
              color: const Color(0xFFE53935),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vous n\'êtes pas seul(e).',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ces psychologues sont disponibles maintenant pour vous écouter, '
                    'sans rendez-vous et sans attente.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  // rappel numéro national (si disponible au Sénégal)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.phone_in_talk, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'En cas de danger immédiat, composez le 15 (SAMU) '
                            'ou le 1515 (Croix-Rouge Sénégal).',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // liste des psys disponibles
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFFE53935)),
                          SizedBox(height: 12),
                          Text('Recherche de psychologues disponibles…',
                              style: TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    )
                  : _error != null
                      ? _buildError()
                      : _available.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFFE53935),
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 16),
                                itemCount: _available.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) => _PsychologistSosCard(
                                  psychologist: _available[i],
                                  isCalling: _callingPsyId == _available[i].id,
                                  onCall: () =>
                                      _callPsychologist(_available[i]),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.muted, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935)),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE), shape: BoxShape.circle),
              child: const Icon(Icons.person_search,
                  color: Color(0xFFE53935), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun psychologue disponible pour l\'instant',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF4E342E)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nos psychologues activent leur disponibilité manuellement. '
              'Revenez dans quelques minutes ou prenez rendez-vous.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualiser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                side: const BorderSide(color: Color(0xFFE53935)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// carte d'un psy disponible pour urgence
class _PsychologistSosCard extends StatelessWidget {
  const _PsychologistSosCard({
    required this.psychologist,
    required this.isCalling,
    required this.onCall,
  });

  final PsychologistProfile psychologist;
  final bool isCalling;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFFFEBEE),
            backgroundImage: psychologist.profilePicture != null
                ? NetworkImage(psychologist.profilePicture!)
                : null,
            child: psychologist.profilePicture == null
                ? Text(
                    psychologist.firstName.isNotEmpty
                        ? psychologist.firstName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w700,
                        fontSize: 20),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  psychologist.fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  psychologist.specialty,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12),
                ),
                if (psychologist.offersFreeSessions) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Consultation solidaire — gratuite',
                      style: TextStyle(
                          color: AppColors.teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: isCalling ? null : onCall,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
                style: const TextStyle(fontSize: 13)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
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
