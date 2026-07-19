package com.example.paymentservice.config;

import java.time.Duration;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {

    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(5);
    // 3s était trop court : appointment-service doit appeler user-service pour
    // vérifier l'ownership → 2 appels réseau en cascade, 3s insuffisant
    private static final Duration READ_TIMEOUT = Duration.ofSeconds(10);

    // via RestTemplateBuilder (pas new RestTemplate) pour garder le traçage (B3/Brave)
    @Bean
    @LoadBalanced
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
                .connectTimeout(CONNECT_TIMEOUT)
                .readTimeout(READ_TIMEOUT)
                .build();
    }
}
