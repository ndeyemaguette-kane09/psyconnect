import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../widgets/page_controls.dart';

// Onglet "Utilisateurs" : liste tous les comptes (email, pseudo, rôle)
// avec activation/désactivation. Les fiches détaillées des psychologues
// sont dans l'onglet Validation.
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

enum _RoleFilter { all, patient, psychologist, admin }

extension on _RoleFilter {
  String get label {
    switch (this) {
      case _RoleFilter.all:
        return 'Tous';
      case _RoleFilter.patient:
        return 'Patients';
      case _RoleFilter.psychologist:
        return 'Psychologues';
      case _RoleFilter.admin:
        return 'Admins';
    }
  }

  String? get apiValue {
    switch (this) {
      case _RoleFilter.all:
        return null;
      case _RoleFilter.patient:
        return 'PATIENT';
      case _RoleFilter.psychologist:
        return 'PSYCHOLOGIST';
      case _RoleFilter.admin:
        return 'ADMIN';
    }
  }
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  static const _pageSize = 12;

  final _adminService = AdminService();

  bool _loading = true;
  String? _error;
  List<UserAccount> _users = [];
  _RoleFilter _filter = _RoleFilter.all;
  String? _busyUserId;
  int _page = 0;

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
      final users = await _adminService.listUsers();
      users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _users = users;
        _page = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les comptes.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleEnabled(UserAccount user) async {
    setState(() => _busyUserId = '${user.id}');
    try {
      final updated = await _adminService.setUserEnabled(user.id, !user.enabled);
      if (!mounted) return;
      setState(() {
        _users = [
          for (final u in _users) if (u.id == updated.id) updated else u,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible pour le moment.')),
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _confirmDelete(UserAccount user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
          'Le compte de ${user.fullName.isEmpty ? user.pseudo : user.fullName} '
          'sera supprimé définitivement. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyUserId = '${user.id}');
    try {
      await _adminService.deleteUser(user.id);
      if (!mounted) return;
      setState(() {
        _users = [for (final u in _users) if (u.id != user.id) u];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression impossible pour le moment.')),
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _confirmResetPassword(UserAccount user) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser le mot de passe'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nouveau mot de passe',
              helperText: '6 caractères minimum',
            ),
            validator: (value) =>
                (value == null || value.length < 6) ? 'Trop court (min. 6)' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (newPassword == null) return;

    setState(() => _busyUserId = '${user.id}');
    try {
      await _adminService.resetPassword(user.id, newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe réinitialisé.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible pour le moment.')),
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  List<UserAccount> get _filtered {
    final apiValue = _filter.apiValue;
    if (apiValue == null) return _users;
    return _users.where((u) => u.role == apiValue).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Text('Utilisateurs',
                    style: Theme.of(context).textTheme.displayMedium),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _RoleFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: _filter == f,
                            selectedColor: AppColors.tealLight,
                            onSelected: (_) => setState(() {
                              _filter = f;
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
                  child: Text('Aucun compte dans cette catégorie.',
                      style: TextStyle(color: AppColors.muted)),
                ),
              )
            else
              _buildPagedList(_filtered),
          ],
        ),
      ),
    );
  }

  Widget _buildPagedList(List<UserAccount> filtered) {
    final pageCount = pageCountFor(filtered.length, _pageSize);
    final pageItems = paginate(filtered, _page, _pageSize);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          for (final user in pageItems) ...[
            _UserCard(
              user: user,
              busy: _busyUserId == '${user.id}',
              onToggle: () => _toggleEnabled(user),
              onDelete: () => _confirmDelete(user),
              onResetPassword: () => _confirmResetPassword(user),
            ),
            const SizedBox(height: 10),
          ],
          PageControls(
            page: _page,
            pageCount: pageCount,
            onPageChanged: (p) => setState(() => _page = p),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
    required this.onResetPassword,
  });

  final UserAccount user;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onResetPassword;

  String get _roleLabel {
    switch (user.role) {
      case 'PATIENT':
        return 'Patient';
      case 'PSYCHOLOGIST':
        return 'Psychologue';
      case 'ADMIN':
        return 'Admin';
      default:
        return user.role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user.fullName.isEmpty ? user.pseudo : user.fullName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealMid),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                user.enabled ? AppColors.tealLight : AppColors.errorBg,
            child: Icon(Icons.person,
                color: user.enabled ? AppColors.tealDark : AppColors.rose),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(user.email,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_roleLabel,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  activeColor: AppColors.teal,
                  value: user.enabled,
                  onChanged: (_) => onToggle(),
                ),
                // Suppression et réinitialisation réservées aux comptes non-admin :
                // le backend refuse déjà ces opérations sur un compte ADMIN.
                if (user.role != 'ADMIN')
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: AppColors.muted),
                    onSelected: (value) {
                      if (value == 'reset') onResetPassword();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'reset',
                        child: Text('Réinitialiser le mot de passe'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Supprimer le compte',
                            style: TextStyle(color: AppColors.rose)),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
