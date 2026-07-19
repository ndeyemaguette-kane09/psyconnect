import 'payment_models.dart';

// solde actuel du patient (cf WalletResponse cote user-service)
class Wallet {
  final int patientId;
  final double balance;

  Wallet({required this.patientId, required this.balance});

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        patientId: (json['patientId'] as num).toInt(),
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );
}

// corps pour /wallet/deposit et /wallet/withdraw. method = un des 3 moyens
// simulés (Wave/Orange Money/Carte), jamais wallet vu que c'est
// justement ça qu'on est en train de faire
class WalletAmountRequest {
  final double amount;
  final PaymentMethod method;

  WalletAmountRequest({required this.amount, required this.method});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'method': method.label,
      };
}

// reflete l'enum WalletTransactionType cote user-service
enum WalletTransactionType { deposit, withdrawal, debit, credit }

extension WalletTransactionTypeX on WalletTransactionType {
  // true si le mouvement a fait monter le solde (depot, remboursement)
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

// une ligne du relevé du solde (GET /patients/{id}/wallet/transactions)
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
