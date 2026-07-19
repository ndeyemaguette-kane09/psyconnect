package com.example.userservice.security;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

// Récupère le header Authorization depuis la couche service
// pour le relayer vers notification-service
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
