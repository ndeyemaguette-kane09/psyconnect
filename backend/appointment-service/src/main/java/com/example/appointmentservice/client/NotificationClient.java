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

import io.github.resilience4j.retry.annotation.Retry;

// seul point d'entree vers notification-service
// une notif ratée doit jamais faire echouer le reste
// @CircuitBreaker retiré : état OPEN persistant bloquait toutes les notifs définitivement
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

    @Retry(name = "notificationService", fallbackMethod = "fallbackSend")
    public void send(Long userId, String title, String message, String type, String userRole) {

        Map<String, Object> notification = new HashMap<>();
        notification.put("userId", userId);
        notification.put("title", title);
        notification.put("message", message);
        notification.put("type", type);
        notification.put("userRole", userRole);

        HttpHeaders headers = new HttpHeaders();
        // currentAuthorizationHeader() lit RequestContextHolder qui n'est PAS
        // disponible dans un thread @Scheduled (pas de requête HTTP liée).
        // On attrape silencieusement : POST /notifications est permitAll côté
        // notification-service, donc l'absence de token n'est pas bloquante.
        try {
            String authorization = SecurityUtils.currentAuthorizationHeader();
            if (authorization != null) {
                headers.set("Authorization", authorization);
            }
        } catch (IllegalStateException ignored) {
            // appelé depuis un scheduler — pas de contexte HTTP, pas de token à transmettre
        }

        restTemplate.exchange(
                notificationServiceUrl + "/notifications",
                HttpMethod.POST,
                new HttpEntity<>(notification, headers),
                Object.class
        );
    }

    // fallback : on lève une RuntimeException pour que l'appelant (scheduler)
    // puisse l'attraper et éviter de marquer reminderSent=true à tort.
    // Cela permet aussi de réessayer lors du prochain cycle du scheduler.
    private void fallbackSend(Long userId, String title, String message, String type, String userRole, Throwable t) {
        LOGGER.warn(
                "Notification non envoyée à l'utilisateur {} (\"{}\") : notification-service indisponible "
                        + "(retry épuisé ou circuit ouvert)",
                userId,
                title,
                t
        );
        throw new RuntimeException("notification-service indisponible, rappel non envoyé", t);
    }
}
