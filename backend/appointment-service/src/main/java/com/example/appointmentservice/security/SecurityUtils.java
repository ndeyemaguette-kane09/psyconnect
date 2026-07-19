package com.example.appointmentservice.security;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.example.appointmentservice.exception.ForbiddenOperationException;

// pour recuperer les infos du JWT (id, role, header) depuis les services
public final class SecurityUtils {

    private SecurityUtils() {
    }

    private static HttpServletRequest currentRequest() {
        return ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes())
                .getRequest();
    }

    public static Long currentAuthUserId() {
        Object attribute = currentRequest().getAttribute("authUserId");

        if (attribute == null) {
            throw new ForbiddenOperationException("Utilisateur non authentifié");
        }

        return (Long) attribute;
    }

    public static String currentAuthorizationHeader() {
        return currentRequest().getHeader("Authorization");
    }

    public static boolean hasRole(String role) {
        return SecurityContextHolder.getContext().getAuthentication() != null
                && SecurityContextHolder.getContext().getAuthentication().getAuthorities()
                        .stream()
                        .anyMatch(a -> a.getAuthority().equals("ROLE_" + role));
    }
}
