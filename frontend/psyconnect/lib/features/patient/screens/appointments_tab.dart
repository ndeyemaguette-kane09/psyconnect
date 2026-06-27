import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../call/screens/call_screen.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/screens/payment_screen.dart';
import '../../payment/services/payment_service.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../services/appointment_service.dart';
import '../services/psychologist_service.dart';

/// Contenu de l'onglet "RDV" du parcours patient (cf. maquette v2) — liste
/// des rendez-vous du patient, triés du plus proche au plus ancien.
///
/// `GET /appointments/patient/{id}` ne renvoie pas le nom du psychologue
/// (seulement `psychologistId`) : on récupère `GET /psychologists` à côté
/// pour résoudre les noms, comme déjà fait dans `PatientHomeScreen`.
class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  final _appointmentService = AppointmentService();
  final _psychologistService = PsychologistService();
  final _paymentService = PaymentService();

  bool _loading = true;
  String? _error;
  List<Appointment> _appointments = [];
  Map<int, PsychologistProfile> _psychologistsById = {};

  // Filtre par statut façon "balises" (même pattern que les filtres
  // anxiété/dépression de la recherche de psychologues). `null` = "Tous" :
  // affichage groupé par statut.
  AppointmentStatus? _statusFilter;

  // RDV CONFIRMED ayant déjà un paiement COMPLETED : le bouton "Payer" ne
  // doit plus s'afficher pour eux.
  Set<int> _paidAppointmentIds = {};

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

    // Lu avant tout `await` : éviter d'utiliser `context` après un gap async.
    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) {
      setState(() {
        _error = 'Profil patient introuvable.';
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        _appointmentService.getAppointmentsByPatientId(patientId),
        _psychologistService.getAllPsychologists(),
      ]);
      final appointments = results[0] as List<Appointment>;
      final psychologists = results[1] as List<PsychologistProfile>;
      // Tri par date d'ajout (createdAt), pas par date du créneau : un RDV
      // tout juste demandé doit apparaître en haut.
      appointments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Seuls les RDV CONFIRMED peuvent afficher "Payer" : on ne vérifie
      // l'existence d'un paiement déjà complété que pour ceux-là, pour
      // éviter un appel réseau par RDV sans intérêt (PENDING/CANCELLED/...).
      final confirmedIds = appointments
          .where((a) => a.status == AppointmentStatus.confirmed)
          .map((a) => a.id)
          .toList();
      final paidIds = await _loadPaidAppointmentIds(confirmedIds);

      if (!mounted) return;
      setState(() {
        _appointments = appointments;
        _psychologistsById = {for (final p in psychologists) p.id: p};
        _paidAppointmentIds = paidIds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger vos rendez-vous.';
        _loading = false;
      });
    }
  }

  /// Renvoie l'id des RDV (parmi [confirmedAppointmentIds]) qui ont déjà un
  /// paiement COMPLETED — donc qui ne doivent plus afficher de bouton
  /// "Payer". Best-effort : un échec ponctuel sur un RDV donné ne bloque pas
  /// l'affichage des autres (le pire cas reste un bouton "Payer" visible à
  /// tort, immédiatement rejeté par le backend, cf. PaymentServiceImpl).
  Future<Set<int>> _loadPaidAppointmentIds(List<int> confirmedAppointmentIds) async {
    if (confirmedAppointmentIds.isEmpty) return {};
    final paid = <int>{};
    await Future.wait(confirmedAppointmentIds.map((id) async {
      try {
        final payments = await _paymentService.getPaymentsByAppointmentId(id);
        if (payments.any((p) => p.status == PaymentStatus.completed)) {
          paid.add(id);
        }
      } catch (_) {
        // Best-effort, cf. doc ci-dessus.
      }
    }));
    return paid;
  }

  /// Ouvre l'écran de paiement (simulé) pour un RDV encore en attente.
  /// Rafraîchit la liste au retour : un paiement réussi confirme le RDV
  /// côté backend (cf. PaymentScreen/PaymentServiceImpl).
  Future<void> _pay(Appointment appointment, PsychologistProfile? psychologist) async {
    final price = psychologist?.consultationPrice;
    if (price == null || price <= 0) return;
    final patientId = context.read<AuthProvider>().session?.profileId;
    if (patientId == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          appointmentId: appointment.id,
          amount: price,
          otherDisplayName: psychologist?.fullName ?? 'votre psychologue',
          patientId: patientId,
        ),
      ),
    );
    if (mounted) _load();
  }

  /// Ouvre l'écran d'appel simulé (CONFIRMED + type vidéo/audio uniquement —
  /// cf. SessionServiceImpl côté backend qui refuse de démarrer une session
  /// sur un RDV non confirmé).
  void _joinCall(Appointment appointment, PsychologistProfile? psychologist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          appointmentId: appointment.id,
          peerName: psychologist?.fullName ?? 'Psychologue',
          isVideo: appointment.consultationType == ConsultationType.video,
        ),
      ),
    );
  }

  /// Ouvre la feuille de report (nouveau créneau) pour un RDV encore
  /// modifiable (PENDING ou CONFIRMED). Pas dans la maquette v2 (qui ne
  /// montre qu'un bouton "Reporter" sans détailler l'écran) — design libre.
  Future<void> _reschedule(Appointment appointment) async {
    final newRange = await showModalBottomSheet<_NewSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RescheduleSheet(appointment: appointment),
    );
    if (newRange == null || !mounted) return;

    try {
      await _appointmentService.rescheduleAppointment(
        appointment.id,
        RescheduleAppointmentRequest(
          newStartTime: newRange.start,
          newEndTime: newRange.end,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Rendez-vous reporté'),
          content: Text(
            appointment.status == AppointmentStatus.confirmed
                ? 'Le nouveau créneau a été envoyé au psychologue, qui doit '
                    'le reconfirmer.'
                : 'Le nouveau créneau a bien été enregistré.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      final message =
          e is ApiException ? e.message : 'Le report a échoué.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Annule un RDV après confirmation, en affichant au préalable la
  /// politique de remboursement applicable (cf. maquette
  /// confirmer_RDV.png : "Remboursement si annulation 48h avant").
  Future<void> _cancel(Appointment appointment) async {
    final hoursUntilStart =
        appointment.startTime.difference(DateTime.now()).inHours;
    final eligibleForRefund = hoursUntilStart >= 48;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: Text(
          eligibleForRefund
              ? "Vous annulez à plus de 48h du rendez-vous : si un paiement "
                  "a été effectué, il sera automatiquement remboursé."
              : "Vous annulez à moins de 48h du rendez-vous : aucun "
                  "remboursement ne sera appliqué, même si un paiement a "
                  "été effectué.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _appointmentService.updateAppointmentStatus(
        appointment.id,
        AppointmentStatus.cancelled,
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      final message =
          e is ApiException ? e.message : "L'annulation a échoué.";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Supprime définitivement un RDV annulé/refusé. Réservé par le backend
  // à ces deux statuts — voir `_AppointmentCard`.
  Future<void> _delete(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce rendez-vous ?'),
        content: const Text(
          'Cette action est définitive et ne supprime que cet élément de '
          'votre agenda — elle ne touche à aucun paiement déjà effectué.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _appointmentService.deleteAppointment(appointment.id);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      final message =
          e is ApiException ? e.message : 'La suppression a échoué.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Ordre d'affichage des groupes en vue "Tous" : les RDV qui demandent
  // encore une action (en attente, confirmé) en haut, l'historique en dessous.
  static const _groupOrder = [
    AppointmentStatus.pending,
    AppointmentStatus.confirmed,
    AppointmentStatus.completed,
    AppointmentStatus.cancelled,
    AppointmentStatus.rejected,
  ];

  /// Construit une carte pour un RDV donné — extrait du builder de liste
  /// pour être réutilisé par les groupes par statut (vue "Tous") et par la
  /// liste filtrée (vue par balise).
  Widget _buildCard(Appointment appointment) {
    final psychologist = _psychologistsById[appointment.psychologistId];
    // Reporter/Annuler n'ont de sens que pour un RDV encore modifiable et
    // pas déjà passé.
    final modifiable = (appointment.status == AppointmentStatus.pending ||
            appointment.status == AppointmentStatus.confirmed) &&
        appointment.startTime.isAfter(DateTime.now());
    // Rejoindre l'appel : RDV confirmé + consultation vidéo/audio uniquement
    // (chat passe par la messagerie, cabinet n'a pas de session distante).
    // Même fenêtre que côté backend (SessionServiceImpl.startSession) : 10
    // min avant le créneau jusqu'à sa fin.
    final now = DateTime.now();
    final callWindowOpen =
        now.isAfter(appointment.startTime.subtract(const Duration(minutes: 10))) &&
            now.isBefore(appointment.endTime);
    final isCallType = appointment.consultationType == ConsultationType.video ||
        appointment.consultationType == ConsultationType.audio;
    final canJoinCall = appointment.status == AppointmentStatus.confirmed &&
        isCallType &&
        callWindowOpen;
    // RDV confirmé, du bon type, mais pas encore l'heure : message indicatif
    // plutôt qu'un bouton qui disparaît sans explication.
    final callNotYetOpen = appointment.status == AppointmentStatus.confirmed &&
        isCallType &&
        !callWindowOpen &&
        now.isBefore(appointment.startTime);
    // Suppression réservée aux RDV sans suite (annulé/refusé), cf.
    // AppointmentServiceImpl.deleteAppointment.
    final deletable = appointment.status == AppointmentStatus.cancelled ||
        appointment.status == AppointmentStatus.rejected;
    return _AppointmentCard(
      appointment: appointment,
      psychologist: psychologist,
      // Le paiement n'est proposé qu'une fois le rendez-vous CONFIRMED par
      // le psychologue (cf. PaymentServiceImpl côté backend, qui refuse
      // tout paiement sur un RDV encore PENDING), et plus du tout si un
      // paiement COMPLETED existe déjà pour ce RDV.
      onPay: appointment.status == AppointmentStatus.confirmed &&
              (psychologist?.consultationPrice ?? 0) > 0 &&
              !_paidAppointmentIds.contains(appointment.id)
          ? () => _pay(appointment, psychologist)
          : null,
      onJoinCall:
          canJoinCall ? () => _joinCall(appointment, psychologist) : null,
      callNotYetOpen: callNotYetOpen,
      onReschedule: modifiable ? () => _reschedule(appointment) : null,
      onCancel: modifiable ? () => _cancel(appointment) : null,
      onDelete: deletable ? () => _delete(appointment) : null,
    );
  }

  // Slivers du contenu principal (hors titre/filtres) : soit une liste
  // plate filtrée par balise, soit des sections groupées par statut quand
  // "Tous" est sélectionné.
  List<Widget> _buildContentSlivers() {
    if (_statusFilter != null) {
      final filtered =
          _appointments.where((a) => a.status == _statusFilter).toList();
      if (filtered.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Aucun rendez-vous "${_statusFilter!.label}".',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildCard(filtered[i]),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    for (final status in _groupOrder) {
      final items =
          _appointments.where((a) => a.status == status).toList();
      if (items.isEmpty) continue;
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${status.label} (${items.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildCard(items[i]),
          ),
        ),
      );
    }
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text('Mes rendez-vous',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
            ),
            if (!_loading && _error == null && _appointments.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 0, 8),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 20),
                      itemCount: _groupOrder.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final status = i == 0 ? null : _groupOrder[i - 1];
                        final label = status?.label ?? 'Tous';
                        final selected = _statusFilter == status;
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _statusFilter = status),
                          selectedColor: AppColors.teal,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                                color: selected
                                    ? AppColors.teal
                                    : AppColors.tealMid),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off,
                            color: AppColors.muted, size: 36),
                        const SizedBox(height: 8),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                ),
              )
            else if (_appointments.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Aucun rendez-vous pour le moment.',
                      style: TextStyle(color: AppColors.muted)),
                ),
              )
            else
              ..._buildContentSlivers(),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    this.psychologist,
    this.onPay,
    this.onJoinCall,
    this.callNotYetOpen = false,
    this.onReschedule,
    this.onCancel,
    this.onDelete,
  });

  final Appointment appointment;
  final PsychologistProfile? psychologist;
  final VoidCallback? onPay;
  final VoidCallback? onJoinCall;
  // RDV confirmé et de type appel, mais pas encore dans la fenêtre
  // autorisée (10 min avant le créneau jusqu'à sa fin).
  final bool callNotYetOpen;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  Color get _statusColor {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return AppColors.gold;
      case AppointmentStatus.confirmed:
        return AppColors.teal;
      case AppointmentStatus.completed:
        return AppColors.muted;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.rejected:
        return AppColors.rose;
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = appointment.startTime;
    final date = '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}/${start.year} à '
        '${start.hour.toString().padLeft(2, '0')}h'
        '${start.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealMid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRow(context, date),
          if (appointment.status == AppointmentStatus.pending) ...[
            const SizedBox(height: 8),
            const Text(
              'En attente de confirmation du psychologue. Vous pourrez '
              'payer une fois le rendez-vous confirmé.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (callNotYetOpen) ...[
            const SizedBox(height: 8),
            Text(
              "L'appel pourra être rejoint à partir de "
              '${appointment.startTime.hour.toString().padLeft(2, '0')}h'
              '${appointment.startTime.minute.toString().padLeft(2, '0')} '
              '(10 minutes avant le créneau).',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (onPay != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: Text(
                psychologist?.consultationPrice != null
                    ? 'Payer ${psychologist!.consultationPrice} F CFA'
                    : 'Payer maintenant',
              ),
            ),
          ],
          if (onJoinCall != null) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: onJoinCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                appointment.consultationType == ConsultationType.video
                    ? Icons.videocam
                    : Icons.call,
                size: 18,
              ),
              label: const Text("Rejoindre l'appel"),
            ),
          ],
          if (onReschedule != null || onCancel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onReschedule != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReschedule,
                      icon: const Icon(Icons.event_repeat, size: 18),
                      label: const Text('Reporter'),
                    ),
                  ),
                if (onReschedule != null && onCancel != null)
                  const SizedBox(width: 8),
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rose,
                        side: const BorderSide(color: AppColors.rose),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Annuler'),
                    ),
                  ),
              ],
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Supprimer'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          CircleAvatar(
            backgroundColor: AppColors.tealLight,
            child: Icon(
              appointment.consultationType == ConsultationType.video
                  ? Icons.videocam_outlined
                  : appointment.consultationType == ConsultationType.audio
                      ? Icons.call_outlined
                      : Icons.meeting_room_outlined,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  psychologist?.fullName ?? 'Psychologue',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date · ${appointment.consultationType.label}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              appointment.status.label,
              style: TextStyle(
                  color: _statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
  }
}

