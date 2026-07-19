import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/wallet_models.dart';

// appelle les endpoints du solde :
// GET /patients/{id}/wallet, POST .../wallet/deposit, .../wallet/withdraw.
// /debit et /credit existent côté backend mais c'est juste pour les
// appels entre services — jamais utilisés ici.
class WalletService {
  WalletService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Wallet> getWallet(int patientId) async {
    final json = await _api.get(ApiConstants.patientWallet(patientId));
    return Wallet.fromJson(json as Map<String, dynamic>);
  }

  Future<Wallet> deposit(int patientId, WalletAmountRequest request) async {
    final json = await _api.post(
      ApiConstants.patientWalletDeposit(patientId),
      body: request.toJson(),
    );
    return Wallet.fromJson(json as Map<String, dynamic>);
  }

  Future<Wallet> withdraw(int patientId, WalletAmountRequest request) async {
    final json = await _api.post(
      ApiConstants.patientWalletWithdraw(patientId),
      body: request.toJson(),
    );
    return Wallet.fromJson(json as Map<String, dynamic>);
  }

  Future<List<WalletTransaction>> getTransactions(int patientId) async {
    final json = await _api.get(ApiConstants.patientWalletTransactions(patientId));
    return (json as List)
        .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
