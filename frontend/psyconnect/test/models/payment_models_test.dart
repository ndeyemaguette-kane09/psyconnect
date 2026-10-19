import 'package:flutter_test/flutter_test.dart';
import 'package:psyconnect/features/payment/models/payment_models.dart';

const nbsp = ' ';

void main() {
  group('formatAmount', () {
    test('laisse un petit montant tel quel', () {
      expect(formatAmount(0), '0');
      expect(formatAmount(999), '999');
    });

    test('sépare les milliers avec une espace insécable', () {
      expect(formatAmount(15000), '15${nbsp}000');
      expect(formatAmount(1000000), '1${nbsp}000${nbsp}000');
    });

    test('garde le signe moins pour un débit', () {
      expect(formatAmount(-2500), '-2${nbsp}500');
    });

    test('affiche les décimales avec une virgule', () {
      expect(formatAmount(1234.5), '1${nbsp}234,50');
    });

    test('traite un double entier comme un entier', () {
      expect(formatAmount(5000.0), '5${nbsp}000');
    });
  });

  group('PaymentStatusX.fromApiValue', () {
    test('reconnaît chaque statut du backend', () {
      expect(PaymentStatusX.fromApiValue('PENDING'), PaymentStatus.pending);
      expect(PaymentStatusX.fromApiValue('COMPLETED'), PaymentStatus.completed);
      expect(PaymentStatusX.fromApiValue('FAILED'), PaymentStatus.failed);
      expect(PaymentStatusX.fromApiValue('REFUNDED'), PaymentStatus.refunded);
    });

    test('ignore la casse', () {
      expect(PaymentStatusX.fromApiValue('refunded'), PaymentStatus.refunded);
    });

    test('rejette un statut inconnu', () {
      expect(() => PaymentStatusX.fromApiValue('LOST'), throwsArgumentError);
    });
  });

  group('CreatePaymentRequest.toJson', () {
    test('envoie la valeur attendue par payment-service', () {
      final json = CreatePaymentRequest(
        appointmentId: 12,
        amount: 15000,
        method: PaymentMethod.wallet,
      ).toJson();

      expect(json, {
        'appointmentId': 12,
        'amount': 15000,
        'method': 'WALLET',
      });
    });

    test('marque les moyens mobile money comme simulés', () {
      expect(PaymentMethod.wave.apiValue, 'SIMULATED_WAVE');
      expect(PaymentMethod.orangeMoney.apiValue, 'SIMULATED_ORANGE_MONEY');
      expect(PaymentMethod.card.apiValue, 'SIMULATED_CARD');
    });
  });

  group('Payment.fromJson', () {
    Map<String, dynamic> paymentJson({String? method}) => {
          'id': 3,
          'appointmentId': 12,
          'amount': 15000,
          'method': method,
          'status': 'COMPLETED',
          'transactionReference': 'TX-42',
          'createdAt': '2026-09-01T10:00:00',
        };

    test('lit un paiement par le solde', () {
      final payment = Payment.fromJson(paymentJson(method: 'WALLET'));

      expect(payment.id, 3);
      expect(payment.appointmentId, 12);
      expect(payment.amount, 15000);
      expect(payment.method, PaymentMethod.wallet);
      expect(payment.status, PaymentStatus.completed);
      expect(payment.transactionReference, 'TX-42');
      expect(payment.createdAt, DateTime(2026, 9, 1, 10));
    });

    test('ne plante pas sur une méthode absente ou inconnue', () {
      expect(Payment.fromJson(paymentJson()).method, isNull);
      expect(Payment.fromJson(paymentJson(method: 'PAYPAL')).method, isNull);
    });
  });

  group('PsychologistWallet.fromJson', () {
    test('met des zéros quand le psy n\'a encore rien gagné', () {
      final wallet = PsychologistWallet.fromJson({});

      expect(wallet.availableBalance, 0);
      expect(wallet.totalNetRevenue, 0);
      expect(wallet.totalWithdrawn, 0);
      expect(wallet.commissionRatePercent, 0);
      expect(wallet.withdrawals, isEmpty);
    });

    test('lit le solde et la liste des retraits', () {
      final wallet = PsychologistWallet.fromJson({
        'availableBalance': 42500,
        'totalNetRevenue': 85000,
        'totalWithdrawn': 42500,
        'commissionRatePercent': 15,
        'withdrawals': [
          {
            'id': 1,
            'psychologistId': 7,
            'amount': 42500,
            'method': 'WAVE',
            'status': 'COMPLETED',
            'createdAt': '2026-08-30T18:00:00',
          },
        ],
      });

      expect(wallet.availableBalance, 42500.0);
      expect(wallet.commissionRatePercent, 15.0);
      expect(wallet.withdrawals, hasLength(1));
      expect(wallet.withdrawals.first.method, 'WAVE');
      expect(wallet.withdrawals.first.amount, 42500.0);
    });
  });

  group('PaymentTransaction.fromJson', () {
    test('lit une transaction remboursée sans date de séance', () {
      final tx = PaymentTransaction.fromJson({
        'paymentId': 9,
        'appointmentId': 12,
        'grossAmount': 15000,
        'netAmount': 12750,
        'commissionAmount': 2250,
        'status': 'REFUNDED',
        'transactionReference': 'TX-9',
        'paidAt': '2026-09-02T09:30:00',
      });

      expect(tx.patientId, isNull);
      expect(tx.appointmentStartTime, isNull);
      expect(tx.status, PaymentStatus.refunded);
      expect(tx.grossAmount - tx.commissionAmount, tx.netAmount);
    });
  });
}
