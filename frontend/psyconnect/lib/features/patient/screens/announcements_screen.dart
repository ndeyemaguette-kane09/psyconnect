import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

// modèle léger pour les broadcasts lus depuis user-service
class _Broadcast {
  final int id;
  final String title;
  final String message;
  final String audience;
  final int recipientCount;
  final DateTime sentAt;

  _Broadcast({
    required this.id,
    required this.title,
    required this.message,
    required this.audience,
    required this.recipientCount,
    required this.sentAt,
  });

  factory _Broadcast.fromJson(Map<String, dynamic> j) => _Broadcast(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? '',
        message: j['message'] as String? ?? '',
        audience: j['audience'] as String? ?? 'ALL',
        recipientCount: (j['recipientCount'] as num?)?.toInt() ?? 0,
        sentAt: j['sentAt'] != null
            ? DateTime.parse(j['sentAt'] as String)
            : DateTime.now(),
      );
}

// ecran "Annonces système" : affiche les broadcasts admin stockés en base
// dans user-service, filtrés selon le rôle de l'utilisateur connecté.
// Accessible depuis la home patient et la home psy (icône mégaphone).
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

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
          .toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Annonces système',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style:
                                      const TextStyle(color: AppColors.muted)),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                  onPressed: _load,
                                  child: const Text('Réessayer')),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _broadcasts.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 100),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEDE9FE),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.campaign_outlined,
                                        size: 32,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Aucune annonce',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Les annonces de l\'administrateur\napparaîtront ici.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: AppColors.muted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: _broadcasts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _BroadcastCard(broadcast: _broadcasts[i]),
                        ),
        ),
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.broadcast});

  final _Broadcast broadcast;

  String get _audienceLabel {
    switch (broadcast.audience) {
      case 'PATIENTS':
        return 'Patients';
      case 'PSYCHOLOGISTS':
        return 'Psychologues';
      default:
        return 'Tous les utilisateurs';
    }
  }

  String get _relativeDate {
    final now = DateTime.now();
    final diff = now.difference(broadcast.sentAt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    final d = broadcast.sentAt;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // barre latérale violet
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFFEDE9FE),
                          child: Icon(
                            Icons.campaign_outlined,
                            size: 16,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            broadcast.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      broadcast.message,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.text, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.access_time_outlined,
                            size: 12, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          _relativeDate,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _audienceLabel,
                            style: const TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
