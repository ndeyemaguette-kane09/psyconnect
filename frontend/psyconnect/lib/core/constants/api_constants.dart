// adresses du gateway (port 8080), on passe toujours par lui
//
// baseUrl change selon ou l'app tourne :
// - web/desktop/simu iOS : localhost:8080
// - emulateur android : 10.0.2.2:8080
// - telephone physique : nom du mac (plus stable que l'ip wifi)
// possible de changer avec : flutter run --dart-define=API_BASE_URL=...
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
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

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

  // POST pour envoyer/remplacer le justificatif, GET pour le telecharger
  static String psychologistLicenseDocument(int psychologistId) =>
      '/psychologists/$psychologistId/license-document';

  // GET solde, POST deposit/withdraw pour recharger/retirer
  static String patientWallet(int patientId) => '/patients/$patientId/wallet';

  static String patientWalletDeposit(int patientId) =>
      '/patients/$patientId/wallet/deposit';

  static String patientWalletWithdraw(int patientId) =>
      '/patients/$patientId/wallet/withdraw';

  // GET : liste des mouvements du solde, du plus recent au plus ancien
  static String patientWalletTransactions(int patientId) =>
      '/patients/$patientId/wallet/transactions';

  // GET public / PUT proprietaire : disponibilites hebdomadaires du psy
  static String psychologistAvailabilities(int psychologistId) =>
      '/psychologists/$psychologistId/availabilities';

  // --- lien de suivi psy ↔ patient (POST=ajouter, DELETE=retirer, GET=liste/statut) ---
  static String followedPatients(int psyId) =>
      '/psychologists/$psyId/followed-patients';

  static String followedPatient(int psyId, int patientId) =>
      '/psychologists/$psyId/followed-patients/$patientId';

  // GET/PUT : antecedents medicaux structures, editable patient + psy suivi
  static String patientMedicalHistory(int patientId) =>
      '/patients/$patientId/medical-history';

  // --- notes cliniques privees (psychologue uniquement, jamais le patient
  // ni l'admin - cf CDC section 6) ---
  static String patientClinicalNotes(int patientId) =>
      '/patients/$patientId/clinical-notes';
  static String clinicalNote(int noteId) => '/clinical-notes/$noteId';

  // --- avis psy (anonymes, reserves au patient ayant eu une seance
  // COMPLETED avec ce psy) ---
  // GET : liste publique et anonyme des avis
  static String psychologistReviews(int psychologistId) =>
      '/psychologists/$psychologistId/reviews';

  // PUT : cree ou met a jour l'avis du patient connecte (upsert)
  static String psychologistReview(int psychologistId) =>
      '/psychologists/$psychologistId/review';

  // GET : l'avis du patient connecte sur ce psy (rating=null si aucun avis)
  static String psychologistMyReview(int psychologistId) =>
      '/psychologists/$psychologistId/review/me';

  // --- ml-service (route fixe, pas dans Eureka) ---
  // GET recommandations (TF-IDF + cosinus), JWT relayé pour appeler user-service
  static String recommendations(int patientId, {int topN = 5}) =>
      '/recommendations/$patientId?top_n=$topN';

  // --- appointment-service (routé via /appointments/**) ---
  static const String appointments = '/appointments';

  static String appointmentsByPatient(int patientId) =>
      '/appointments/patient/$patientId';

  static String appointmentsByPsychologist(int psychologistId) =>
      '/appointments/psychologist/$psychologistId';

  // status en query param, pas en body JSON
  static String appointmentStatus(int appointmentId, String status) =>
      '/appointments/$appointmentId/status?status=$status';

  // GET revenu net du psy (apres commission), total + mois en cours
  static String psychologistRevenue(int psychologistId) =>
      '/payments/psychologist/$psychologistId/revenue';

  // GET portefeuille psy (solde dispo, total net, historique retraits)
  static String psychologistWallet(int psychologistId) =>
      '/payments/psychologist/$psychologistId/wallet';

  // POST retrait simule : ?amount=X&method=ORANGE_MONEY|WAVE|BANK_TRANSFER
  static String psychologistWithdraw(int psychologistId) =>
      '/payments/psychologist/$psychologistId/withdraw';

  // GET historique détaillé des paiements reçus par un psy (1 ligne = 1 RDV)
  static String psychologistTransactions(int psychologistId) =>
      '/payments/psychologist/$psychologistId/transactions';

  // reserve au patient proprietaire, repasse un RDV confirme en attente (psy doit reconfirmer)
  static String appointmentReschedule(int appointmentId) =>
      '/appointments/$appointmentId/reschedule';

  // réservé aux RDV ANNULÉ/REFUSÉ, par le patient propriétaire
  static String appointmentById(int appointmentId) =>
      '/appointments/$appointmentId';

  // --- journal privé (identité patient résolue côté backend via JWT) ---
  static const String journalEntries = '/journal';

  static String journalEntry(int entryId) => '/journal/$entryId';

  // --- urgence : psys disponibles maintenant ---
  static const String emergencyPsychologists = '/psychologists/emergency';

  static String psychologistEmergencyStatus(int psychologistId) =>
      '/psychologists/$psychologistId/emergency';

  // --- session de consultation simulée ---
  static const String sessionsStart = '/sessions/start';
  static const String sessionsEmergency = '/sessions/emergency';

  static String sessionEnd(int sessionId) => '/sessions/$sessionId/end';

  static String sessionById(int sessionId) => '/sessions/$sessionId';

  static String sessionByAppointment(int appointmentId) =>
      '/sessions/appointment/$appointmentId';

  // --- paiement ---
  static const String payments = '/payments';

  static String paymentsByAppointment(int appointmentId) =>
      '/payments/appointment/$appointmentId';

  // --- notifications ---
  // userId = en fait PatientProfile.id, pas l'authUserId
  static String notificationsByUser(int patientId) =>
      '/notifications/user/$patientId';

  static String notificationRead(int notificationId) =>
      '/notifications/$notificationId/read';

  // --- admin (réservé ROLE_ADMIN) ---
  static const String adminUsers = '/admin/users';
  static const String adminPsychologists = '/admin/psychologists';
  static const String adminPatients = '/admin/patients';
  static const String adminAppointments = '/admin/appointments';
  static const String adminPayments = '/admin/payments';

  // ici le filtre status est gere par le backend, pas pour les paiements (filtre cote app)
  static String adminAppointmentsByStatus(String? status) =>
      status == null ? adminAppointments : '/admin/appointments?status=$status';

  // chaque service a son propre /admin/stats/*, renomme pour pas avoir de doublons
  static const String adminStatsAccounts = '/admin/stats/accounts';
  static const String adminStatsProfiles = '/admin/stats/profiles';
  static const String adminStatsAppointments = '/admin/stats/appointments';
  // paiement/commission, maintenant cote payment-service (route a part depuis
  // l'extraction du paiement en microservice dedie)
  static const String adminStatsPayments = '/admin/stats/payments';

  static String adminSetUserEnabled(int userId, bool enabled) =>
      '/admin/users/$userId/enabled?enabled=$enabled';

  // suppression définitive, irréversible
  static String adminDeleteUser(int userId) => '/admin/users/$userId';

  // reset force par l'admin, mdp en corps JSON
  static String adminResetPassword(int userId) =>
      '/admin/users/$userId/password';

  static String adminSetPsychologistVerified(int psychologistId, bool verified) =>
      '/admin/psychologists/$psychologistId/verify?verified=$verified';

  // refuse explicitement (verify?verified=false est un no-op si déjà en attente)
  static String adminSetPsychologistRejected(int psychologistId, bool rejected) =>
      '/admin/psychologists/$psychologistId/reject?rejected=$rejected';

  // taux de commission courant de la plateforme
  static const String adminPlatformSettings = '/admin/platform-settings';

  // PUT /admin/platform-settings/commission-rate?commissionRatePercent=N
  static String adminSetCommissionRate(double commissionRatePercent) =>
      '/admin/platform-settings/commission-rate?commissionRatePercent=$commissionRatePercent';

  // --- messagerie patient/psychologue ---
  static const String messagesConversations = '/messages/conversations';

  static String messagesConversationMessages(int conversationId) =>
      '/messages/conversations/$conversationId/messages';

  static String messagesConversationRead(int conversationId) =>
      '/messages/conversations/$conversationId/read';

  // --- recommandations post-séance (appointment-service via /session-recommendations/**) ---
  // POST : psy crée, GET /patient/me : patient voit les siennes (non cochées)
  // GET /appointment/{id} : psy voit celles d'un RDV ; PATCH /{id}/complete ; DELETE /{id}
  static const String sessionRecommendations = '/session-recommendations';
  static const String myPendingRecommendations =
      '/session-recommendations/patient/me';
  static String recommendationsByAppointment(int appointmentId) =>
      '/session-recommendations/appointment/$appointmentId';
  static String recommendationComplete(int id) =>
      '/session-recommendations/$id/complete';
  static String sessionRecommendation(int id) => '/session-recommendations/$id';

  // --- questionnaires PHQ-9 / GAD-7 (appointment-service via /questionnaires/**) ---
  static const String questionnaires = '/questionnaires';
  static const String myPendingQuestionnaires = '/questionnaires/patient/me/pending';
  // historique complet patient (pending + completed)
  static const String myQuestionnaires = '/questionnaires/patient/me';
  static String patientQuestionnaires(int patientId) =>
      '/questionnaires/patient/$patientId';
  static String questionnaireAnswers(int questionnaireId) =>
      '/questionnaires/$questionnaireId/answers';

  // --- signalements psychologues (user-service via /patients/**/reports, /admin/reports/**) ---
  static String patientReports(int patientId) => '/patients/$patientId/reports';
  static const String adminReports = '/admin/reports';
  static String adminReport(int reportId) => '/admin/reports/$reportId';
  static String adminReportEvidence(int reportId) =>
      '/admin/reports/$reportId/evidence';

  // --- broadcast admin (annonces vers tous / patients / psys) ---
  // audience = 'ALL' | 'PATIENTS' | 'PSYCHOLOGISTS'
  static const String adminBroadcast = '/admin/notifications/broadcast';

  // GET /users/broadcasts : liste des broadcasts visibles par l'utilisateur connecté
  // (routé via /users/** existant, filtré par rôle côté backend)
  static const String broadcasts = '/users/broadcasts';

  // --- compagnon IA "Xalaat" (ai-companion-service, routé via /companion/**) ---
  // Conversation jamais stockée côté serveur (cf. README ai-companion-service) :
  // CompanionService côté Flutter garde l'historique en mémoire uniquement et
  // le renvoie à chaque appel.
  static const String companionChat = '/companion/chat';

  static const Duration timeout = Duration(seconds: 15);

  // Mistral via Ollama peut etre lent (CPU/Metal, pas de GPU dedie) : le
  // timeout global de 15s ci-dessus coupe systematiquement la reponse avant
  // qu'elle n'arrive. Cet endpoint a son propre timeout, plus genereux.
  static const Duration companionChatTimeout = Duration(seconds: 90);

  // upload du justificatif psy (photo/PDF, jusqu'a 20MB) : peut prendre
  // plus de 15s sur un reseau mobile/wifi faible
  static const Duration licenseUploadTimeout = Duration(seconds: 60);
}
