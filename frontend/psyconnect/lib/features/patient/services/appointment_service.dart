import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/appointment_models.dart';

// appelle appointment-service pour les RDV
// partage entre patient et psy, pas envie de dupliquer ce fichier
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

  // confirme ou refuse un RDV
  // le statut part en query param, pas dans le corps
  Future<Appointment> updateAppointmentStatus(
    int appointmentId,
    AppointmentStatus status,
  ) async {
    final json = await _api.put(
      ApiConstants.appointmentStatus(appointmentId, status.apiValue),
    );
    return Appointment.fromJson(json as Map<String, dynamic>);
  }

  // reporte un RDV. s'il etait confirme, repasse en attente
  // le psy doit reconfirmer
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

  // supprime definitivement un RDV annule/refuse, rejette tout autre statut
  Future<void> deleteAppointment(int appointmentId) async {
    await _api.delete(ApiConstants.appointmentById(appointmentId));
  }
}
