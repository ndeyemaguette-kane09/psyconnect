import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/services/profile_service.dart';
import '../../patient/models/appointment_models.dart';
import '../../patient/services/appointment_service.dart';
import '../../payment/models/payment_models.dart';
import '../../payment/services/payment_service.dart';
import '../utils/patient_name.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final int appointmentId;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final _appointmentService = AppointmentService();
  final _profileService = ProfileService();
  final _paymentService = PaymentService();

  Appointment? _appointment;
  PatientProfile? _patient;
  List<Payment>? _payments;
  bool _loading = true;
  bool _saving = false;
  String? _error;

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
      final appointment =
          await _appointmentService.getAppointmentById(widget.appointmentId);
      PatientProfile? patient;
      List<Payment>? payments;
      try {
        patient =
            await _profileService.getPatientProfileById(appointment.patientId);
      } catch (_) {}
      try {
        payments =
            await _paymentService.getPaymentsByAppointmentId(appointment.id);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _appointment = appointment;
        _patient = patient;
        _payments = payments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _answer(AppointmentStatus status) async {
    final appointment = _appointment;
    if (appointment == null) return;
    setState(() => _saving = true);
    try {
      final updated = await _appointmentService.updateAppointmentStatus(
          appointment.id, status);
      if (!mounted) return;
      setState(() {
        _appointment = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_answerMessage(appointment, status))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessage(e))),
      );
    }
  }

  String _answerMessage(Appointment before, AppointmentStatus status) {
    if (before.modalityChangePending) {
      return status == AppointmentStatus.confirmed
          ? 'Séance au cabinet confirmée. Le patient est prévenu.'
          : 'La séance garde sa modalité d\'origine. Le patient est prévenu.';
    }
    return status == AppointmentStatus.confirmed
        ? 'Rendez-vous confirmé.'
        : 'Rendez-vous refusé.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du rendez-vous')),
      body: _loading
          ? const AppLoadingState()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppNoticeCard(
                      icon: Icons.info_outline,
                      title: 'Rendez-vous indisponible',
                      message: '$_error\nTouchez ici pour réessayer.',
                      accent: AppColors.info,
                      onTap: _load,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildContent(_appointment!),
                ),
    );
  }

  Widget _buildContent(Appointment appointment) {
    final name = patientDisplayName(_patient);
    final previous = appointment.previousConsultationType;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        AppCard(
          child: Row(
            children: [
              AppAvatar(name: name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(appointment),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (appointment.modalityChangePending && previous != null) ...[
          const SizedBox(height: 24),
          const _Heading('Changement de modalité demandé'),
          const SizedBox(height: 10),
          _ModalityChange(
            from: previous,
            to: appointment.consultationType,
          ),
          const SizedBox(height: 10),
          Text(
            'Le patient souhaite venir au cabinet. '
            'Sinon, la séance reste ${_modalityPhrase(previous)}.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.text,
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _Heading('Séance'),
        const SizedBox(height: 6),
        _Row(label: 'Statut', value: _statusText(appointment)),
        _Row(
          label: 'Modalité',
          value: appointment.consultationType.label,
        ),
        if (previous != null && !appointment.modalityChangePending)
          _Row(label: 'Modalité initiale', value: previous.label),
        _Row(label: 'Durée', value: _durationText(appointment)),
        const SizedBox(height: 24),
        const _Heading('Paiement'),
        const SizedBox(height: 10),
        _buildPayment(),
        if (appointment.status == AppointmentStatus.pending) ...[
          const SizedBox(height: 28),
          FilledButton(
            onPressed:
                _saving ? null : () => _answer(AppointmentStatus.confirmed),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(appointment.modalityChangePending
                ? 'Confirmer la séance au cabinet'
                : 'Confirmer le rendez-vous'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed:
                _saving ? null : () => _answer(AppointmentStatus.rejected),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(appointment.modalityChangePending && previous != null
                ? 'Garder la séance ${_modalityPhrase(previous)}'
                : 'Refuser le rendez-vous'),
          ),
        ],
      ],
    );
  }

  Widget _buildPayment() {
    final payments = _payments;
    if (payments == null) {
      return AppNoticeCard(
        icon: Icons.info_outline,
        title: 'Vérification impossible pour le moment',
        message: 'Touchez ici pour réessayer.',
        accent: AppColors.info,
        onTap: _load,
      );
    }
    final paid =
        payments.where((p) => p.status == PaymentStatus.completed).toList();
    if (paid.isEmpty) {
      return const AppNoticeCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Pas encore payé',
        message: 'Le patient n\'a pas encore réglé cette séance.',
        accent: AppColors.warning,
      );
    }
    final amount = paid.fold<int>(0, (sum, p) => sum + p.amount);
    final method = paid.first.method?.label;
    return AppNoticeCard(
      icon: Icons.check_circle_outline,
      title: 'Payé : ${formatAmount(amount)} F CFA',
      message: method != null ? 'Réglé par $method.' : 'Réglé depuis le solde du patient.',
      accent: AppColors.success,
    );
  }

  String _statusText(Appointment appointment) {
    if (appointment.modalityChangePending) return 'À reconfirmer';
    return appointment.status.label;
  }

  String _durationText(Appointment appointment) {
    final minutes =
        appointment.endTime.difference(appointment.startTime).inMinutes;
    return '$minutes min';
  }

  String _formatDateTime(Appointment appointment) {
    final start = appointment.startTime.toLocal();
    final end = appointment.endTime.toLocal();
    String hm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${_weekdays[start.weekday - 1]} ${start.day} '
        '${_months[start.month - 1]} ${start.year}, ${hm(start)} – ${hm(end)}';
  }
}

String _modalityPhrase(ConsultationType type) {
  switch (type) {
    case ConsultationType.video:
      return 'en vidéo';
    case ConsultationType.audio:
      return 'en audio';
    case ConsultationType.physical:
      return 'au cabinet';
    case ConsultationType.chat:
      return 'par messagerie';
  }
}

class _ModalityChange extends StatelessWidget {
  const _ModalityChange({required this.from, required this.to});

  final ConsultationType from;
  final ConsultationType to;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: _ModalityBox(caption: 'Prévue', type: from)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward, color: AppColors.muted),
          ),
          Expanded(
            child: _ModalityBox(caption: 'Demandée', type: to, highlight: true),
          ),
        ],
      ),
    );
  }
}

class _ModalityBox extends StatelessWidget {
  const _ModalityBox({
    required this.caption,
    required this.type,
    this.highlight = false,
  });

  final String caption;
  final ConsultationType type;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          type.label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: highlight ? AppColors.teal : AppColors.text,
          ),
        ),
      ],
    );
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15.5, color: AppColors.muted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
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
