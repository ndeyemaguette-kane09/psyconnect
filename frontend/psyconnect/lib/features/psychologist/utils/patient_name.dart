import '../../auth/models/profile_models.dart';

String patientDisplayName(PatientProfile? p) {
  if (p == null) return 'Patient';
  final name = '${p.firstName} ${p.lastName}'.trim();
  if (p.anonymousMode) {
    if (name.isEmpty || name == 'Patient anonyme') return 'Patient anonyme';
    return '« $name »';
  }
  return name.isEmpty ? 'Patient' : name;
}
