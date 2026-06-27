import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/payment_models.dart';

/// Appelle les endpoints de appointment-service (via l'API Gateway) :
/// POST /payments, GET /payments/appointment/{id}.
///
/// Paiement simulé (cf. PaymentServiceImpl côté backend) : aucune
/// intégration réelle avec Orange Money/Wave/une banque, débité depuis le
/// solde PsyConnect du patient. Ne confirme PAS le rendez-vous : seul un
/// rendez-vous déjà CONFIRMED par le psychologue peut être payé, et le
/// backend rejette toute tentative de paiement en double pour un même
/// rendez-vous (déjà COMPLETED).
class PaymentService {
  PaymentService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Payment> createPayment(CreatePaymentRequest request) async {
    final json = await _api.post(
      ApiConstants.payments,
      body: request.toJson(),
    );
    return Payment.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Payment>> getPaymentsByAppointmentId(int appointmentId) async {
    final json =
        await _api.get(ApiConstants.paymentsByAppointment(appointmentId));
    return (json as List)
        .map((e) => Payment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Revenu net (après commission) d'un psychologue, total + mois en cours —
  /// cf. PaymentController#getPsychologistRevenue côté backend.
  Future<PsychologistRevenue> getPsychologistRevenue(
    int psychologistId,
  ) async {
    final json =
        await _api.get(ApiConstants.psychologistRevenue(psychologistId));
    return PsychologistRevenue.fromJson(json as Map<String, dynamic>);
  }
}
