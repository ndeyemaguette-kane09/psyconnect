String formatAmount(num value) {
  final whole = value == value.roundToDouble();
  final text = whole
      ? value.round().abs().toString()
      : value.abs().toStringAsFixed(2);
  final parts = text.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u00A0');
    buffer.write(digits[i]);
  }
  final sign = value < 0 ? '-' : '';
  return parts.length > 1 ? '$sign$buffer,${parts[1]}' : '$sign$buffer';
}

// les 3 valeurs SIMULATED_* sont juste pour faire semblant, y'a pas
// de vrai operateur derriere. ca sert a marquer un depot/retrait
// sur le solde (cf WalletScreen) — payer un RDV ça passe que par le wallet
enum PaymentMethod { orangeMoney, wave, card, wallet }

extension PaymentMethodX on PaymentMethod {
  String get apiValue {
    switch (this) {
      case PaymentMethod.orangeMoney:
        return 'SIMULATED_ORANGE_MONEY';
      case PaymentMethod.wave:
        return 'SIMULATED_WAVE';
      case PaymentMethod.card:
        return 'SIMULATED_CARD';
      case PaymentMethod.wallet:
        return 'WALLET';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.orangeMoney:
        return 'Orange Money';
      case PaymentMethod.wave:
        return 'Wave';
      case PaymentMethod.card:
        return 'Carte bancaire';
      case PaymentMethod.wallet:
        return 'Solde PsyConnect';
    }
  }
}

// en pratique un paiement cree est toujours completed (c'est simule), les
// autres valeurs sont juste là pour pas qu'il manque un cas
enum PaymentStatus { pending, completed, failed, refunded }

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'En attente';
      case PaymentStatus.completed:
        return 'Payé';
      case PaymentStatus.failed:
        return 'Échoué';
      case PaymentStatus.refunded:
        return 'Remboursé';
    }
  }

  static PaymentStatus fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return PaymentStatus.pending;
      case 'COMPLETED':
        return PaymentStatus.completed;
      case 'FAILED':
        return PaymentStatus.failed;
      case 'REFUNDED':
        return PaymentStatus.refunded;
      default:
        throw ArgumentError('Statut de paiement inconnu: $value');
    }
  }
}

// correspond a CreatePaymentRequest du backend (POST /payments)
class CreatePaymentRequest {
  final int appointmentId;
  final int amount;
  final PaymentMethod method;

  CreatePaymentRequest({
    required this.appointmentId,
    required this.amount,
    required this.method,
  });

  Map<String, dynamic> toJson() => {
        'appointmentId': appointmentId,
        'amount': amount,
        'method': method.apiValue,
      };
}

// correspond a PaymentResponse du backend
class Payment {
  final int id;
  final int appointmentId;
  final int amount;
  final PaymentMethod? method;
  final PaymentStatus status;
  final String transactionReference;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.appointmentId,
    required this.amount,
    required this.method,
    required this.status,
    required this.transactionReference,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: (json['id'] as num).toInt(),
        appointmentId: (json['appointmentId'] as num).toInt(),
        amount: (json['amount'] as num).toInt(),
        method: _methodFromApiValue(json['method'] as String?),
        status: PaymentStatusX.fromApiValue(json['status'] as String),
        transactionReference: json['transactionReference'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static PaymentMethod? _methodFromApiValue(String? value) {
    switch (value) {
      case 'SIMULATED_ORANGE_MONEY':
        return PaymentMethod.orangeMoney;
      case 'SIMULATED_WAVE':
        return PaymentMethod.wave;
      case 'SIMULATED_CARD':
        return PaymentMethod.card;
      case 'WALLET':
        return PaymentMethod.wallet;
      default:
        return null;
    }
  }
}

// enum des methodes de retrait disponibles pour le psy
enum WithdrawalMethod { orangeMoney, wave, bankTransfer }

extension WithdrawalMethodX on WithdrawalMethod {
  String get apiValue {
    switch (this) {
      case WithdrawalMethod.orangeMoney:
        return 'ORANGE_MONEY';
      case WithdrawalMethod.wave:
        return 'WAVE';
      case WithdrawalMethod.bankTransfer:
        return 'BANK_TRANSFER';
    }
  }

  String get label {
    switch (this) {
      case WithdrawalMethod.orangeMoney:
        return 'Orange Money';
      case WithdrawalMethod.wave:
        return 'Wave';
      case WithdrawalMethod.bankTransfer:
        return 'Virement bancaire';
    }
  }
}

// un retrait simule (GET /wallet -> withdrawals[])
class PsychologistWithdrawal {
  final int id;
  final int psychologistId;
  final double amount;
  final String method;
  final String status;
  final DateTime createdAt;

