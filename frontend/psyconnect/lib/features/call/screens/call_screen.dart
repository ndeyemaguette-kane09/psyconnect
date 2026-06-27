import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../models/session_models.dart';
import '../services/session_service.dart';

/// Écran d'appel simulé : aucune intégration SDK réelle (Agora/WebRTC), cf.
/// commentaire de [SessionServiceImpl] côté backend ("pas d'intégration
/// réelle ... on génère un jeton de session simulé"). Reprend ce contrat tel
/// quel côté Flutter : on démarre/termine une [CallSession] via /sessions,
/// et on affiche une interface d'appel factice (avatar statique, minuteur,
/// boutons micro/caméra sans effet réel) pendant qu'elle est IN_PROGRESS.
///
/// Pas dans la maquette v2 — design libre (cf. mémoire projet).
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

  bool _loading = true;
  String? _error;
  CallSession? _session;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  bool _micMuted = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // On vérifie d'abord s'il existe déjà une session IN_PROGRESS pour ce
      // RDV (l'utilisateur a peut-être quitté l'écran sans raccrocher).
      final sessions =
          await _sessionService.getSessionsByAppointment(widget.appointmentId);
      final inProgress = sessions
          .where((s) => s.status == SessionStatus.inProgress)
          .toList();
      if (!mounted) return;
      setState(() {
        _session = inProgress.isNotEmpty ? inProgress.first : null;
        _loading = false;
      });
      if (_session != null) _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Impossible de charger la session.';
      });
    }
  }

  void _startTicker() {
    final startedAt = _session?.startedAt ?? DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(startedAt));
    });
  }

  Future<void> _startCall() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _sessionService.startSession(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
      });
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : "Impossible de démarrer l'appel.";
      });
    }
  }

  Future<void> _endCall() async {
    final session = _session;
    if (session == null) return;
    _ticker?.cancel();
    setState(() => _loading = true);
    try {
      final ended = await _sessionService.endSession(session.id);
      if (!mounted) return;
      setState(() {
        _session = ended;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : "Impossible de terminer l'appel.";
      });
    }
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final inCall = _session?.status == SessionStatus.inProgress;
    final ended = _session?.status == SessionStatus.completed;

    return Scaffold(
      backgroundColor: AppColors.tealDark,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : ended
                ? _buildEndedView()
                : inCall
                    ? _buildInCallView()
                    : _buildPreCallView(),
      ),
    );
  }

  Widget _buildPreCallView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.white24,
            child: Text(
              widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.peerName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            widget.isVideo ? 'Appel vidéo (simulé)' : 'Appel audio (simulé)',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 32),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.rose)),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            onPressed: _startCall,
            icon: const Icon(Icons.call),
            label: const Text("Démarrer l'appel"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildInCallView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(_formatElapsed(_elapsed),
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, letterSpacing: 1)),
        const Spacer(),
        CircleAvatar(
          radius: 64,
          backgroundColor: Colors.white24,
          child: Text(
            widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 18),
        Text(widget.peerName,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Session simulée en cours',
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.rose)),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CallIconButton(
                icon: _micMuted ? Icons.mic_off : Icons.mic,
                background: Colors.white24,
                onTap: () => setState(() => _micMuted = !_micMuted),
              ),
              const SizedBox(width: 20),
              _CallIconButton(
                icon: Icons.call_end,
                background: AppColors.rose,
                onTap: _endCall,
                large: true,
              ),
              const SizedBox(width: 20),
              if (widget.isVideo)
                _CallIconButton(
                  icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                  background: Colors.white24,
                  onTap: () => setState(() => _cameraOff = !_cameraOff),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndedView() {
    final duration = _session?.durationSeconds != null
        ? Duration(seconds: _session!.durationSeconds!)
        : _elapsed;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.call_end, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          const Text('Appel terminé',
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Durée : ${_formatElapsed(duration)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}

class _CallIconButton extends StatelessWidget {
  const _CallIconButton({
    required this.icon,
    required this.background,
    required this.onTap,
    this.large = false,
  });

  final IconData icon;
  final Color background;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: large ? 30 : 24),
      ),
    );
  }
}
