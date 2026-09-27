import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';

class _Broadcast {
  final int id;
  final String title;
  final String message;
  final String audience;
  final DateTime sentAt;

  _Broadcast({
    required this.id,
    required this.title,
    required this.message,
    required this.audience,
    required this.sentAt,
  });

  factory _Broadcast.fromJson(Map<String, dynamic> j) => _Broadcast(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        message: j['message'] as String? ?? '',
        audience: j['audience'] as String? ?? 'ALL',
        sentAt: j['sentAt'] != null
            ? DateTime.parse(j['sentAt'] as String)
            : DateTime.now(),
      );
}

// ecran "Annonces système" : affiche les broadcasts admin stockés en base
// dans user-service, filtrés selon le rôle de l'utilisateur connecté.
// Accessible depuis la home patient et la home psy (icône mégaphone).
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.lastSeen});

  // Date de la dernière consultation de l'écran, lue par l'appelant avant la
  // navigation. Les annonces postées après sont marquées comme non lues.
  final DateTime? lastSeen;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _api = ApiClient();

  bool _loading = true;
  String? _error;
  List<_Broadcast> _broadcasts = [];

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
      final json = await _api.get(ApiConstants.broadcasts);
      final list = (json as List)
          .map((e) => _Broadcast.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
      if (!mounted) return;
      setState(() {
        _broadcasts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les annonces.';
        _loading = false;
      });
    }
  }

  bool _isUnread(_Broadcast b) {
    final seen = widget.lastSeen;
    return seen != null && b.sentAt.isAfter(seen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Annonces'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60),
        children: [AppErrorState(message: _error!, onRetry: _load)],
      );
    }

    if (_broadcasts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60),
        children: const [
          AppEmptyState(
            icon: Icons.campaign_outlined,
            title: 'Aucune annonce',
            message:
                'Les messages de l\'équipe PsyConnect apparaîtront ici.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        for (final b in _broadcasts)
          _BroadcastEntry(broadcast: b, unread: _isUnread(b)),
        Container(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _BroadcastEntry extends StatelessWidget {
  const _BroadcastEntry({required this.broadcast, required this.unread});

  final _Broadcast broadcast;
  final bool unread;

  static const _months = [
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

  String get _dateline {
    final d = broadcast.sentAt;
    final month = _months[d.month - 1];
    final date = '${d.day} $month ${d.year}';

    switch (broadcast.audience) {
      case 'PATIENTS':
        return '$date · Aux patients';
      case 'PSYCHOLOGISTS':
        return '$date · Aux psychologues';
      default:
        return '$date · Équipe PsyConnect';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dateline,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Nouveau',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              broadcast.title,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              broadcast.message,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
