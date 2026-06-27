package com.example.appointmentservice.config;

import java.time.Duration;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {

    // Sans ces délais, un appel à user-service ou notification-service qui ne
    // répond jamais (service bloqué, réseau coupé sans RST/FIN) laisserait le
    // thread appelant — et donc potentiellement tout le pool de threads HTTP
    // d'appointment-service — bloqué indéfiniment. C'est ce délai borné qui
    // permet ensuite à Resilience4j (retry / circuit breaker) de réagir dans
    // un temps fini plutôt que de rester suspendu en attente d'une réponse.
    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(2);
    private static final Duration READ_TIMEOUT = Duration.ofSeconds(3);

    // Construit via le RestTemplateBuilder auto-configuré par Spring Boot
    // (plutôt qu'un "new RestTemplate(requestFactory)" manuel) afin de
    // bénéficier de ses ObservationRestTemplateCustomizer : c'est ce qui
    // propage automatiquement l'id de trace (B3/Brave) dans les en-têtes
    // sortants vers user-service/notification-service. Un RestTemplate
    // construit "à la main" ignorerait silencieusement le traçage.
    @Bean
    @LoadBalanced
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
                .connectTimeout(CONNECT_TIMEOUT)
                .readTimeout(READ_TIMEOUT)
                .build();
    }
}
