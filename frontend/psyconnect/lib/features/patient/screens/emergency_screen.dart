import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../call/screens/emergency_call_screen.dart';
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
          builder: (_) => EmergencyCallScreen(
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
