/// Adresses de l'API Gateway (Spring Cloud Gateway, cf. backend/api-gateway).
///
/// L'app passe TOUJOURS par le gateway (port 8080), jamais directement par
/// un microservice : c'est lui qui route /auth, /users, /patients,
/// /psychologists, /appointments, /payments, /journal, /notifications
/// vers le bon service via Eureka.
///
/// La bonne valeur de [baseUrl] dépend de l'endroit où tourne l'app :
/// - Web / Flutter desktop (macOS, etc.) : http://localhost:8080
/// - Émulateur Android : http://10.0.2.2:8080 (10.0.2.2 = host machine)
/// - Simulateur iOS : http://localhost:8080
/// - Appareil physique : le nom mDNS/Bonjour de la machine de dev
///   (`MacBook-Pro-de-ndeye.local`, obtenu via `scutil --get LocalHostName`)
///   plutôt que son IP locale, qui change à chaque reconnexion Wi-Fi.
///   C'est la valeur par défaut ci-dessous : `flutter run` seul (sans flag)
///   fonctionne donc directement sur device physique, tant que le téléphone
///   et le Mac sont sur le même réseau et que le nom de la machine ne change
///   pas (renommage via Réglages Système > Général > Partage si besoin).
///
/// On peut quand même surcharger cette valeur au lancement, par exemple
/// pour un émulateur Android ou si le mDNS ne résout pas sur un réseau
/// particulier (Wi-Fi d'entreprise/invité) :
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://MacBook-Pro-de-ndeye.local:8080',
  );

  // --- auth-service (routé via /auth/**) ---
  static const String registerPatient = '/auth/register/patient';
  static const String registerPsychologist = '/auth/register/psy';
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // --- user-service (routé via /users/**, /patients/**, /psychologists/**) ---
  static const String userProfiles = '/users';
  static const String patientProfiles = '/patients';
  static const String psychologistProfiles = '/psychologists';

  static String userProfileByAuthUser(int authUserId) =>
      '/users/by-auth-user/$authUserId';

  static String patientProfileByAuthUser(int authUserId) =>
      '/patients/by-auth-user/$authUserId';

  static String psychologistProfileByAuthUser(int authUserId) =>
      '/psychologists/by-auth-user/$authUserId';

  /// POST (multipart, champ "file") pour envoyer/remplacer le justificatif,
  /// GET pour le télécharger (réservé au propriétaire ou à un ADMIN — cf.
  /// SecurityConfig côté user-service).
  static String psychologistLicenseDocument(int psychologistId) =>
      '/psychologists/$psychologistId/license-document';

  // Solde PsyConnect : GET pour lire le solde, POST deposit/withdraw pour
  // recharger/retirer (corps JSON {amount, method}). /debit et /credit
  // existent côté backend mais réservés aux appels inter-services.
  static String patientWallet(int patientId) => '/patients/$patientId/wallet';

  static String patientWalletDeposit(int patientId) =>
      '/patients/$patientId/wallet/deposit';

  static String patientWalletWithdraw(int patientId) =>
      '/patients/$patientId/wallet/withdraw';

  /// GET : relevé des mouvements du solde (dépôts/retraits/débits/crédits),
  /// du plus récent au plus ancien.
  static String patientWalletTransactions(int patientId) =>
      '/patients/$patientId/wallet/transactions';

  // --- ml-service (routé via /recommendations/**, route fixe vers
  // l'instance uvicorn — service Python non enregistré dans Eureka, cf.
  // ml-service-route dans api-gateway/application.properties) ---
  /// GET /recommendations/{patientId}?top_n=N : recommandation par
  /// filtrage de contenu (TF-IDF + similarité cosinus) + note, cf.
  /// ml-service/app/main.py. Le jeton JWT du patient est relayé tel quel
  /// par [ApiClient] (withAuth: true par défaut) car ml-service en a
  /// besoin pour appeler GET /patients/{id} côté user-service.
  static String recommendations(int patientId, {int topN = 5}) =>
      '/recommendations/$patientId?top_n=$topN';

  // --- appointment-service (routé via /appointments/**) ---
  static const String appointments = '/appointments';

  static String appointmentsByPatient(int patientId) =>
      '/appointments/patient/$patientId';

  static String appointmentsByPsychologist(int psychologistId) =>
      '/appointments/psychologist/$psychologistId';

  /// `status` est passé en query param côté backend (pas de body JSON) :
  /// PUT /appointments/{id}/status?status=CONFIRMED|REJECTED|...
  static String appointmentStatus(int appointmentId, String status) =>
      '/appointments/$appointmentId/status?status=$status';

  // GET /payments/psychologist/{id}/revenue : revenu net (après commission)
  // d'un psychologue, total + mois en cours.
  static String psychologistRevenue(int psychologistId) =>
      '/payments/psychologist/$psychologistId/revenue';

  /// PUT /appointments/{id}/reschedule — corps JSON
  /// {newStartTime, newEndTime}. Réservé au patient propriétaire ; un RDV
  /// déjà CONFIRMED repasse en PENDING côté backend (le psychologue doit
  /// reconfirmer le nouveau créneau).
  static String appointmentReschedule(int appointmentId) =>
      '/appointments/$appointmentId/reschedule';

  // DELETE /appointments/{id} — réservé aux RDV ANNULÉ/REFUSÉ, par le
  // patient propriétaire.
  static String appointmentById(int appointmentId) =>
      '/appointments/$appointmentId';

  // --- journal privé (routé via /journal/**, implémenté dans user-service
  // — cf. journal-route dans api-gateway/application.properties).
  // L'identité du patient est résolue côté backend depuis le JWT (pas de
  // patientId dans l'URL ni dans le corps) : chaque utilisateur ne voit que
  // ses propres entrées. ---
  static const String journalEntries = '/journal';

  static String journalEntry(int entryId) => '/journal/$entryId';

  // --- session de consultation simulée (routé via /sessions/**, implémenté
  // dans appointment-service) ---
  static const String sessionsStart = '/sessions/start';

  static String sessionEnd(int sessionId) => '/sessions/$sessionId/end';

  static String sessionById(int sessionId) => '/sessions/$sessionId';

  static String sessionByAppointment(int appointmentId) =>
      '/sessions/appointment/$appointmentId';

  // --- paiement (routé via /payments/**, implémenté dans
  // appointment-service — cf. routes[3] dans
  // api-gateway/application.properties) ---
  static const String payments = '/payments';

  static String paymentsByAppointment(int appointmentId) =>
      '/payments/appointment/$appointmentId';

  // --- notification-service (routé via /notifications/**) ---
  /// `userId` ici correspond en réalité au PatientProfile.id (pas
  /// l'authUserId) — vérifié dans NotificationServiceImpl/OwnershipResolver
  /// côté backend.
  static String notificationsByUser(int patientId) =>
      '/notifications/user/$patientId';

  static String notificationRead(int notificationId) =>
      '/notifications/$notificationId/read';

  // --- admin (réservé ROLE_ADMIN, routé vers auth/user/appointment-service
  // selon le préfixe — cf. api-gateway/application.properties routes
  // admin-auth-route / admin-user-route / admin-appointment-route) ---
  static const String adminUsers = '/admin/users';
  static const String adminPsychologists = '/admin/psychologists';
  static const String adminPatients = '/admin/patients';
  static const String adminAppointments = '/admin/appointments';
  static const String adminPayments = '/admin/payments';

  /// GET /admin/appointments?status= — filtre déjà géré côté backend
  /// (AppointmentServiceImpl#getAllAppointmentsForAdmin), contrairement à
  /// /admin/payments qui n'a pas d'équivalent (filtrage payments fait
  /// côté client).
  static String adminAppointmentsByStatus(String? status) =>
      status == null ? adminAppointments : '/admin/appointments?status=$status';

  /// Chaque service a son propre /admin/stats/* (renommé pour éviter une
  /// collision de chemin entre les 3 services, cf. AdminController.java).
  static const String adminStatsAccounts = '/admin/stats/accounts';
  static const String adminStatsProfiles = '/admin/stats/profiles';
  static const String adminStatsAppointments = '/admin/stats/appointments';

  static String adminSetUserEnabled(int userId, bool enabled) =>
      '/admin/users/$userId/enabled?enabled=$enabled';

  /// DELETE /admin/users/{id} — suppression définitive (irréversible).
  static String adminDeleteUser(int userId) => '/admin/users/$userId';

  /// PATCH /admin/users/{id}/password — reset forcé par l'admin, mot de
  /// passe transmis en corps JSON (jamais en query string).
  static String adminResetPassword(int userId) =>
      '/admin/users/$userId/password';

  static String adminSetPsychologistVerified(int psychologistId, bool verified) =>
      '/admin/psychologists/$psychologistId/verify?verified=$verified';

  /// Distinct de [adminSetPsychologistVerified] : refuse explicitement une
  /// demande (ou la remet en attente avec rejected=false). Nécessaire car
  /// `verify?verified=false` est un no-op sur un profil déjà en attente.
  static String adminSetPsychologistRejected(int psychologistId, bool rejected) =>
      '/admin/psychologists/$psychologistId/reject?rejected=$rejected';

  /// GET /admin/platform-settings (appointment-service) : taux de
  /// commission courant de la plateforme.
  static const String adminPlatformSettings = '/admin/platform-settings';

  /// PUT /admin/platform-settings/commission-rate?commissionRatePercent=N
  static String adminSetCommissionRate(double commissionRatePercent) =>
      '/admin/platform-settings/commission-rate?commissionRatePercent=$commissionRatePercent';

  // --- messagerie patient/psychologue (routé via /messages/**, implémentée
  // dans appointment-service — cf. messaging-route dans
  // api-gateway/application.properties) ---
  static const String messagesConversations = '/messages/conversations';

  static String messagesConversationMessages(int conversationId) =>
      '/messages/conversations/$conversationId/messages';

  static String messagesConversationRead(int conversationId) =>
      '/messages/conversations/$conversationId/read';

  static const Duration timeout = Duration(seconds: 15);
}
