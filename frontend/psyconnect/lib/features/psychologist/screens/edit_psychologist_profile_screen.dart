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
    final hasDocument = widget.psychologist.hasLicenseDocument == true;

    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Modifier mon profil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                'Ces informations apparaissent sur votre fiche, côté patient.',
                style: TextStyle(fontSize: 15.5, color: AppColors.muted),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 14.5),
                ),
              ),
            ],
            const _Heading('Mon métier'),
            _field(_specialty, 'Spécialité', required: true),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(_years, 'Expérience (ans)',
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(_price, 'Prix (F CFA)',
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
            _field(_languages, 'Langues parlées', hint: 'Ex : Français, Wolof'),
            _field(_licenseNumber, 'Numéro de licence', isLast: true),
            const _Heading('Où me trouver'),
            _field(_city, 'Ville'),
            _field(
              _address,
              'Adresse du cabinet',
              hint: 'Visible par les patients pour les séances en cabinet',
              isLast: true,
            ),
            const _Heading('Ma présentation'),
            _field(
              _bio,
              'Quelques mots pour vos patients',
              maxLines: 5,
              isLast: true,
            ),
            const _Heading('Justificatif de diplôme'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                hasDocument
                    ? 'Un justificatif est déjà enregistré.'
                    : 'Aucun justificatif enregistré pour l\'instant.',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: hasDocument ? AppColors.teal : AppColors.goldDark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _uploadingLicense ? null : _reuploadLicenseDocument,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.text,
                ),
                icon: _uploadingLicense
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined, size: 20),
                label: Text(
                  _newLicenseName ??
                      (hasDocument
                          ? 'Remplacer le justificatif'
                          : 'Envoyer un justificatif'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_licenseUploadMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  _licenseUploadMessage!,
                  style: TextStyle(
                    color:
                        _licenseUploadError ? AppColors.danger : AppColors.teal,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enregistrer'),
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
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
            : null,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
    );
  }
}
