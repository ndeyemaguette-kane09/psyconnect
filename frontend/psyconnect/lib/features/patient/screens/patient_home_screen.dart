import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../journal/screens/journal_screen.dart';
import '../../payment/models/wallet_models.dart';
import '../../payment/screens/wallet_screen.dart';
import '../../payment/services/wallet_service.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/psychologist_service.dart';
import '../widgets/psychologist_card.dart';
import 'psychologist_profile_screen.dart';

/// Contenu de l'onglet "Accueil" du parcours patient (cf. maquette v2,
/// section .patient-home) — affiché par [PatientShell], pas de Scaffold/
/// AppBar propre ici.
///
/// Adapté par rapport à la maquette : pas de sélecteur d'humeur dédié, mais
/// un accès rapide au journal privé (`/journal`, user-service — cf.
/// [JournalScreen]) a été ajouté juste sous la barre de recherche. La
/// section "Recommandé pour vous" est branchée sur la vraie recommandation
/// IA (`GET /recommendations/{patientId}`, ml-service) plutôt que sur un tri
/// par note côté client. On affiche en plus un prochain RDV (si disponible).
class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({
    super.key,
    required this.onOpenSearch,
    required this.onOpenProfile,
  });

  /// Appelé quand l'utilisateur tape sur la barre de recherche ou "Voir
  /// tout" : bascule vers l'onglet "Chercher" du [PatientShell] parent
  /// plutôt que de pousser un nouvel écran.
  final VoidCallback onOpenSearch;

  /// Appelé depuis le bandeau "Complétez votre profil" : bascule vers
  /// l'onglet "Profil" du [PatientShell] parent.
  final VoidCallback onOpenProfile;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _psychologistService = PsychologistService();
  final _appointmentService = AppointmentService();
  final _profileService = ProfileService();
  final _walletService = WalletService();

  bool _loading = true;
  List<PsychologistProfile> _recommended = [];
  Appointment? _nextAppointment;
  PsychologistProfile? _nextAppointmentPsychologist;
  PatientProfile? _patientProfile;
  // Solde "Mon solde PsyConnect" — affiché en haut de l'accueil pour qu'il
  // soit visible sans aller jusque dans l'onglet Profil (qui reste en place).
  Wallet? _wallet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Lu avant tout `await` : éviter d'utiliser `context` après un gap async.
    final patientId = context.read<AuthProvider>().session?.profileId;

    List<PsychologistProfile> psychologists = [];
    try {
      psychologists = await _psychologistService.getAllPsychologists();
    } catch (_) {
      // Liste indisponible (réseau/serveur) : on affiche l'écran sans la
      // section recommandations plutôt que de planter l'accueil.
    }

    // Recommandation IA réelle (ml-service) plutôt qu'un tri par note côté
    // client. Repli sur ce tri uniquement si le service ML est indisponible
    // (502/timeout) ou si on n'a pas de patientId — jamais d'écran vide.
    List<PsychologistProfile> recommended = [];
    if (patientId != null) {
      try {
        recommended = await _psychologistService.getRecommendations(
          patientId,
          topN: 5,
        );
      } catch (_) {
        // ml-service down ou patient introuvable côté user-service : repli.
      }
    }
    if (recommended.isEmpty) {
      recommended = ([...psychologists]
            ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0)))
          .take(5)
          .toList();
    }

    // Best-effort : si ça échoue, on ne montre simplement pas le bandeau
    // "Complétez votre profil" plutôt que de bloquer l'accueil.
    PatientProfile? patientProfile;
    if (patientId != null) {
      try {
        patientProfile = await _profileService.getPatientProfileById(patientId);
      } catch (_) {
        // Pas de bandeau si le profil n'a pas pu être chargé.
      }
    }

    // Best-effort, comme le reste de cet écran : pas de solde affiché si
    // l'appel échoue plutôt que de bloquer l'accueil.
    Wallet? wallet;
    if (patientId != null) {
      try {
        wallet = await _walletService.getWallet(patientId);
      } catch (_) {
        // Pas de carte solde si le chargement échoue.
      }
    }

    Appointment? next;
    PsychologistProfile? nextPsy;
    if (patientId != null) {
      try {
        final appointments =
            await _appointmentService.getAppointmentsByPatientId(patientId);
        final now = DateTime.now();
        final upcoming = appointments.where((a) =>
            a.startTime.isAfter(now) &&
            (a.status == AppointmentStatus.pending ||
                a.status == AppointmentStatus.confirmed)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        if (upcoming.isNotEmpty) {
          next = upcoming.first;
          nextPsy = psychologists
              .where((p) => p.id == next!.psychologistId)
              .cast<PsychologistProfile?>()
              .firstWhere((_) => true, orElse: () => null);
        }
      } catch (_) {
        // Pas de RDV à afficher si l'appel échoue.
      }
    }

    if (!mounted) return;
    setState(() {
      _recommended = recommended;
      _nextAppointment = next;
      _nextAppointmentPsychologist = nextPsy;
      _patientProfile = patientProfile;
      _wallet = wallet;
      _loading = false;
    });
  }

  /// Ouvre l'écran "Mon solde PsyConnect" et rafraîchit le solde affiché au
  /// retour (une recharge/un retrait peut l'avoir changé).
  Future<void> _openWallet(int patientId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WalletScreen(patientId: patientId)),
    );
    if (mounted) _load();
  }

  /// Champs PatientProfile/UserProfile utiles côté psychologue ou pour
  /// l'expérience patient, mais pas demandés à l'inscription : on les
  /// signale ici plutôt que de laisser le patient les découvrir vides un
  /// par un dans Profil/Paramètres.
  List<String> get _missingProfileFields {
    final profile = _patientProfile;
    if (profile == null) return [];
    final missing = <String>[];
    if (profile.preferredLanguage == null ||
        profile.preferredLanguage!.trim().isEmpty) {
      missing.add('langue préférée');
    }
    if (profile.emergencyContactName == null ||
        profile.emergencyContactName!.trim().isEmpty) {
      missing.add("contact d'urgence");
    }
    return missing;
  }

  // Le bandeau "Complétez votre profil" signale la langue préférée et/ou
  // le contact d'urgence ; les deux se règlent au même endroit ("Modifier"
  // de l'onglet Profil, cf. [EditProfileScreen]). Un simple renvoi vers
  // l'onglet Profil suffit donc, quel que soit le champ manquant.
  void _onIncompleteProfileTap() => widget.onOpenProfile();

  void _openProfile(int psychologistId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PsychologistProfileScreen(psychologistId: psychologistId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text('Bonjour',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 2),
            // Prénom réel si disponible (chargé via _patientProfile), sinon
            // repli sur le pseudo.
            Text(
              (_patientProfile?.firstName.trim().isNotEmpty ?? false)
                  ? _patientProfile!.firstName.trim()
                  : (session?.pseudo ?? ''),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: widget.onOpenSearch,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.tealMid),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppColors.muted),
                    SizedBox(width: 10),
                    Text('Rechercher un psychologue…',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 14)),
                  ],
                ),
              ),
            ),
            if (!_loading && session?.profileId != null) ...[
              const SizedBox(height: 16),
              _WalletCard(
                wallet: _wallet,
                onTap: () => _openWallet(session!.profileId!),
              ),
            ],
            if (!_loading && _missingProfileFields.isNotEmpty) ...[
              const SizedBox(height: 16),
              _IncompleteProfileBanner(
                missingFields: _missingProfileFields,
                onTap: _onIncompleteProfileTap,
              ),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JournalScreen()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.book_outlined, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Comment vous sentez-vous aujourd\'hui ? '
                          'Écrivez dans votre journal.',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_nextAppointment != null) ...[
                Text('Prochain rendez-vous',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _NextAppointmentCard(
                  appointment: _nextAppointment!,
                  psychologist: _nextAppointmentPsychologist,
                ),
                const SizedBox(height: 24),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recommandé pour vous',
                      style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: widget.onOpenSearch,
                    child: const Text('Voir tout'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_recommended.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aucun psychologue disponible pour le moment.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                ...List.generate(_recommended.length, (i) {
                  final p = _recommended[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PsychologistMiniCard(
                      psychologist: p,
                      onTap: () => _openProfile(p.id),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bandeau affiché sur l'accueil quand le PatientProfile a des champs
/// utiles non renseignés (langue préférée, contact d'urgence…) — sinon
/// l'utilisateur ne les découvre qu'en allant les chercher un par un dans
/// Profil/Paramètres. Pas dans la maquette v2 : design libre.
class _IncompleteProfileBanner extends StatelessWidget {
  const _IncompleteProfileBanner({
    required this.missingFields,
    required this.onTap,
  });

  final List<String> missingFields;
  final VoidCallback onTap;

  /// Tous les champs signalés se règlent désormais au même endroit
  /// ("Modifier" de l'onglet Profil) — cf. doc de
  /// [_PatientHomeScreenState._onIncompleteProfileTap].
  String get _hint =>
      'Encore à renseigner : ${missingFields.join(', ')} (bouton "Modifier").';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.goldLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complétez votre profil',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hint,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

// Carte "Mon solde PsyConnect" affichée en haut de l'accueil. Best-effort :
// si le solde n'a pas pu être chargé, la carte invite simplement à
// l'ouvrir plutôt que de disparaître.
class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.onTap});

  final Wallet? wallet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mon solde PsyConnect',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    wallet != null
                        ? '${wallet!.balance.toStringAsFixed(0)} F CFA'
                        : '— F CFA',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({required this.appointment, this.psychologist});

  final Appointment appointment;
  final PsychologistProfile? psychologist;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final date = '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')} à '
        '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.event_available, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  psychologist != null
                      ? psychologist!.fullName
                      : 'Psychologue',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date · ${appointment.consultationType.label} · '
                  '${appointment.status.label}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
