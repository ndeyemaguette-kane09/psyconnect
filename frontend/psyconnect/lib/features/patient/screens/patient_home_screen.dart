import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../companion/screens/xalaat_screen.dart';
import '../../journal/screens/journal_screen.dart';
import '../../payment/models/wallet_models.dart';
import '../../payment/screens/wallet_screen.dart';
import '../../payment/services/wallet_service.dart';
import '../../psychologist/models/recommendation_models.dart';
import '../../psychologist/services/recommendation_service.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/notification_service.dart';
import '../services/psychologist_service.dart';
import '../widgets/psychologist_card.dart';
import 'announcements_screen.dart';
import 'emergency_screen.dart';
import 'notifications_screen.dart';
import 'psychologist_profile_screen.dart';

// Onglet Accueil du patient, affiché par PatientShell.
// Les recommandations proviennent du ml-service (pas un simple tri par note) ;
// le prochain rendez-vous est mis en avant quand il existe.
class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({
    super.key,
    required this.onOpenSearch,
    required this.onOpenProfile,
  });

  // tap sur la recherche ou "Voir tout", va vers l'onglet Chercher
  final VoidCallback onOpenSearch;

  // tap sur le bandeau profil incomplet, va vers l'onglet Profil
  final VoidCallback onOpenProfile;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _psychologistService = PsychologistService();
  final _appointmentService = AppointmentService();
  final _profileService = ProfileService();
  final _walletService = WalletService();
  final _notificationService = NotificationService();
  final _recommendationService = RecommendationService();
  final _api = ApiClient();
  final _storage = const FlutterSecureStorage();

  bool _loading = true;
  List<PsychologistProfile> _recommended = [];
  Appointment? _nextAppointment;
  PsychologistProfile? _nextAppointmentPsychologist;
  PatientProfile? _patientProfile;
  // Solde affiché en haut de l'accueil pour un accès rapide.
  Wallet? _wallet;
  // Badge de la cloche, chargé en arrière-plan (échec silencieux).
  int _unreadNotifCount = 0;
  // Badge mégaphone : annonces non vues depuis la dernière ouverture.
  int _newBroadcastCount = 0;
  // Recommandations post-séance non encore cochées par le patient.
  List<SessionRecommendation> _pendingRecommendations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Récupéré avant le premier await pour ne pas utiliser context après.
    final patientId = context.read<AuthProvider>().session?.profileId;

    List<PsychologistProfile> psychologists = [];
    try {
      psychologists = await _psychologistService.getAllPsychologists();
    } catch (_) {}

    // Recommandations du ml-service ; repli sur un tri par note si indisponible.
    List<PsychologistProfile> recommended = [];
    if (patientId != null) {
      try {
        recommended = await _psychologistService.getRecommendations(
          patientId,
          topN: 5,
        );
      } catch (_) {}
    }
    if (recommended.isEmpty) {
      recommended = ([...psychologists]
            ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0)))
          .take(5)
          .toList();
    }

    // En cas d'échec, le bandeau "Complétez votre profil" n'est pas affiché.
    PatientProfile? patientProfile;
    if (patientId != null) {
      try {
        patientProfile = await _profileService.getPatientProfileById(patientId);
      } catch (_) {}
    }

    // En cas d'échec, la carte de solde n'est pas affichée.
    Wallet? wallet;
    if (patientId != null) {
      try {
        wallet = await _walletService.getWallet(patientId);
      } catch (_) {}
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
      } catch (_) {}
    }

    // Recommandations post-séance non cochées (échec silencieux, non critique).
    List<SessionRecommendation> pendingRecos = [];
    try {
      pendingRecos = await _recommendationService.getMyPendingRecommendations();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _recommended = recommended;
      _nextAppointment = next;
      _nextAppointmentPsychologist = nextPsy;
      _patientProfile = patientProfile;
      _wallet = wallet;
      _pendingRecommendations = pendingRecos;
      _loading = false;
    });

    // Chargés après le setState pour ne pas retarder l'affichage principal.
    _refreshUnreadNotifCount();
    _refreshBroadcastBadge();
  }

  Future<void> _refreshUnreadNotifCount() async {
    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) return;
    try {
      final notifs =
          await _notificationService.getNotificationsByUserId(patientId);
      final unread = notifs.where((n) => !n.isRead).length;
      if (mounted) setState(() => _unreadNotifCount = unread);
    } catch (_) {}
  }

  Future<void> _openNotifications(int patientId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(userId: patientId),
      ),
    );
    if (mounted) _refreshUnreadNotifCount();
  }

  // Compte les broadcasts postés après le dernier timestamp de lecture.
  // Persiste via flutter_secure_storage pour survivre aux redémarrages.
  Future<void> _refreshBroadcastBadge() async {
    try {
      final json = await _api.get(ApiConstants.broadcasts);
      final broadcasts = (json as List).cast<Map<String, dynamic>>();

      final lastSeenStr = await _storage.read(key: 'patient_broadcasts_last_seen');
      final lastSeen = lastSeenStr != null
          ? DateTime.tryParse(lastSeenStr) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0);

      final newCount = broadcasts.where((b) {
        final raw = b['sentAt'] as String?;
        if (raw == null) return false;
        final sentAt = DateTime.tryParse(raw);
        return sentAt != null && sentAt.isAfter(lastSeen);
      }).length;

      if (mounted) setState(() => _newBroadcastCount = newCount);
    } catch (_) {}
  }

  // Ouvre les annonces + enregistre le timestamp de lecture.
  Future<void> _openAnnouncements() async {
    // Marquer comme "tout vu" maintenant
    await _storage.write(
      key: 'patient_broadcasts_last_seen',
      value: DateTime.now().toIso8601String(),
    );
    if (mounted) setState(() => _newBroadcastCount = 0);

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
    );
    // Vérifier s'il en est arrivé de nouvelles pendant la consultation
    if (mounted) _refreshBroadcastBadge();
  }

  Future<void> _openWallet(int patientId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WalletScreen(patientId: patientId)),
    );
    if (mounted) _load();
  }

  // Champs facultatifs à l'inscription mais signalés ici s'ils sont absents.
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

  void _onIncompleteProfileTap() => widget.onOpenProfile();

  // patient coche une recommandation post-seance
  Future<void> _markRecommendationDone(SessionRecommendation reco) async {
    try {
      await _recommendationService.markCompleted(reco.id);
      if (!mounted) return;
      setState(() => _pendingRecommendations
          .removeWhere((r) => r.id == reco.id));
    } catch (_) {}
  }

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bonjour',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 13)),
                      const SizedBox(height: 2),
                      // Prénom réel si disponible, sinon le pseudo.
                      Text(
                        (_patientProfile?.firstName.trim().isNotEmpty ?? false)
                            ? _patientProfile!.firstName.trim()
                            : (session?.pseudo ?? ''),
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Annonces système',
                  onPressed: _openAnnouncements,
                  icon: Badge(
                    isLabelVisible: _newBroadcastCount > 0,
                    label: Text('$_newBroadcastCount'),
                    backgroundColor: AppColors.rose,
                    child: const Icon(Icons.campaign_outlined,
                        color: AppColors.teal),
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: session?.profileId == null
                      ? null
                      : () => _openNotifications(session!.profileId!),
                  icon: Badge(
                    isLabelVisible: _unreadNotifCount > 0,
                    label: Text('$_unreadNotifCount'),
                    child: const Icon(Icons.notifications_outlined,
                        color: AppColors.teal),
                  ),
                ),
              ],
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
            // bouton SOS : toujours visible, même si chargement en cours
            const SizedBox(height: 16),
            _SosButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmergencyScreen()),
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
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const XalaatScreen()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.spa_outlined, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Parler à Xalaat',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          SizedBox(height: 2),
                          Text(
                            'Prépare-toi avant ton rendez-vous, en toute '
                            'confidentialité.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
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
                // Recommandations post-séance non encore cochées.
              if (_pendingRecommendations.isNotEmpty) ...[
                Text('Avant ma prochaine séance',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._pendingRecommendations.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecommendationTile(
                    recommendation: r,
                    onDone: () => _markRecommendationDone(r),
                  ),
                )),
                const SizedBox(height: 16),
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

// Bouton d'urgence, toujours visible quelle que soit l'état du chargement.
class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.emergency_outlined, color: Colors.white),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'J\'ai besoin d\'aide maintenant',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Appelez un psychologue disponible immédiatement',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

// Tuile affichant une recommandation post-séance avec un bouton pour la cocher.
class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.recommendation,
    required this.onDone,
  });

  final SessionRecommendation recommendation;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tealMid),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onDone,
            child: const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.radio_button_unchecked,
                  color: AppColors.teal, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recommendation.content,
                    style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 4),
                const Text(
                  'Conseil de votre psychologue',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Bandeau invitant le patient à compléter son profil si des champs sont manquants.
class _IncompleteProfileBanner extends StatelessWidget {
  const _IncompleteProfileBanner({
    required this.missingFields,
    required this.onTap,
  });

  final List<String> missingFields;
  final VoidCallback onTap;

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

// Carte affichant le solde du patient. En cas d'échec du chargement, elle
// reste visible et invite l'utilisateur à ouvrir l'écran du portefeuille.
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
