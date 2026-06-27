
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
                        .requestMatchers(
                                "/psychologists/by-auth-user/**"
                        ).authenticated()
                        // Doit précéder la règle GET permitAll ci-dessous :
                        // le justificatif (diplôme, carte pro) ne doit
                        // jamais être téléchargeable sans authentification.
                        // L'autorisation fine (propriétaire OU ADMIN) est
                        // ensuite vérifiée dans PsychologistProfileServiceImpl
                        // #getLicenseDocument.
                        .requestMatchers(
                                HttpMethod.GET,
                                "/psychologists/*/license-document"
                        ).authenticated()
                        .requestMatchers(
                                HttpMethod.GET,
                                "/psychologists",
                                "/psychologists/**"
                        ).permitAll()
                        .requestMatchers("/psychologists/**")
                        .hasRole("PSYCHOLOGIST")
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
