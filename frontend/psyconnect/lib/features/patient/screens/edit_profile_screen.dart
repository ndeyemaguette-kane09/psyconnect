import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/services/profile_service.dart';

/// Formulaire d'édition du Profil patient — infos civiles (nom, téléphone,
/// ville, pays), langue préférée et contact d'urgence.
///
/// La langue préférée se règle ici, regroupée avec le reste de l'édition du
/// profil (elle vivait avant dans l'écran Paramètres, ce qui obligeait à
/// naviguer à deux endroits différents). Le mode anonyme reste dans
/// Paramètres : c'est un réglage de confidentialité, pas une info de profil.
///
/// Les deux endpoints backend (PUT /users/{id} et PUT /patients/{id})
/// attendent l'état complet connu, pas seulement les champs modifiés
/// (DTO de type "create" réutilisé pour la mise à jour) — on repart donc
/// toujours des profils actuels et on ne change que les champs édités ici,
/// en conservant les autres (langue, mode anonyme, antécédents médicaux).
///
/// Design libre par rapport à la maquette v2 (pas d'écran équivalent) :
/// avatar d'initiales + champs regroupés en cartes par section.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.userProfileId,
    required this.patientId,
    required this.userProfile,
    required this.patientProfile,
  });

  final int userProfileId;
  final int patientId;
  final UserProfile userProfile;
  final PatientProfile? patientProfile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _languages = ['Français', 'Wolof', 'Anglais'];

  final _formKey = GlobalKey<FormState>();

  late final _firstName = TextEditingController(text: widget.userProfile.firstName);
  late final _lastName = TextEditingController(text: widget.userProfile.lastName);
  late final _phone = TextEditingController(text: widget.userProfile.phoneNumber);
  late final _city = TextEditingController(text: widget.userProfile.city ?? '');
  late final _country = TextEditingController(text: widget.userProfile.country ?? '');
  late final _emergencyName =
      TextEditingController(text: widget.patientProfile?.emergencyContactName ?? '');
  late final _emergencyPhone =
      TextEditingController(text: widget.patientProfile?.emergencyContactPhone ?? '');
  late String? _language = widget.patientProfile?.preferredLanguage;

  final _profileService = ProfileService();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstName.addListener(_refresh);
    _lastName.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _firstName.removeListener(_refresh);
    _lastName.removeListener(_refresh);
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _city.dispose();
    _country.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  String get _initials {
    final f = _firstName.text.trim();
    final l = _lastName.text.trim();
    final a = f.isNotEmpty ? f[0] : '';
    final b = l.isNotEmpty ? l[0] : '';
    final initials = '$a$b'.toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _profileService.updateUserProfile(
        widget.userProfileId,
        UpdateUserProfileRequest(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phoneNumber: _phone.text.trim(),
          gender: widget.userProfile.gender,
          address: widget.userProfile.address,
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          country: _country.text.trim().isEmpty ? null : _country.text.trim(),
        ),
      );

      await _profileService.updatePatientProfile(
        widget.patientId,
        CreatePatientProfileRequest(
          userProfileId: widget.userProfileId,
          emergencyContactName: _emergencyName.text.trim().isEmpty
              ? null
              : _emergencyName.text.trim(),
          emergencyContactPhone: _emergencyPhone.text.trim().isEmpty
              ? null
              : _emergencyPhone.text.trim(),
          medicalHistory: widget.patientProfile?.medicalHistory,
          preferredLanguage: _language,
          anonymousMode: widget.patientProfile?.anonymousMode,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Impossible d\'enregistrer les modifications.';
        _saving = false;
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
        title: const Text('Modifier le profil', style: TextStyle(color: AppColors.text)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.teal,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.rose)),
                ),
                const SizedBox(height: 16),
              ],
              _SectionLabel('Informations personnelles'),
              const SizedBox(height: 10),
              _FormCard(
                children: [
                  _field(_firstName, 'Prénom', required: true),
                  _field(_lastName, 'Nom', required: true),
                  _field(_phone, 'Téléphone', required: true, keyboardType: TextInputType.phone),
                  _field(_city, 'Ville'),
                  _field(_country, 'Pays', isLast: true),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('Préférences'),
              const SizedBox(height: 10),
              _FormCard(
                children: [
                  InkWell(
                    onTap: _pickLanguage,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.language_outlined,
                              color: AppColors.teal, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Langue préférée',
                                    style: TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(_language ?? 'Non renseignée',
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.muted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel("Contact d'urgence"),
              const SizedBox(height: 10),
              _FormCard(
                children: [
                  _field(_emergencyName, 'Nom du contact'),
                  _field(_emergencyPhone, 'Téléphone du contact',
                      keyboardType: TextInputType.phone, isLast: true),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Langue préférée',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            for (final lang in _languages)
              ListTile(
                title: Text(lang),
                trailing:
                    lang == _language ? const Icon(Icons.check, color: AppColors.teal) : null,
                onTap: () => Navigator.of(context).pop(lang),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _language = selected);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool isLast = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
            : null,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
