// correspond a UserAdminResponse du backend (GET /admin/users).
// c'est le compte brut (un par user, peu importe le role), different de
// PatientProfile/PsychologistProfile qui eux ont le nom/ville/etc
class UserAccount {
  final int id;
  final String email;
  final String pseudo;
  final String firstName;
  final String lastName;
  final String role;
  final bool enabled;
  final DateTime createdAt;

  UserAccount({
    required this.id,
    required this.email,
    required this.pseudo,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.enabled,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String? ?? '',
        pseudo: json['pseudo'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        role: json['role'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

// correspond a AdminStatsResponse cote auth-service (GET /admin/stats/accounts)
class AdminAccountStats {
  final int totalUsers;
  final int totalPatients;
  final int totalPsychologists;
  final int totalAdmins;
  final int enabledUsers;
  final int disabledUsers;

  AdminAccountStats({
    required this.totalUsers,
    required this.totalPatients,
    required this.totalPsychologists,
    required this.totalAdmins,
    required this.enabledUsers,
    required this.disabledUsers,
  });

  factory AdminAccountStats.fromJson(Map<String, dynamic> json) =>
      AdminAccountStats(
        totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
        totalPatients: (json['totalPatients'] as num?)?.toInt() ?? 0,
        totalPsychologists: (json['totalPsychologists'] as num?)?.toInt() ?? 0,
        totalAdmins: (json['totalAdmins'] as num?)?.toInt() ?? 0,
        enabledUsers: (json['enabledUsers'] as num?)?.toInt() ?? 0,
        disabledUsers: (json['disabledUsers'] as num?)?.toInt() ?? 0,
      );
}

// correspond a AdminStatsResponse cote user-service (GET /admin/stats/profiles)
class AdminProfileStats {
  final int totalPatients;
  final int totalPsychologists;
  final int verifiedPsychologists;
  final int pendingPsychologists;
  final int rejectedPsychologists;

  AdminProfileStats({
    required this.totalPatients,
    required this.totalPsychologists,
    required this.verifiedPsychologists,
    required this.pendingPsychologists,
    this.rejectedPsychologists = 0,
  });

  factory AdminProfileStats.fromJson(Map<String, dynamic> json) =>
      AdminProfileStats(
        totalPatients: (json['totalPatients'] as num?)?.toInt() ?? 0,
        totalPsychologists: (json['totalPsychologists'] as num?)?.toInt() ?? 0,
        verifiedPsychologists:
            (json['verifiedPsychologists'] as num?)?.toInt() ?? 0,
        pendingPsychologists:
            (json['pendingPsychologists'] as num?)?.toInt() ?? 0,
        rejectedPsychologists:
            (json['rejectedPsychologists'] as num?)?.toInt() ?? 0,
      );
}

// fusion de AdminStatsResponse cote appointment-service (GET
// /admin/stats/appointments) et PaymentAdminStatsResponse cote
// payment-service (GET /admin/stats/payments), assemblee par AdminService
class AdminAppointmentStats {
  final int totalAppointments;
  final int pendingAppointments;
  final int confirmedAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final int rejectedAppointments;
  final int totalPayments;
  final int completedPayments;
  final double totalRevenue;
  // part de revenus de l'admin, le taux peut changer depuis l'onglet Config
  // c'est pas fixe en dur, ces 3 champs montrent le taux actuel du backend
  final double commissionRatePercent;
  final double platformRevenue;
  final double psychologistRevenue;

  AdminAppointmentStats({
    required this.totalAppointments,
    required this.pendingAppointments,
    required this.confirmedAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.rejectedAppointments,
    required this.totalPayments,
    required this.completedPayments,
    required this.totalRevenue,
    this.commissionRatePercent = 0,
    this.platformRevenue = 0,
    this.psychologistRevenue = 0,
  });

  factory AdminAppointmentStats.fromJson(Map<String, dynamic> json) =>
      AdminAppointmentStats(
        totalAppointments: (json['totalAppointments'] as num?)?.toInt() ?? 0,
        pendingAppointments:
            (json['pendingAppointments'] as num?)?.toInt() ?? 0,
        confirmedAppointments:
            (json['confirmedAppointments'] as num?)?.toInt() ?? 0,
        completedAppointments:
            (json['completedAppointments'] as num?)?.toInt() ?? 0,
        cancelledAppointments:
            (json['cancelledAppointments'] as num?)?.toInt() ?? 0,
        rejectedAppointments:
            (json['rejectedAppointments'] as num?)?.toInt() ?? 0,
        totalPayments: (json['totalPayments'] as num?)?.toInt() ?? 0,
        completedPayments: (json['completedPayments'] as num?)?.toInt() ?? 0,
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
        commissionRatePercent:
            (json['commissionRatePercent'] as num?)?.toDouble() ?? 0,
        platformRevenue: (json['platformRevenue'] as num?)?.toDouble() ?? 0,
        psychologistRevenue:
            (json['psychologistRevenue'] as num?)?.toDouble() ?? 0,
      );
}

// correspond a PlatformSettingsResponse cote appointment-service
// (GET/PUT /admin/platform-settings)
class PlatformSettings {
  final double commissionRatePercent;

  PlatformSettings({required this.commissionRatePercent});

  factory PlatformSettings.fromJson(Map<String, dynamic> json) =>
      PlatformSettings(
        commissionRatePercent:
            (json['commissionRatePercent'] as num?)?.toDouble() ?? 0,
      );
}

// reflete l'enum PaymentStatus de payment-service
enum PaymentStatus { pending, completed, failed, refunded }

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'En attente';
      case PaymentStatus.completed:
        return 'Réussi';
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
        return PaymentStatus.pending;
    }
  }
}

// reflete l'enum PaymentMethod de payment-service — tous simules, pas
// de vraie integration Orange Money/Wave/carte
enum PaymentMethod { orangeMoney, wave, card }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.orangeMoney:
        return 'Orange Money';
      case PaymentMethod.wave:
        return 'Wave';
      case PaymentMethod.card:
        return 'Carte bancaire';
    }
  }

  static PaymentMethod fromApiValue(String value) {
    switch (value.toUpperCase()) {
      case 'SIMULATED_ORANGE_MONEY':
        return PaymentMethod.orangeMoney;
      case 'SIMULATED_WAVE':
        return PaymentMethod.wave;
      case 'SIMULATED_CARD':
        return PaymentMethod.card;
      default:
        return PaymentMethod.card;
    }
  }
}

// correspond a PaymentResponse cote payment-service (GET /admin/payments)
class Payment {
  final int id;
  final int appointmentId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? transactionReference;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.appointmentId,
    required this.amount,
    required this.method,
    required this.status,
    this.transactionReference,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: (json['id'] as num).toInt(),
        appointmentId: (json['appointmentId'] as num).toInt(),
        amount: (json['amount'] as num).toDouble(),
        method: PaymentMethodX.fromApiValue(json['method'] as String),
        status: PaymentStatusX.fromApiValue(json['status'] as String),
        transactionReference: json['transactionReference'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
