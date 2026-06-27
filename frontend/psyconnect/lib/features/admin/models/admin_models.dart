/// Correspond à UserAdminResponse côté auth-service (GET /admin/users).
/// C'est le compte d'authentification brut (un par utilisateur, quel que
/// soit son rôle) — distinct du PatientProfile/PsychologistProfile (qui,
/// eux, contiennent le nom/la ville/etc. côté user-service).
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

/// Correspond à AdminStatsResponse côté auth-service (GET /admin/stats/accounts).
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

/// Correspond à AdminStatsResponse côté user-service (GET /admin/stats/profiles).
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

/// Correspond à AdminStatsResponse côté appointment-service
/// (GET /admin/stats/appointments).
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
  // Part de revenus de l'administrateur — taux réglable depuis l'onglet
  // Config (cf. AdminService.setCommissionRate), pas figé en dur côté
  // frontend : ces 3 champs reflètent le taux courant côté backend.
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

/// Correspond à PlatformSettingsResponse côté appointment-service
/// (GET/PUT /admin/platform-settings).
class PlatformSettings {
  final double commissionRatePercent;

  PlatformSettings({required this.commissionRatePercent});

  factory PlatformSettings.fromJson(Map<String, dynamic> json) =>
      PlatformSettings(
        commissionRatePercent:
            (json['commissionRatePercent'] as num?)?.toDouble() ?? 0,
      );
}

/// Reflète l'enum `PaymentStatus` de appointment-service.
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

/// Reflète l'enum `PaymentMethod` de appointment-service — tous les moyens
/// sont simulés (pas de vraie intégration Orange Money/Wave/carte).
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

/// Correspond à PaymentResponse côté appointment-service (GET /admin/payments).
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
