package com.example.notificationservice.entity;

public enum NotificationType {
    APPOINTMENT,
    REMINDER,
    SYSTEM,
    // ajouté 2026-06-29 : les paiements (payment-service) envoyaient déjà
    // type="PAYMENT" mais cette valeur n'existait pas → Jackson plantait (400),
    // avalé en silence par le circuit breaker. Aucune notif de paiement ne
    // parvenait jamais.
    PAYMENT,
    // ajouté 2026-07-12 : QuestionnaireServiceImpl envoie "QUESTIONNAIRE"
    // (notif patient → nouveau questionnaire à remplir) et "QUESTIONNAIRE_RESULT"
    // (notif psy → résultats reçus). Même bug silencieux que PAYMENT ci-dessus.
    QUESTIONNAIRE,
    QUESTIONNAIRE_RESULT,
    // annonce admin envoyée en broadcast à un groupe d'utilisateurs
    // (POST /admin/notifications/broadcast → user-service → NotificationClient)
    ANNOUNCEMENT,
    // ajouté 2026-07-14 : session-service envoie "SESSION" à la fin d'une
    // session (normale ou d'urgence). Même bug silencieux que PAYMENT/QUESTIONNAIRE.
    SESSION
}