/// Nouveau créneau choisi dans [_RescheduleSheet].
class _NewSlot {
  const _NewSlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

/// Feuille de report d'un RDV : reprend le sélecteur date/heure de
/// [PsychologistProfileScreen] (créneaux fixes, pas d'agenda serveur) plutôt
/// que d'en inventer un nouveau. Pas dans la maquette v2 — design libre.
class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.appointment});

  final Appointment appointment;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  static const _slotHours = [9, 10, 11, 14, 15, 16];

  late DateTime _selectedDate;
  late int _selectedHour;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _selectedHour = _slotHours.first;
  }

  Duration get _duration =>
      widget.appointment.endTime.difference(widget.appointment.startTime);

  void _confirm() {
    final start = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _selectedHour);
    Navigator.of(context)
        .pop(_NewSlot(start: start, end: start.add(_duration)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.tealMid,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Reporter le rendez-vous',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text('Nouvelle date', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final date = DateTime.now().add(Duration(days: i + 1));
                  final day = DateTime(date.year, date.month, date.day);
                  final selected = day == _selectedDate;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.teal : AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AppColors.teal : AppColors.tealMid,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_weekdayShort(day.weekday),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: selected
                                      ? Colors.white70
                                      : AppColors.muted)),
                          const SizedBox(height: 2),
                          Text('${day.day}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.text)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text('Nouvelle heure', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slotHours.map((hour) {
                final selected = hour == _selectedHour;
                return ChoiceChip(
                  label: Text('${hour.toString().padLeft(2, '0')}h00'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedHour = hour),
                  selectedColor: AppColors.teal,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: selected ? AppColors.teal : AppColors.tealMid),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _confirm,
              child: const Text('Confirmer le nouveau créneau'),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayShort(int weekday) {
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return labels[weekday - 1];
  }
}
