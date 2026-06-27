import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/appointment_models.dart';

/// Appelle les endpoints de appointment-service (via l'API Gateway) :
/// POST /appointments, GET /appointments/patient/{id},
/// GET /appointments/psychologist/{id}, PUT /appointments/{id}/status.
///
/// Partagé entre le parcours patient et le parcours psychologue (qui vivent
/// dans des dossiers `features/` séparés) : pas de raison de dupliquer ce
/// client juste pour respecter la frontière de dossier.
class AppointmentService {
  AppointmentService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Appointment> createAppointment(
    CreateAppointmentRequest request,
  ) async {
    final json = await _api.post(
      ApiConstants.appointments,
      body: request.toJson(),
    );
    return Appointment.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Appointment>> getAppointmentsByPatientId(int patientId) async {
    final json =
        await _api.get(ApiConstants.appointmentsByPatient(patientId));
    return (json as List)
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Appointment>> getAppointmentsByPsychologistId(
    int psychologistId,
  ) async {
    final json =
        await _api.get(ApiConstants.appointmentsByPsychologist(psychologistId));
    return (json as List)
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Confirme ou refuse un RDV en attente (ou tout autre changement de
  /// statut valide). Le backend attend le statut en query param, pas en
  /// corps JSON — cf. ApiConstants.appointmentStatus.
  Future<Appointment> updateAppointmentStatus(
    int appointmentId,
    AppointmentStatus status,
  ) async {
    final json = await _api.put(
      ApiConstants.appointmentStatus(appointmentId, status.apiValue),
    );
    return Appointment.fromJson(json as Map<String, dynamic>);
  }

  /// Reporte un RDV encore modifiable (en attente ou confirmé) à un nouveau
  /// créneau. S'il était confirmé, le backend le repasse en attente : le
  /// psychologue doit reconfirmer le nouveau créneau.
  Future<Appointment> rescheduleAppointment(
    int appointmentId,
    RescheduleAppointmentRequest request,
  ) async {
    final json = await _api.put(
      ApiConstants.appointmentReschedule(appointmentId),
      body: request.toJson(),
    );
    return Appointment.fromJson(json as Map<String, dynamic>);
  }

  // Supprime définitivement un RDV ANNULÉ ou REFUSÉ. Le backend rejette
  // tout autre statut ou toute tentative par quelqu'un d'autre que le
  // patient propriétaire.
  Future<void> deleteAppointment(int appointmentId) async {
    await _api.delete(ApiConstants.appointmentById(appointmentId));
  }
}
