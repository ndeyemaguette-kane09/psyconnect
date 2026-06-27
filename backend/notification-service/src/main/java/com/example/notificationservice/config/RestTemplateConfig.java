package com.example.notificationservice.config;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {

    // Construit via le RestTemplateBuilder auto-configuré par Spring Boot
    // (plutôt qu'un "new RestTemplate()" manuel) afin de bénéficier de ses
    // ObservationRestTemplateCustomizer : c'est ce qui propage l'id de trace
    // (B3/Brave) vers user-service. Voir appointment-service/RestTemplateConfig
    // pour le même correctif appliqué là-bas.
    @Bean
    @LoadBalanced
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder.build();
    }
}
