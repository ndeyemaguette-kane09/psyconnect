package com.example.paymentservice.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final Logger LOGGER = LoggerFactory.getLogger(JwtAuthenticationFilter.class);

    private final JwtService jwtService;

    public JwtAuthenticationFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        final String authHeader = request.getHeader("Authorization");
        final String jwt;
        final String username;

        LOGGER.debug("[payment-JWT] {} {} | Authorization: {}",
                request.getMethod(), request.getRequestURI(),
                authHeader != null ? "présent (Bearer...)" : "ABSENT");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            LOGGER.warn("[payment-JWT] Pas de Bearer token pour {} {} → filtre passe, Spring Security bloquera si route protégée",
                    request.getMethod(), request.getRequestURI());
            filterChain.doFilter(request, response);
            return;
        }

        jwt = authHeader.substring(7);

        try {
            username = jwtService.extractUsername(jwt);
        } catch (RuntimeException ex) {
            LOGGER.error("[payment-JWT] extractUsername a échoué pour {} {} : {}",
                    request.getMethod(), request.getRequestURI(), ex.getMessage());
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {

            if (jwtService.isTokenValid(jwt)) {

                String role = jwtService.extractRole(jwt);
                LOGGER.info("[payment-JWT] JWT valide pour {} | role={} | uri={}",
                        username, role, request.getRequestURI());

                UsernamePasswordAuthenticationToken authToken =
                        new UsernamePasswordAuthenticationToken(
                                username,
                                null,
                                List.of(new SimpleGrantedAuthority("ROLE_" + role))
                        );

                authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                SecurityContextHolder.getContext().setAuthentication(authToken);

                try {
                    Long authUserId = jwtService.extractUserId(jwt);
                    request.setAttribute("authUserId", authUserId);
                    LOGGER.debug("[payment-JWT] authUserId={} positionné pour {}", authUserId, request.getRequestURI());
                } catch (RuntimeException ex) {
                    // vieux token sans userId, on laisse vide
                    LOGGER.warn("[payment-JWT] Pas de userId dans le token pour {} : {}", request.getRequestURI(), ex.getMessage());
                }
            } else {
                LOGGER.error("[payment-JWT] isTokenValid=false pour {} {} | username={} → authentification NON positionnée → Spring Security va bloquer",
                        request.getMethod(), request.getRequestURI(), username);
            }
        }

        filterChain.doFilter(request, response);
    }
}
