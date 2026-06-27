// Reflète l'enum `PaymentMethod` de appointment-service
// (backend/appointment-service/.../entity/PaymentMethod.java). Les trois
// valeurs SIMULATED_* sont préfixées ainsi côté backend : aucune
// intégration réelle avec un opérateur de paiement. Elles ne servent plus
// qu'à qualifier un dépôt/retrait sur le solde (cf. WalletScreen) —
// [wallet] est le seul moyen utilisé pour payer un rendez-vous (cf.
// PaymentServiceImpl.createPayment, qui force ce moyen côté backend).
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

/// Reflète l'enum `PaymentStatus` de appointment-service. En pratique,
/// côté simulation, un paiement créé est toujours `completed` (cf. backend) —
/// les autres valeurs existent pour la complétude du modèle.
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

/// Correspond à CreatePaymentRequest côté appointment-service
/// (POST /payments).
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

/// Correspond à PaymentResponse côté appointment-service.
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

// Reflète PsychologistRevenueResponse côté appointment-service (GET
// /payments/psychologist/{id}/revenue) : revenu NET (après commission)
// du psychologue, total et sur le mois en cours.
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