  PsychologistWithdrawal({
    required this.id,
    required this.psychologistId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
  });

  factory PsychologistWithdrawal.fromJson(Map<String, dynamic> json) =>
      PsychologistWithdrawal(
        id: (json['id'] as num).toInt(),
        psychologistId: (json['psychologistId'] as num).toInt(),
        amount: (json['amount'] as num).toDouble(),
        method: json['method'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

// portefeuille du psy : GET /payments/psychologist/{id}/wallet
class PsychologistWallet {
  final double availableBalance;
  final double totalNetRevenue;
  final double totalWithdrawn;
  final double commissionRatePercent;
  final List<PsychologistWithdrawal> withdrawals;

  PsychologistWallet({
    required this.availableBalance,
    required this.totalNetRevenue,
    required this.totalWithdrawn,
    required this.commissionRatePercent,
    required this.withdrawals,
  });

  factory PsychologistWallet.fromJson(Map<String, dynamic> json) =>
      PsychologistWallet(
        availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0,
        totalNetRevenue: (json['totalNetRevenue'] as num?)?.toDouble() ?? 0,
        totalWithdrawn: (json['totalWithdrawn'] as num?)?.toDouble() ?? 0,
        commissionRatePercent:
            (json['commissionRatePercent'] as num?)?.toDouble() ?? 0,
        withdrawals: (json['withdrawals'] as List<dynamic>? ?? [])
            .map((e) =>
                PsychologistWithdrawal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// une ligne de l'historique détaillé des paiements reçus par le psy :
// GET /payments/psychologist/{id}/transactions
// le pseudo du patient est enrichi côté Flutter (appel séparé GET /patients/{id})
class PaymentTransaction {
  final int paymentId;
  final int appointmentId;
  final int? patientId;
  final DateTime? appointmentStartTime;
  final double grossAmount;
  final double netAmount;
  final double commissionAmount;
  final PaymentStatus status; // COMPLETED ou REFUNDED
  final String transactionReference;
  final DateTime paidAt;

  PaymentTransaction({
    required this.paymentId,
    required this.appointmentId,
    this.patientId,
    this.appointmentStartTime,
    required this.grossAmount,
    required this.netAmount,
    required this.commissionAmount,
    required this.status,
    required this.transactionReference,
    required this.paidAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) =>
      PaymentTransaction(
        paymentId: (json['paymentId'] as num).toInt(),
        appointmentId: (json['appointmentId'] as num).toInt(),
        patientId: (json['patientId'] as num?)?.toInt(),
        appointmentStartTime: json['appointmentStartTime'] != null
            ? DateTime.parse(json['appointmentStartTime'] as String)
            : null,
        grossAmount: (json['grossAmount'] as num).toDouble(),
        netAmount: (json['netAmount'] as num).toDouble(),
        commissionAmount: (json['commissionAmount'] as num).toDouble(),
        status: PaymentStatusX.fromApiValue(json['status'] as String),
        transactionReference: json['transactionReference'] as String,
        paidAt: DateTime.parse(json['paidAt'] as String),
      );
}

// revenu net du psy (apres commission), total et mois en cours
class PsychologistRevenue {
  final double commissionRatePercent;
  final double totalGrossRevenue;
  final double totalNetRevenue;
  final double currentMonthGrossRevenue;
  final double currentMonthNetRevenue;

  PsychologistRevenue({
    required this.commissionRatePercent,
    required this.totalGrossRevenue,
    required this.totalNetRevenue,
    required this.currentMonthGrossRevenue,
    required this.currentMonthNetRevenue,
  });

  factory PsychologistRevenue.fromJson(Map<String, dynamic> json) =>
      PsychologistRevenue(
        commissionRatePercent:
            (json['commissionRatePercent'] as num?)?.toDouble() ?? 0,
        totalGrossRevenue: (json['totalGrossRevenue'] as num?)?.toDouble() ?? 0,
        totalNetRevenue: (json['totalNetRevenue'] as num?)?.toDouble() ?? 0,
        currentMonthGrossRevenue:
            (json['currentMonthGrossRevenue'] as num?)?.toDouble() ?? 0,
        currentMonthNetRevenue:
            (json['currentMonthNetRevenue'] as num?)?.toDouble() ?? 0,
      );
}
