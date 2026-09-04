package com.example.userservice.config;

import com.example.userservice.security.JwtAuthenticationFilter;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    public SecurityConfig(
            JwtAuthenticationFilter jwtAuthenticationFilter
    ) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http
    ) throws Exception {

        http
                .csrf(csrf -> csrf.disable())

                .sessionManagement(session ->
                        session.sessionCreationPolicy(
                                SessionCreationPolicy.STATELESS
                        )
                )

                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/admin/**").hasRole("ADMIN")

                        .requestMatchers(HttpMethod.GET, "/users/broadcasts").authenticated()
                        .requestMatchers(
                                "/psychologists/by-auth-user/**"
                        ).authenticated()

                        .requestMatchers(
                                HttpMethod.GET,
                                "/psychologists/*/license-document"
                        ).authenticated()
                        .requestMatchers(
                                HttpMethod.GET,
                                "/psychologists",
                                "/psychologists/**"
                        ).permitAll()

                        .requestMatchers(
                                HttpMethod.PUT,
                                "/psychologists/*/review"
                        ).hasRole("PATIENT")
                        .requestMatchers("/psychologists/**")
                        .hasRole("PSYCHOLOGIST")

                        .requestMatchers("/patients/*/clinical-notes", "/clinical-notes/**")
                        .hasRole("PSYCHOLOGIST")

                        .requestMatchers(
                                HttpMethod.POST,
                                "/patients/*/reports"
                        ).hasRole("PATIENT")
                        .requestMatchers(
                                HttpMethod.POST,
                                "/patients/*/support-messages"
                        ).hasRole("PATIENT")
                        .requestMatchers("/users/**", "/patients/**", "/journal/**")
                        .authenticated()
                        .anyRequest().denyAll()
                )

                .addFilterBefore(
                        jwtAuthenticationFilter,
                        UsernamePasswordAuthenticationFilter.class
                );

        return http.build();
    }
}
