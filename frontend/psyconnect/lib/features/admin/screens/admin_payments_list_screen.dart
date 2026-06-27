import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../widgets/page_controls.dart';

/// Écran de "drill-down" ouvert depuis l'onglet Stats (tap sur "Paiements"
/// ou sur la carte de revenu) — pas dans la maquette v2. Liste complète des
/// paiements (GET /admin/payments). Contrairement aux rendez-vous, le
/// backend n'a pas de filtre par statut pour les paiements (vérifié dans
/// AdminController#listPayments côté appointment-service) : le filtre ci-
/// dessous est donc appliqué côté client.
class AdminPaymentsListScreen extends StatefulWidget {
  const AdminPaymentsListScreen({super.key, this.initialStatus});

  final PaymentStatus? initialStatus;

  @override
  State<AdminPaymentsListScreen> createState() => _AdminPaymentsListScreenState();
}

class _AdminPaymentsListScreenState extends State<AdminPaymentsListScreen> {
  static const _pageSize = 10;

  final _adminService = AdminService();

  bool _loading = true;
  String? _error;
  List<Payment> _payments = [];
  PaymentStatus? _filter;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialStatus;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payments = await _adminService.listPayments();
      payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _page = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les paiements.';
        _loading = false;
      });
    }
  }

  List<Payment> get _filtered {
    if (_filter == null) return _payments;
    return _payments.where((p) => p.status == _filter).toList();
  }

  String _formatXof(double amount) {
    final rounded = amount.round();
    final digits = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '$buffer FCFA';
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return AppColors.gold;
      case PaymentStatus.completed:
        return AppColors.teal;
      case PaymentStatus.failed:
        return AppColors.rose;
      case PaymentStatus.refunded:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Paiements',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Tous'),
                            selected: _filter == null,
                            selectedColor: AppColors.tealLight,
                            onSelected: (_) => setState(() {
                              _filter = null;
                              _page = 0;
                            }),
                          ),
                        ),
                        for (final s in PaymentStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(s.label),
                              selected: _filter == s,
                              selectedColor: AppColors.tealLight,
                              onSelected: (_) => setState(() {
                                _filter = s;
                                _page = 0;
                              }),
                            ),
                          ),
                      ],
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
              else if (_filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('Aucun paiement dans cette catégorie.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                )
              else
                _buildPagedList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagedList() {
    final filtered = _filtered;
    final pageCount = pageCountFor(filtered.length, _pageSize);
    final pageItems = paginate(filtered, _page, _pageSize);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          for (final p in pageItems) ...[
            _PaymentRow(
              payment: p,
              statusColor: _statusColor(p.status),
              dateLabel: _formatDateTime(p.createdAt),
              amountLabel: _formatXof(p.amount),
            ),
            const SizedBox(height: 10),
          ],
          PageControls(
            page: _page,
            pageCount: pageCount,
            onPageChanged: (p) => setState(() => _page = p),
          ),
        ]),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.statusColor,
    required this.dateLabel,
    required this.amountLabel,
  });

  final Payment payment;
  final Color statusColor;
  final String dateLabel;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealMid),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(amountLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text('RDV #${payment.appointmentId} · ${payment.method.label}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(dateLabel, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(payment.status.label,
                style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
