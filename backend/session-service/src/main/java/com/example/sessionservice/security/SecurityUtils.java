package com.example.sessionservice.security;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.example.sessionservice.exception.ForbiddenOperationException;

public final class SecurityUtils {

    private SecurityUtils() { }

    private static HttpServletRequest currentRequest() {
        return ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest();
    }

    public static Long currentAuthUserId() {
        Object attr = currentRequest().getAttribute("authUserId");
        if (attr == null) throw new ForbiddenOperationException("Utilisateur non authentifié");
        return (Long) attr;
    }

    public static String currentAuthorizationHeader() {
        return currentRequest().getHeader("Authorization");
    }

    public static boolean hasRole(String role) {
        return SecurityContextHolder.getContext().getAuthentication() != null
                && SecurityContextHolder.getContext().getAuthentication().getAuthorities()
                        .stream().anyMatch(a -> a.getAuthority().equals("ROLE_" + role));
    }
}
