import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/payment_models.dart';

// paiement simulé : débite le solde PsyConnect, pas de vrai opérateur derrière
// le RDV doit déjà être confirmé, et le backend refuse un double paiement
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

  // revenu net du psy (apres commission), total et mois en cours
  Future<PsychologistRevenue> getPsychologistRevenue(
    int psychologistId,
  ) async {
    final json =
        await _api.get(ApiConstants.psychologistRevenue(psychologistId));
    return PsychologistRevenue.fromJson(json as Map<String, dynamic>);
  }

  // portefeuille du psy : solde disponible + historique des retraits
  Future<PsychologistWallet> getPsychologistWallet(int psychologistId) async {
    final json =
        await _api.get(ApiConstants.psychologistWallet(psychologistId));
    return PsychologistWallet.fromJson(json as Map<String, dynamic>);
  }

  // historique détaillé des paiements reçus par le psy
  Future<List<PaymentTransaction>> getTransactionsByPsychologistId(
    int psychologistId,
  ) async {
    final json = await _api.get(
      ApiConstants.psychologistTransactions(psychologistId),
    );
    return (json as List)
        .map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // retrait simulé : amount en FCFA, method = apiValue de WithdrawalMethod
  Future<PsychologistWithdrawal> withdraw({
    required int psychologistId,
    required double amount,
    required WithdrawalMethod method,
  }) async {
    final json = await _api.post(
      '${ApiConstants.psychologistWithdraw(psychologistId)}'
      '?amount=$amount&method=${method.apiValue}',
      body: {},
    );
    return PsychologistWithdrawal.fromJson(json as Map<String, dynamic>);
  }
}
