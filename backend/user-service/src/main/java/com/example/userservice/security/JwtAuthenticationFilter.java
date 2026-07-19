package com.example.userservice.security;

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
public class JwtAuthenticationFilter
        extends OncePerRequestFilter {

    private static final Logger log =
            LoggerFactory.getLogger(JwtAuthenticationFilter.class);

    private final JwtService jwtService;

    public JwtAuthenticationFilter(
            JwtService jwtService
    ) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        final String method = request.getMethod();
        final String uri    = request.getRequestURI();

        final String authHeader =
                request.getHeader("Authorization");

        final String jwt;

        final String username;

        if (authHeader == null
                || !authHeader.startsWith("Bearer ")) {

            filterChain.doFilter(request, response);

            return;
        }

        jwt = authHeader.substring(7);

        try {
            username = jwtService.extractUsername(jwt);
        } catch (RuntimeException ex) {
            log.warn("JWT filter [{}] {} — extractUsername failed: {}", method, uri, ex.getMessage());
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        if (username != null
                && SecurityContextHolder
                .getContext()
                .getAuthentication() == null) {

            boolean valid = jwtService.isTokenValid(jwt);

            if (valid) {
                String role = jwtService.extractRole(jwt);
                String authority = "ROLE_" + role;

                UsernamePasswordAuthenticationToken authToken =
                        new UsernamePasswordAuthenticationToken(
                                username,
                                null,
                                List.of(new SimpleGrantedAuthority(authority))
                        );

                authToken.setDetails(
                        new WebAuthenticationDetailsSource()
                                .buildDetails(request)
                );

                SecurityContextHolder
                        .getContext()
                        .setAuthentication(authToken);

                try {
                    Long authUserId = jwtService.extractUserId(jwt);
                    request.setAttribute("authUserId", authUserId);
                } catch (RuntimeException ex) {
                    // Ancien token sans userId — attribut laissé vide intentionnellement
                }
            } else {
                log.warn("JWT filter [{}] {} — token INVALID (expired or bad signature)", method, uri);
            }
        }

        filterChain.doFilter(request, response);
    }
}
