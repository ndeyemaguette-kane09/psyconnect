package com.example.sessionservice.client;

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

import com.example.sessionservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

@Component
public class NotificationClient {

    private static final Logger LOG = LoggerFactory.getLogger(NotificationClient.class);

    private final RestTemplate restTemplate;
    private final String notificationServiceUrl;

    public NotificationClient(
            RestTemplate restTemplate,
            @Value("${services.notification.url}") String notificationServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.notificationServiceUrl = notificationServiceUrl;
    }

    @CircuitBreaker(name = "notificationService")
    @Retry(name = "notificationService", fallbackMethod = "fallbackSend")
    public void send(Long userId, String title, String message, String type, String userRole) {
        Map<String, Object> body = new HashMap<>();
        body.put("userId", userId);
        body.put("title", title);
        body.put("message", message);
        body.put("type", type);
        body.put("userRole", userRole);

        HttpHeaders headers = new HttpHeaders();
        String auth = SecurityUtils.currentAuthorizationHeader();
        if (auth != null) headers.set("Authorization", auth);

        restTemplate.exchange(
                notificationServiceUrl + "/notifications",
                HttpMethod.POST,
                new HttpEntity<>(body, headers),
                Object.class
        );
    }

    private void fallbackSend(Long userId, String title, String message, String type, String userRole, Throwable t) {
        LOG.warn("Notification non envoyée à {} {} (\"{}\"): notification-service indisponible", userRole, userId, title, t);
    }
}
