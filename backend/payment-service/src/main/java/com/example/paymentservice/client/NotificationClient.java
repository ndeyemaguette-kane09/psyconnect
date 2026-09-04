package com.example.paymentservice.client;

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

import com.example.paymentservice.security.SecurityUtils;

import io.github.resilience4j.retry.annotation.Retry;

// envoi de notif (paiement effectué, remboursement, etc) ; ne doit jamais
// faire echouer le paiement donc le fallback avale juste l'erreur
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
        try {
            String authorization = SecurityUtils.currentAuthorizationHeader();
            if (authorization != null) {
                headers.set("Authorization", authorization);
            }
        } catch (IllegalStateException ignored) {
        }

        restTemplate.exchange(
                notificationServiceUrl + "/notifications",
                HttpMethod.POST,
                new HttpEntity<>(notification, headers),
                Object.class
        );
    }

    private void fallbackSend(Long userId, String title, String message, String type, String userRole, Throwable t) {
        LOGGER.warn(
                "Notification non envoyée à l'utilisateur {} (\"{}\") : notification-service indisponible "
                        + "(retry épuisé ou circuit ouvert)",
                userId,
                title,
                t
        );
    }
}
