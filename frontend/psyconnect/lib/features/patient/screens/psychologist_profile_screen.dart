import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/psychologist_models.dart';
import '../services/psychologist_service.dart';
import 'booking_screen.dart';
import 'report_psychologist_screen.dart';

class PsychologistProfileScreen extends StatefulWidget {
  const PsychologistProfileScreen({super.key, required this.psychologistId});

  final int psychologistId;

  @override
  State<PsychologistProfileScreen> createState() =>
      _PsychologistProfileScreenState();
}

class _PsychologistProfileScreenState
    extends State<PsychologistProfileScreen> {
  final _psychologistService = PsychologistService();

  bool _loading = true;
  String? _error;
  PsychologistProfile? _psychologist;

  List<PsyAvailabilitySlot> _availabilities = [];

  // Avis publics et anonymes : chargés indépendamment de _load() pour ne pas
  // bloquer l'affichage du profil si ce second appel échoue.
  List<PsychologistReview> _reviews = [];
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews =
          await _psychologistService.getReviews(widget.psychologistId);
      if (!mounted) return;
      setState(() => _reviews = reviews);
    } catch (_) {
      // Échec silencieux : la section avis reste vide sans bloquer l'écran.
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Profil et disponibilités en parallèle.
      final results = await Future.wait([
        _psychologistService.getPsychologistById(widget.psychologistId),
        _psychologistService
            .getAvailabilities(widget.psychologistId)
            .catchError((_) => <PsyAvailabilitySlot>[]), // best-effort
      ]);

      if (!mounted) return;
      setState(() {
        _psychologist = results[0] as PsychologistProfile;
        _availabilities = results[1] as List<PsyAvailabilitySlot>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBooking() async {
    final p = _psychologist;
    if (p == null) return;

    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          psychologist: p,
          availabilities: _availabilities,
        ),
      ),
    );
    if (booked == true && mounted) Navigator.of(context).pop();
  }

  void _openReport() {
    final p = _psychologist;
    if (p == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportPsychologistScreen(
          psychologistId: widget.psychologistId,
          psychologistName: p.fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _error == null && _psychologist != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Signaler ce psychologue',
            onPressed: _psychologist == null ? null : _openReport,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            if (ready) _buildBookingBar(_psychologist!),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _psychologist == null) {
      return AppErrorState(
        title: 'Profil indisponible',
        message: _error ?? 'Psychologue introuvable.',
        onRetry: _load,
      );
    }

    final p = _psychologist!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        // ── Identité ────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              AppAvatar(name: p.fullName, size: 88),
              const SizedBox(height: 14),
              Text(
                p.fullName,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  AppPill(
                    label: p.specialty,
                    icon: Icons.psychology_outlined,
                  ),
                  if (p.availableForEmergency)
                    const AppPill(
                      label: 'Joignable en urgence',
                      icon: Icons.emergency_outlined,
                      color: AppColors.success,
                      background: AppColors.successBg,
                    ),
                ],
              ),
              if (p.city != null || p.languages != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (p.city != null) p.city!,
                    if (p.languages != null) p.languages!,
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (p.profileVerified) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 15, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Text(
                      p.hasLicenseDocument
                          ? 'Profil vérifié · diplôme contrôlé'
                          : 'Profil vérifié par PsyConnect',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 22),

        // ── Chiffres clés ───────────────────────────────────────────────
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stat(
                  value: p.rating != null && p.rating! > 0
                      ? p.rating!.toStringAsFixed(1)
                      : '—',
                  label: 'Note',
                ),
                const VerticalDivider(width: 1),
                _Stat(value: '${p.totalReviews ?? 0}', label: 'Avis'),
                const VerticalDivider(width: 1),
                _Stat(
                  value: p.yearsOfExperience != null
                      ? '${p.yearsOfExperience} ans'
                      : '—',
                  label: 'Expérience',
                ),
                const VerticalDivider(width: 1),
                _Stat(
                  value: p.consultationPrice != null
                      ? '${p.consultationPrice} F'
                      : '—',
                  label: 'Séance',
                ),
              ],
            ),
          ),
        ),

        if (p.offersFreeSessions) ...[
          const SizedBox(height: 16),
          const AppNoticeCard(
            icon: Icons.favorite_border_rounded,
            title: 'Consultations solidaires',
            message: 'Ce psychologue propose des séances gratuites aux '
                'patients qui ne peuvent pas payer. Indiquez-le au moment de '
                'votre demande de rendez-vous.',
            accent: AppColors.success,
            background: AppColors.successBg,
          ),
        ],

        // ── Présentation ────────────────────────────────────────────────
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          const SizedBox(height: 26),
          const SectionHeader(title: 'À propos'),
          const SizedBox(height: 10),
          Text(p.bio!, style: theme.textTheme.bodyMedium),
        ],

        // ── Cabinet ─────────────────────────────────────────────────────
        if (p.address != null && p.address!.isNotEmpty) ...[
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(14),
            borderColor: AppColors.border,
            shadow: const [],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.teal, size: 20),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adresse du cabinet',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(p.address!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Avis ────────────────────────────────────────────────────────
        if (!_reviewsLoading && _reviews.isNotEmpty) ...[
          const SizedBox(height: 26),
          SectionHeader(
            title: 'Avis (${_reviews.length})',
            subtitle: 'Anonymes, laissés par des patients ayant terminé une '
                'séance avec ce psychologue.',
          ),
          const SizedBox(height: 12),
          ..._reviews.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReviewTile(review: r),
              )),
        ],

        // ── Ancienneté ──────────────────────────────────────────────────
        if (p.createdAt != null) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Sur PsyConnect depuis ${_monthYear(p.createdAt!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.faint),
            ),
          ),
        ],
      ],
    );
  }

  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  static String _monthYear(DateTime d) =>
      '${_months[d.month - 1]} ${d.year}';

  Widget _buildBookingBar(PsychologistProfile p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'La séance',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 1),
              Text(
                p.consultationPrice != null
                    ? '${p.consultationPrice} F'
                    : 'Non précisé',
                style: TextStyle(
                  fontSize: p.consultationPrice != null ? 17 : 13,
                  fontWeight: FontWeight.w700,
                  color: p.consultationPrice != null
                      ? AppColors.text
                      : AppColors.muted,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: ElevatedButton(
              onPressed: p.available ? _openBooking : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
              child: Text(
                p.available ? 'Réserver une séance' : 'Indisponible',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Tuile affichant un avis anonyme : note et commentaire uniquement, sans
/// aucune donnée d'identité du patient (cf. ReviewResponse côté backend).
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PsychologistReview review;

  @override
  Widget build(BuildContext context) {
    final rating = review.rating ?? 0;
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: AppColors.border,
      shadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: AppColors.gold,
                size: 17,
              ),
            ),
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
