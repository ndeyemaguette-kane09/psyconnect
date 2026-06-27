import 'payment_models.dart';

// Reflète WalletResponse côté user-service (GET/POST /patients/{id}/wallet*) :
// solde courant du patient.
class Wallet {
  final int patientId;
  final double balance;

  Wallet({required this.patientId, required this.balance});

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        patientId: (json['patientId'] as num).toInt(),
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );
}

/// Corps de requête pour /wallet/deposit et /wallet/withdraw — reflète
/// WalletAmountRequest côté user-service. `method` reste un des 3 moyens
/// mobile money simulés (Wave/Orange Money/Carte), jamais [PaymentMethod.wallet]
/// lui-même puisque c'est précisément l'opération qu'on décrit.
class WalletAmountRequest {
  final double amount;
  final PaymentMethod method;

  WalletAmountRequest({required this.amount, required this.method});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'method': method.label,
      };
}

/// Reflète l'enum `WalletTransactionType` côté user-service.
enum WalletTransactionType { deposit, withdrawal, debit, credit }

extension WalletTransactionTypeX on WalletTransactionType {
  /// true si ce mouvement a augmenté le solde (dépôt, remboursement).
  bool get isCredit =>
      this == WalletTransactionType.deposit || this == WalletTransactionType.credit;

  String get label {
    switch (this) {
      case WalletTransactionType.deposit:
        return 'Recharge';
      case WalletTransactionType.withdrawal:
        return 'Retrait';
      case WalletTransactionType.debit:
        return 'Paiement de rendez-vous';
      case WalletTransactionType.credit:
        return 'Remboursement';
    }
  }

  static WalletTransactionType fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'DEPOSIT':
        return WalletTransactionType.deposit;
      case 'WITHDRAWAL':
        return WalletTransactionType.withdrawal;
      case 'DEBIT':
        return WalletTransactionType.debit;
      case 'CREDIT':
        return WalletTransactionType.credit;
      default:
        throw ArgumentError('Type de mouvement de solde inconnu: $value');
    }
  }
}

// Reflète WalletTransactionResponse côté user-service
// (GET /patients/{id}/wallet/transactions) : une ligne du relevé du solde.
class WalletTransaction {
  final int id;
  final WalletTransactionType type;
  final double amount;
  final double balanceAfter;
  final String? method;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.method,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: (json['id'] as num).toInt(),
        type: WalletTransactionTypeX.fromApiValue(json['type'] as String),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0,
        method: json['method'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
