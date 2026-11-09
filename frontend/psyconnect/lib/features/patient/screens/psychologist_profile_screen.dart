import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../models/psychologist_models.dart';
import '../services/psychologist_service.dart';
import '../widgets/psychologist_card.dart';
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
        backgroundColor: AppColors.background,
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
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (ready) _buildBookingBar(_psychologist!),
        ],
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
    final subtitle = [
      p.specialty,
      if (p.city != null && p.city!.trim().isNotEmpty) p.city!,
    ].join(' · ');
    final rating = p.rating;
    final reviewsLabel = rating != null && rating > 0
        ? '${rating.toStringAsFixed(1).replaceAll('.', ',')} · '
            '${p.totalReviews ?? 0} avis'
        : 'Pas encore d\'avis';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppAvatar(name: p.fullName, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.fullName, style: theme.textTheme.displayMedium),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.muted,
                          ),
                        ),
                        if (p.profileVerified || p.availableForEmergency) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              if (p.profileVerified)
                                _Mark(
                                  icon: Icons.check_rounded,
                                  label: p.hasLicenseDocument
                                      ? 'Diplôme vérifié'
                                      : 'Profil vérifié',
                                  color: AppColors.teal,
                                ),
                              if (p.availableForEmergency)
                                const _Mark(
                                  icon: Icons.phone_outlined,
                                  label: 'Urgences',
                                  color: AppColors.danger,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Fact(label: 'Avis des patients', value: reviewsLabel),
              if (p.yearsOfExperience != null)
                _Fact(
                  label: 'Expérience',
                  value: '${p.yearsOfExperience} ans',
                ),
              if (p.languages != null && p.languages!.trim().isNotEmpty)
                _Fact(label: 'Langues', value: p.languages!),
              if (p.offersFreeSessions) ...[
                const SizedBox(height: 16),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        color: AppColors.teal, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Séances gratuites possibles, précisez-le dans votre demande.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (p.bio != null && p.bio!.isNotEmpty) ...[
                const SizedBox(height: 26),
                const SectionHeader(title: 'Sa présentation'),
                const SizedBox(height: 8),
                Text(
                  p.bio!,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.55,
                    color: AppColors.text,
                  ),
                ),
              ],
              if (p.address != null && p.address!.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: AppColors.goldDark, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cabinet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            p.address!,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (!_reviewsLoading && _reviews.isNotEmpty) ...[
                const SizedBox(height: 28),
                const SectionHeader(
                  title: 'Ce qu\'en disent ses patients',
                  subtitle: 'Avis anonymes, laissés après une séance terminée.',
                ),
                const SizedBox(height: 12),
                ..._reviews.map((r) => Padding(
                      padding: EdgeInsets.zero,
                      child: _ReviewTile(review: r),
                    )),
              ],
              if (p.createdAt != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Sur PsyConnect depuis ${_monthYear(p.createdAt!)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
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
    final price = p.consultationPrice;
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'La séance',
                style: TextStyle(fontSize: 13.5, color: AppColors.muted),
              ),
              Text(
                price != null ? '${formatPrice(price)} F' : 'Non précisé',
                style: TextStyle(
                  fontSize: price != null ? 19 : 14,
                  fontWeight: FontWeight.w800,
                  color: price != null ? AppColors.text : AppColors.muted,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: p.available ? _openBooking : null,
              child: Text(
                p.available ? 'Choisir un créneau' : 'Indisponible',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: AppColors.muted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// avis anonyme : note et commentaire seulement
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PsychologistReview review;

  @override
  Widget build(BuildContext context) {
    final rating = review.rating ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
            Text(
              review.comment!,
              style: const TextStyle(fontSize: 15.5, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
