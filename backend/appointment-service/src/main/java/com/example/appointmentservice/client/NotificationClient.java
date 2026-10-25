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

import com.example.appointmentservice.security.ServiceTokenProvider;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

@Component
public class NotificationClient {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(NotificationClient.class);

    private final RestTemplate restTemplate;
    private final String notificationServiceUrl;

    private final ServiceTokenProvider serviceTokenProvider;

    public NotificationClient(
            RestTemplate restTemplate,
            @Value("${services.notification.url}") String notificationServiceUrl,
            ServiceTokenProvider serviceTokenProvider
    ) {
        this.restTemplate = restTemplate;
        this.notificationServiceUrl = notificationServiceUrl;
        this.serviceTokenProvider = serviceTokenProvider;
    }

    @CircuitBreaker(name = "notificationService")
    @Retry(name = "notificationService", fallbackMethod = "fallbackSend")
    public void send(Long userId, String title, String message, String type, String userRole) {

        Map<String, Object> notification = new HashMap<>();
        notification.put("userId", userId);
        notification.put("title", title);
        notification.put("message", message);
        notification.put("type", type);
        notification.put("userRole", userRole);

        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", serviceTokenProvider.authorizationHeader());

        restTemplate.exchange(
                notificationServiceUrl + "/notifications",
                HttpMethod.POST,
                new HttpEntity<>(notification, headers),
                Object.class
        );
    }

    @CircuitBreaker(name = "notificationService")
    @Retry(name = "notificationService", fallbackMethod = "fallbackSendAboutAppointment")
    public void sendAboutAppointment(Long userId, String title, String message, String type,
                                     String userRole, Long appointmentId) {

        Map<String, Object> notification = new HashMap<>();
        notification.put("userId", userId);
        notification.put("title", title);
        notification.put("message", message);
        notification.put("type", type);
        notification.put("userRole", userRole);
        notification.put("appointmentId", appointmentId);

        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", serviceTokenProvider.authorizationHeader());

        restTemplate.exchange(
                notificationServiceUrl + "/notifications",
                HttpMethod.POST,
                new HttpEntity<>(notification, headers),
                Object.class
        );
    }

    private void fallbackSendAboutAppointment(Long userId, String title, String message, String type,
                                              String userRole, Long appointmentId, Throwable t) {
        fallbackSend(userId, title, message, type, userRole, t);
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
