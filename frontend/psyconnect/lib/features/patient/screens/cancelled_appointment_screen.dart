import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/services/profile_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';
import '../models/appointment_models.dart';
import '../models/psychologist_models.dart';
import '../../psychologist/utils/patient_name.dart';
import '../services/psychologist_service.dart';

class CancelledAppointmentScreen extends StatefulWidget {
  const CancelledAppointmentScreen({
    super.key,
    required this.appointment,
    this.viewedByPsychologist = false,
  });

  final Appointment appointment;
  final bool viewedByPsychologist;

  @override
  State<CancelledAppointmentScreen> createState() =>
      _CancelledAppointmentScreenState();
}

class _CancelledAppointmentScreenState
    extends State<CancelledAppointmentScreen> {
  final _paymentService = PaymentService();
  final _psychologistService = PsychologistService();
  final _profileService = ProfileService();

  PsychologistProfile? _psychologist;
  PatientProfile? _patient;
  List<Payment>? _payments;
  bool _loading = true;
  bool _paymentError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _paymentError = false;
    });
    PsychologistProfile? psychologist;
    PatientProfile? patient;
    List<Payment>? payments;
    var paymentError = false;
    try {
      if (widget.viewedByPsychologist) {
        patient = await _profileService
            .getPatientProfileById(widget.appointment.patientId);
      } else {
        psychologist = await _psychologistService
            .getPsychologistById(widget.appointment.psychologistId);
      }
    } catch (_) {}
    try {
      payments = await _paymentService
          .getPaymentsByAppointmentId(widget.appointment.id);
    } catch (_) {
      paymentError = true;
    }
    if (!mounted) return;
    setState(() {
      _psychologist = psychologist;
      _patient = patient;
      _payments = payments;
      _paymentError = paymentError;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final counterpartName = widget.viewedByPsychologist
        ? patientDisplayName(_patient)
        : _psychologist?.fullName ?? 'Votre psychologue';

    return Scaffold(
      appBar: AppBar(title: const Text('Rendez-vous annulé')),
      body: _loading
          ? const AppLoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      AppAvatar(name: counterpartName, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              counterpartName,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDateTime(appointment.startTime),
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Consultation : ${appointment.consultationType.label}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _Heading('Pourquoi ce rendez-vous a été annulé'),
                const SizedBox(height: 10),
                Text(
                  _reasonText(appointment),
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 28),
                const _Heading('Paiement'),
                const SizedBox(height: 10),
                _buildPaymentNotice(appointment),
              ],
            ),
    );
  }

  Widget _buildPaymentNotice(Appointment appointment) {
    if (_paymentError || _payments == null) {
      return AppNoticeCard(
        icon: Icons.info_outline,
        title: 'Vérification impossible pour le moment',
        message: 'Nous n\'avons pas pu récupérer le paiement de ce rendez-vous. '
            'Touchez ici pour réessayer.',
        accent: AppColors.info,
        background: AppColors.infoBg,
        onTap: _load,
      );
    }

    final payments = _payments!;
    final refunded =
        payments.where((p) => p.status == PaymentStatus.refunded).toList();
    final kept =
        payments.where((p) => p.status == PaymentStatus.completed).toList();

    if (refunded.isNotEmpty) {
      final amount = refunded.fold<int>(0, (sum, p) => sum + p.amount);
      final when = appointment.cancelledAt != null
          ? ' le ${_formatDate(appointment.cancelledAt!)}'
          : '';
      if (widget.viewedByPsychologist) {
        return AppNoticeCard(
          icon: Icons.undo_rounded,
          title: 'Remboursé au patient : ${formatAmount(amount)} F CFA',
          message: appointment.cancellationReason == null ||
                  appointment.cancellationReason == CancellationReason.patient
              ? 'Le patient a annulé plus de 48 heures avant la séance : '
                  'il a été remboursé. Ce montant n\'entre pas dans vos revenus.'
              : 'L\'annulation ne venait pas du patient : il a été remboursé '
                  'en totalité. Ce montant n\'entre pas dans vos revenus.',
          accent: AppColors.info,
          background: AppColors.infoBg,
        );
      }
      return AppNoticeCard(
        icon: Icons.check_circle_outline,
        title: 'Remboursé : ${formatAmount(amount)} F CFA',
        message: appointment.cancellationReason == null ||
                appointment.cancellationReason == CancellationReason.patient
            ? 'Le montant a été recrédité sur votre solde PsyConnect$when. '
                'Vous avez annulé plus de 48 heures avant la séance : '
                'c\'est la condition pour être remboursé.'
            : 'Le montant a été recrédité en totalité sur votre solde '
                'PsyConnect$when. L\'annulation ne venait pas de vous : '
                'le paiement vous est donc entièrement rendu.',
        accent: AppColors.success,
        background: AppColors.successBg,
      );
    }

    if (kept.isNotEmpty) {
      final amount = kept.fold<int>(0, (sum, p) => sum + p.amount);
      if (widget.viewedByPsychologist) {
        return AppNoticeCard(
          icon: Icons.check_circle_outline,
          title: 'Paiement conservé : ${formatAmount(amount)} F CFA',
          message: 'Le patient a annulé moins de 48 heures avant la séance : '
              'le paiement reste acquis et compte dans vos revenus.',
          accent: AppColors.success,
          background: AppColors.successBg,
        );
      }
      return AppNoticeCard(
        icon: Icons.info_outline,
        title: 'Pas de remboursement (${formatAmount(amount)} F CFA)',
        message: 'L\'annulation a eu lieu moins de 48 heures avant la séance. '
            'Passé ce délai, le paiement reste acquis : le psychologue avait '
            'réservé ce créneau pour vous et ne pouvait plus le proposer '
            'à quelqu\'un d\'autre.',
        accent: AppColors.warning,
        background: AppColors.warningBg,
      );
    }

    if (widget.viewedByPsychologist) {
      return const AppNoticeCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Aucun paiement',
        message: 'Ce rendez-vous n\'avait pas été payé par le patient.',
        accent: AppColors.tealDark,
        background: AppColors.tealSoft,
      );
    }
    return const AppNoticeCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Aucun montant débité',
      message: 'Ce rendez-vous n\'avait pas été payé : '
          'rien n\'a été prélevé sur votre solde.',
      accent: AppColors.tealDark,
      background: AppColors.tealSoft,
    );
  }

  String _reasonText(Appointment appointment) {
    if (widget.viewedByPsychologist) {
      switch (appointment.cancellationReason) {
        case CancellationReason.patient:
          return appointment.cancelledAt != null
              ? 'Le patient a annulé ce rendez-vous le ${_formatDate(appointment.cancelledAt!)}.'
              : 'Le patient a annulé ce rendez-vous.';
        case CancellationReason.psychologistNoResponse:
          return 'Vous n\'avez pas confirmé cette demande au moins 2 heures '
              'avant la séance : elle a été annulée automatiquement.';
        case CancellationReason.unpaid:
          return 'Le patient n\'a pas payé ce rendez-vous au moins 1 heure '
              'avant la séance : il a été annulé automatiquement et le '
              'créneau a été libéré.';
        case null:
          return 'Ce rendez-vous a été annulé.';
      }
    }
    switch (appointment.cancellationReason) {
      case CancellationReason.patient:
        return appointment.cancelledAt != null
            ? 'Vous avez annulé ce rendez-vous le ${_formatDate(appointment.cancelledAt!)}.'
            : 'Vous avez annulé ce rendez-vous.';
      case CancellationReason.psychologistNoResponse:
        return 'Le psychologue n\'a pas confirmé votre demande au moins '
            '1 heure avant la séance. Elle a donc été annulée automatiquement. '
            'Vous pouvez réserver un autre créneau.';
      case CancellationReason.unpaid:
        return 'Le rendez-vous n\'a pas été payé au moins 30 minutes avant '
            'la séance. Il a donc été annulé automatiquement et le créneau '
            'a été libéré.';
      case null:
        return 'Ce rendez-vous a été annulé.';
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_weekdays[local.weekday - 1]} ${_formatDate(local)} à $hour:$minute';
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
    );
  }
}

const _weekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];
