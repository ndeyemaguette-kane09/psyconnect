import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/profile_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/screens/home_screen.dart';
import '../models/auth_models.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../widgets/error_banner.dart';

// Inscription en deux étapes : compte (email, mot de passe, pseudo, nom),
// puis profil (téléphone, ville et champs spécifiques au psychologue).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  String? _registeredEmail;
  String? _registeredPassword;

  // Étape 1 — compte
  final _accountFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pseudoController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _obscurePassword = true;

  // Étape 2 — profil
  final _profileFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  // Adresse du cabinet (psychologue uniquement), visible par les patients venant en présentiel.
  final _addressController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _yearsController = TextEditingController();
  final _priceController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _needController = TextEditingController();
  String _language = ProfileConstants.languages.first;

  // Chemin local du justificatif choisi via file_picker, envoyé après la création du profil.
  // Pas de validator Form pour un file picker : la vérification est faite manuellement.
  // Obligatoire pour un psychologue : sans document, l'administrateur ne peut pas valider
  // le compte, et la connexion reste bloquée jusqu'à l'approbation.
  String? _licenseDocumentPath;
  String? _licenseDocumentName;
  String? _licenseDocumentError;

  bool get _isPsychologist => widget.role == UserRole.psychologist;

  Future<void> _pickLicenseDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final picked = result?.files.single;
    if (picked?.path == null) return;
    setState(() {
      _licenseDocumentPath = picked!.path;
      _licenseDocumentName = picked.name;
      _licenseDocumentError = null;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pseudoController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _specialtyController.dispose();
    _yearsController.dispose();
    _priceController.dispose();
    _licenseNumberController.dispose();
    _needController.dispose();
    super.dispose();
  }

  void _submitAccount(AuthProvider auth) {
    if (!_accountFormKey.currentState!.validate()) return;
    auth.clearError();
    setState(() => _step = 1);
  }

  Future<bool> _ensureAccount(AuthProvider auth) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_registeredEmail == email && _registeredPassword == password) {
      return true;
    }
    final ok = await auth.register(
      role: widget.role,
      account: RegisterAccountRequest(
        email: email,
        password: password,
        pseudo: _pseudoController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      ),
    );
    if (!ok) {
      if (mounted) setState(() => _step = 0);
      return false;
    }
    _registeredEmail = email;
    _registeredPassword = password;
    return true;
  }

  Future<void> _submitProfile(AuthProvider auth) async {
    if (!_profileFormKey.currentState!.validate()) return;

    if (_isPsychologist && _licenseDocumentPath == null) {
      setState(() {
        _licenseDocumentError =
            'Le justificatif (diplôme ou carte professionnelle) est requis.';
      });
      return;
    }

    if (!await _ensureAccount(auth)) return;

    final bool ok;
    if (_isPsychologist) {
      ok = await auth.completePsychologistOnboarding(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        specialty: _specialtyController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        country: ProfileConstants.defaultCountry,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        yearsOfExperience: int.tryParse(_yearsController.text.trim()),
        consultationPrice: int.tryParse(_priceController.text.trim()),
        licenseNumber: _licenseNumberController.text.trim().isEmpty
            ? null
            : _licenseNumberController.text.trim(),
        licenseDocumentPath: _licenseDocumentPath,
        licenseDocumentName: _licenseDocumentName,
      );
    } else {
      ok = await auth.completePatientOnboarding(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        country: ProfileConstants.defaultCountry,
        preferredLanguage: _language,
        medicalHistory: _needController.text.trim().isEmpty
            ? null
            : _needController.text.trim(),
      );
    }

    if (ok && mounted) {
      if (_isPsychologist) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              auth.licenseUploadWarning
                  ? "Compte créé, mais l'envoi du justificatif a échoué. "
                      "Vous pourrez le renvoyer depuis votre profil."
                  : 'Compte créé ! Votre profil est en cours de validation '
                      "par un administrateur — vous ne serez visible des "
                      'patients qu\'une fois approuvé.',
            ),
          ),
        );
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inscription ${widget.role.label.toLowerCase()}',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepIndicator(currentStep: _step),
              const SizedBox(height: 24),
              if (auth.errorMessage != null) ...[
                ErrorBanner(message: auth.errorMessage!),
                const SizedBox(height: 16),
              ],
              if (_step == 0)
                _AccountStep(
                  formKey: _accountFormKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  pseudoController: _pseudoController,
                  firstNameController: _firstNameController,
                  lastNameController: _lastNameController,
                  obscurePassword: _obscurePassword,
                  onToggleObscure: () => setState(
                      () => _obscurePassword = !_obscurePassword),
                  isLoading: auth.isLoading,
                  onSubmit: () => _submitAccount(auth),
                )
              else
                _ProfileStep(
                  formKey: _profileFormKey,
                  isPsychologist: _isPsychologist,
                  phoneController: _phoneController,
                  cityController: _cityController,
                  addressController: _addressController,
                  specialtyController: _specialtyController,
                  yearsController: _yearsController,
                  priceController: _priceController,
                  licenseNumberController: _licenseNumberController,
                  needController: _needController,
                  language: _language,
                  onLanguageChanged: (value) =>
                      setState(() => _language = value),
                  licenseDocumentName: _licenseDocumentName,
                  licenseDocumentError: _licenseDocumentError,
                  onPickLicenseDocument: _pickLicenseDocument,
                  isLoading: auth.isLoading,
                  onSubmit: () => _submitProfile(auth),
                  onBack: () => setState(() => _step = 0),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(active: currentStep >= 0, label: '1. Compte'),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 1 ? AppColors.teal : AppColors.tealMid,
          ),
        ),
        _dot(active: currentStep >= 1, label: '2. Profil'),
      ],
    );
  }

  Widget _dot({required bool active, required String label}) {
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active ? AppColors.teal : AppColors.tealMid,
          child: Text(
            label.substring(0, 1),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? AppColors.teal : AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.pseudoController,
    required this.firstNameController,
    required this.lastNameController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController pseudoController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: _required,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: _required,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: pseudoController,
            decoration: const InputDecoration(
              labelText: 'Pseudo',
              helperText: 'Visible par les autres utilisateurs',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "L'email est requis";
              }
              if (!value.contains('@')) return 'Email invalide';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              helperText: 'Au moins 6 caractères',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Le mot de passe est requis';
              }
              if (value.length < 6) {
                return 'Au moins 6 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  static String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Champ requis';
    return null;
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.formKey,
    required this.isPsychologist,
    required this.phoneController,
    required this.cityController,
    required this.addressController,
    required this.specialtyController,
    required this.yearsController,
    required this.priceController,
    required this.licenseNumberController,
    required this.needController,
    required this.language,
    required this.onLanguageChanged,
    required this.licenseDocumentName,
    required this.licenseDocumentError,
    required this.onPickLicenseDocument,
    required this.isLoading,
    required this.onSubmit,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final bool isPsychologist;
  final TextEditingController phoneController;
  final TextEditingController cityController;
  final TextEditingController addressController;
  final TextEditingController specialtyController;
  final TextEditingController yearsController;
  final TextEditingController priceController;
  final TextEditingController licenseNumberController;
  final TextEditingController needController;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final String? licenseDocumentName;
  final String? licenseDocumentError;
  final VoidCallback onPickLicenseDocument;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quelques infos sur vous',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le téléphone est requis';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: cityController,
            decoration: const InputDecoration(
              labelText: 'Ville (optionnel)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          if (!isPsychologist) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: language,
              decoration: const InputDecoration(
                labelText: 'Langue préférée',
                prefixIcon: Icon(Icons.language_outlined),
              ),
              items: [
                for (final lang in ProfileConstants.languages)
                  DropdownMenuItem(value: lang, child: Text(lang)),
              ],
              onChanged: (value) {
                if (value != null) onLanguageChanged(value);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: needController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ce que vous recherchez (optionnel)',
                hintText: 'Ex : anxiété liée au travail, gestion du stress',
                helperText:
                    'Sert à vous proposer les psychologues les plus adaptés',
                helperMaxLines: 2,
                alignLabelWithHint: true,
              ),
            ),
          ],
          if (isPsychologist) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse du cabinet (optionnel)',
                hintText: 'Visible par les patients pour les séances en cabinet',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: specialtyController,
              decoration: const InputDecoration(
                labelText: 'Spécialité',
                hintText: 'Ex : Psychologie clinique, TCC…',
                prefixIcon: Icon(Icons.medical_information_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La spécialité est requise';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: yearsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Années d'expérience",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prix consultation (FCFA)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: licenseNumberController,
              decoration: const InputDecoration(
                labelText: 'Numéro de licence (optionnel)',
                hintText: "Numéro d'agrément / carte professionnelle",
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Justificatif (diplôme ou carte professionnelle) *',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              "Requis pour que l'administrateur puisse valider votre compte. "
              "Sans approbation, votre profil n'est pas visible des "
              'patients et vous ne pouvez recevoir aucun rendez-vous.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onPickLicenseDocument,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                licenseDocumentName ?? 'Choisir un fichier (PDF, JPG, PNG)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (licenseDocumentError != null) ...[
              const SizedBox(height: 6),
              Text(
                licenseDocumentError!,
                style: const TextStyle(color: AppColors.rose, fontSize: 12),
              ),
            ],
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Créer mon compte'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading ? null : onBack,
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}
