import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/models/profile_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/profile_service.dart';
import '../../patient/models/psychologist_models.dart';

// edition du profil psychologue : jusqu'ici aucun ecran d'edition n'existait,
// city/address/etc n'etaient saisissables qu'a l'inscription (register_screen)
// pas dans la maquette, design libre, repris du style de EditProfileScreen (patient)
class EditPsychologistProfileScreen extends StatefulWidget {
  const EditPsychologistProfileScreen({
    super.key,
    required this.psychologistId,
    required this.psychologist,
  });

  final int psychologistId;
  final PsychologistProfile psychologist;

  @override
  State<EditPsychologistProfileScreen> createState() =>
      _EditPsychologistProfileScreenState();
}

class _EditPsychologistProfileScreenState
    extends State<EditPsychologistProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _specialty =
      TextEditingController(text: widget.psychologist.specialty);
  late final _bio = TextEditingController(text: widget.psychologist.bio ?? '');
  late final _years = TextEditingController(
      text: widget.psychologist.yearsOfExperience?.toString() ?? '');
  late final _price = TextEditingController(
      text: widget.psychologist.consultationPrice?.toString() ?? '');
  late final _languages =
      TextEditingController(text: widget.psychologist.languages ?? '');
  late final _city = TextEditingController(text: widget.psychologist.city ?? '');
  late final _address =
      TextEditingController(text: widget.psychologist.address ?? '');
  late final _licenseNumber =
      TextEditingController(text: widget.psychologist.licenseNumber ?? '');

  final _profileService = ProfileService();
  bool _saving = false;
  String? _error;

  // renvoi du justificatif : separe du formulaire principal (endpoint
  // multipart dedie cote backend, deja utilise a l'inscription). utile
  // pour un psy refuse qui doit resoumettre, ou si l'envoi avait echoue
  // au moment de l'inscription
  bool _uploadingLicense = false;
  String? _newLicenseName;
  String? _licenseUploadMessage;
  bool _licenseUploadError = false;

  Future<void> _reuploadLicenseDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final picked = result?.files.single;
    if (picked?.path == null) return;

    setState(() {
      _uploadingLicense = true;
      _newLicenseName = picked!.name;
      _licenseUploadMessage = null;
    });

    try {
      await _profileService.uploadPsychologistLicenseDocument(
        widget.psychologistId,
        picked!.path!,
        fileName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _licenseUploadMessage = 'Justificatif envoyé avec succès.';
        _licenseUploadError = false;
        _uploadingLicense = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _licenseUploadMessage = e is ApiException
            ? e.message
            : "Échec de l'envoi du justificatif.";
        _licenseUploadError = true;
        _uploadingLicense = false;
      });
    }
  }

  @override
  void dispose() {
    _specialty.dispose();
    _bio.dispose();
    _years.dispose();
    _price.dispose();
    _languages.dispose();
    _city.dispose();
    _address.dispose();
    _licenseNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // userProfileId n'est pas utilise par le backend pour une mise a jour
      // (seulement pour la creation), mais le DTO le demande quand meme
      final authUserId = context.read<AuthProvider>().session?.userId;
      final userProfileId = authUserId == null
          ? null
          : await _profileService.getUserProfileIdByAuthUserId(authUserId);

      await _profileService.updatePsychologistProfile(
        widget.psychologistId,
        CreatePsychologistProfileRequest(
          userProfileId: userProfileId ?? 0,
          specialty: _specialty.text.trim(),
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          yearsOfExperience: int.tryParse(_years.text.trim()),
          consultationPrice: int.tryParse(_price.text.trim()),
          languages:
              _languages.text.trim().isEmpty ? null : _languages.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          licenseNumber: _licenseNumber.text.trim().isEmpty
              ? null
              : _licenseNumber.text.trim(),
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
              _SectionLabel('Informations professionnelles'),
              const SizedBox(height: 10),
              _FormCard(
                children: [
                  _field(_specialty, 'Spécialité', required: true),
                  _field(_years, "Années d'expérience",
                      keyboardType: TextInputType.number),
                  _field(_price, 'Prix consultation (FCFA)',
                      keyboardType: TextInputType.number),
                  _field(_languages, 'Langues parlées',
                      hint: 'Ex : Français, Wolof'),
                  _field(_licenseNumber, 'Numéro de licence', isLast: true),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('Localisation'),
              const SizedBox(height: 10),
              _FormCard(
                children: [
                  _field(_city, 'Ville'),
                  _field(
                    _address,
                    'Adresse du cabinet',
                    hint: 'Visible par les patients pour les séances en cabinet',
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('À propos'),
              const SizedBox(height: 10),
              _FormCard(
                children: [
                  _field(_bio, 'Bio', maxLines: 4, isLast: true),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('Justificatif'),
              const SizedBox(height: 10),
              _FormCard(
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.psychologist.hasLicenseDocument == true
                            ? Icons.verified_outlined
                            : Icons.error_outline,
                        size: 18,
                        color: widget.psychologist.hasLicenseDocument == true
                            ? AppColors.teal
                            : AppColors.rose,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.psychologist.hasLicenseDocument == true
                              ? 'Un justificatif est déjà enregistré'
                              : 'Aucun justificatif enregistré',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _uploadingLicense ? null : _reuploadLicenseDocument,
                    icon: _uploadingLicense
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _newLicenseName ??
                          (widget.psychologist.hasLicenseDocument == true
                              ? 'Remplacer le justificatif'
                              : 'Envoyer un justificatif'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_licenseUploadMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _licenseUploadMessage!,
                      style: TextStyle(
                        color: _licenseUploadError
                            ? AppColors.rose
                            : AppColors.teal,
                        fontSize: 12,
                      ),
                    ),
                  ],
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

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool isLast = false,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
