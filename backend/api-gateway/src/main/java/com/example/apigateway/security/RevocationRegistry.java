package com.example.apigateway.security;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.loadbalancer.reactive.ReactorLoadBalancerExchangeFilterFunction;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

@Component
public class RevocationRegistry {

    private static final Logger LOG = LoggerFactory.getLogger(RevocationRegistry.class);

    private final WebClient webClient;
    private final String revocationsUrl;
    private final Map<Long, Long> revokedAtByUser = new ConcurrentHashMap<>();

    public RevocationRegistry(
            ReactorLoadBalancerExchangeFilterFunction loadBalancer,
            @Value("${services.auth.revocations-url:http://AUTH-SERVICE/internal/revocations}")
            String revocationsUrl
    ) {
        this.webClient = WebClient.builder().filter(loadBalancer).build();
        this.revocationsUrl = revocationsUrl;
    }

    public boolean isRevoked(Long userId, long issuedAtMs) {
        Long revokedAt = revokedAtByUser.get(userId);
        return revokedAt != null && issuedAtMs <= revokedAt;
    }

    @Scheduled(fixedDelayString = "${gateway.revocations.refresh-ms:10000}")
    public void refresh() {
        webClient.get()
                .uri(revocationsUrl)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<List<Revocation>>() { })
                .subscribe(
                        list -> {
                            Map<Long, Long> fresh = new ConcurrentHashMap<>();
                            list.forEach(r -> fresh.put(r.userId(), r.revokedAt()));
                            revokedAtByUser.keySet().retainAll(fresh.keySet());
                            revokedAtByUser.putAll(fresh);
                        },
                        error -> LOG.warn("Liste des révocations indisponible : {}", error.getMessage())
                );
    }

    public record Revocation(Long userId, long revokedAt) {
    }
}
