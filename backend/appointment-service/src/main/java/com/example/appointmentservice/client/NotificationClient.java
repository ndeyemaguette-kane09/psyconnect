package com.example.appointmentservice.client;

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import com.example.appointmentservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

/**
 * Point d'entrée unique vers notification-service pour l'envoi de
 * notifications "best effort" (paiement confirmé, rendez-vous créé ou
 * changé de statut, session terminée). Centralise ce qui était dupliqué
 * (RestTemplate + try/catch identiques) dans PaymentServiceImpl,
 * AppointmentServiceImpl et SessionServiceImpl.
 *
 * Une notification non envoyée ne doit JAMAIS faire échouer l'opération
 * métier principale (paiement, rendez-vous, session) qui l'a déclenchée :
 * après épuisement des tentatives de retry ou ouverture du circuit
 * breaker, le fallback se contente de logguer un avertissement plutôt que
 * de relancer une exception vers l'appelant.
 */
@Component
public class NotificationClient {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(NotificationClient.class);

    private final RestTemplate restTemplate;
    private final String notificationServiceUrl;

    public NotificationClient(
            RestTemplate restTemplate,
            @Value("${services.notification.url}") String notificationServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.notificationServiceUrl = notificationServiceUrl;
    }

    // fallbackMethod est attaché à @Retry (l'aspect le plus EXTERNE, voir
    // l'ordre par défaut Retry(CircuitBreaker(...)) de Resilience4j), pas à
    // @CircuitBreaker : si on l'attachait à @CircuitBreaker, son fallback
    // (qui ne relance rien volontairement, cf. fallbackSend) ferait
    // paraître l'appel "réussi" dès la 1ère tentative côté @Retry, qui ne
    // réessaierait alors jamais. En l'attachant à @Retry, le fallback ne
    // s'exécute qu'une fois, après épuisement réel des tentatives (ou
    // échec rapide si le circuit est ouvert).
    @CircuitBreaker(name = "notificationService")
    @Retry(name = "notificationService", fallbackMethod = "fallbackSend")
    public void send(Long userId, String title, String message, String type) {

        Map<String, Object> notification = new HashMap<>();
        notification.put("userId", userId);
        notification.put("title", title);
        notification.put("message", message);
        notification.put("type", type);

        HttpHeaders headers = new HttpHeaders();
        String authorization = SecurityUtils.currentAuthorizationHeader();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        restTemplate.exchange(
                notificationServiceUrl + "/notifications",
                HttpMethod.POST,
                new HttpEntity<>(notification, headers),
                Object.class
        );
    }

    private void fallbackSend(Long userId, String title, String message, String type, Throwable t) {
        LOGGER.warn(
                "Notification non envoyée à l'utilisateur {} (\"{}\") : notification-service indisponible "
                        + "(retry épuisé ou circuit ouvert)",
                userId,
                title,
                t
        );
    }
}
