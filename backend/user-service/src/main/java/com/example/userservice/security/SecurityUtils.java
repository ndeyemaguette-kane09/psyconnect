package com.example.userservice.security;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * Accès, depuis la couche service, à l'en-tête Authorization brut de la
 * requête HTTP en cours — nécessaire pour le relayer vers
 * notification-service (cf. {@link com.example.userservice.client.NotificationClient}),
 * sur le même modèle que appointment-service.security.SecurityUtils.
 */
public final class SecurityUtils {

    private SecurityUtils() {
    }

    private static HttpServletRequest currentRequest() {
        return ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes())
                .getRequest();
    }

    public static String currentAuthorizationHeader() {
        return currentRequest().getHeader("Authorization");
    }
}
