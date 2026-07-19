package com.example.authservice.config;

import java.time.Duration;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

// premier client HTTP sortant de auth-service (vers user-service), pour
// Vérifie au login si un psychologue est approuvé. Même config que
// appointment-service : RestTemplateBuilder (pas new RestTemplate) pour
// garder le tracage B3/Brave, timeouts courts pour ne pas bloquer le login
@Configuration
public class RestTemplateConfig {

    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(2);
    private static final Duration READ_TIMEOUT = Duration.ofSeconds(3);

    @Bean
    @LoadBalanced
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
                .connectTimeout(CONNECT_TIMEOUT)
                .readTimeout(READ_TIMEOUT)
                .build();
    }
}
