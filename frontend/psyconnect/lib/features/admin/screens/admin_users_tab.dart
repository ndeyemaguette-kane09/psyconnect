import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
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
  String _query = '';

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
    final q = _query.trim().toLowerCase();
    return _users.where((u) {
      if (apiValue != null && u.role != apiValue) return false;
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
          u.pseudo.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Utilisateurs',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              }),
              decoration: const InputDecoration(
                hintText: 'Rechercher un nom ou un e-mail',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in _RoleFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: _filter == f ? AppColors.teal : AppColors.sand,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () => setState(() {
                            _filter = f;
                            _page = 0;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _filter == f
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: _filter == f
                                      ? AppColors.background
                                      : AppColors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _load)
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _query.trim().isEmpty
                      ? 'Aucun compte dans cette catégorie.'
                      : 'Aucun compte ne correspond à « ${_query.trim()} ».',
                  style:
                      const TextStyle(fontSize: 15.5, color: AppColors.muted),
                ),
              )
            else ...[
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final user in paginate(filtered, _page, _pageSize))
                      _UserRow(
                        user: user,
                        busy: _busyUserId == '${user.id}',
                        onToggle: () => _toggleEnabled(user),
                        onDelete: () => _confirmDelete(user),
                        onResetPassword: () => _confirmResetPassword(user),
                      ),
                  ],
                ),
              ),
              PageControls(
                page: _page,
                pageCount: pageCountFor(filtered.length, _pageSize),
                onPageChanged: (p) => setState(() => _page = p),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AppAvatar(name: name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '$_roleLabel · ${user.email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13.5, color: AppColors.muted),
                ),
                if (!user.enabled)
                  const Text(
                    'Compte suspendu',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            Switch(
              value: user.enabled,
              activeThumbColor: AppColors.white,
              activeTrackColor: AppColors.teal,
              onChanged: (_) => onToggle(),
            ),
            // Suppression et réinitialisation réservées aux comptes non-admin :
            // le backend refuse déjà ces opérations sur un compte ADMIN.
            if (user.role != 'ADMIN')
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 20, color: AppColors.muted),
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
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              )
            else
              const SizedBox(width: 48),
          ],
        ],
      ),
    );
  }
}
