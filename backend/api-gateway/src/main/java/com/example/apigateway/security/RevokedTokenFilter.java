package com.example.apigateway.security;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.server.reactive.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import reactor.core.publisher.Mono;

// la signature est vérifiée par chaque service ; ici on ne fait que refuser les jetons révoqués
@Component
public class RevokedTokenFilter implements GlobalFilter, Ordered {

    private static final byte[] REVOKED_BODY = ("{\"message\":\"Votre session n'est plus valide. "
            + "Veuillez vous reconnecter.\",\"errorCode\":\"SESSION_REVOKED\"}")
            .getBytes(StandardCharsets.UTF_8);

    private final RevocationRegistry revocationRegistry;
    private final ObjectMapper objectMapper;

    public RevokedTokenFilter(RevocationRegistry revocationRegistry, ObjectMapper objectMapper) {
        this.revocationRegistry = revocationRegistry;
        this.objectMapper = objectMapper;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String header = exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        if (header == null || !header.startsWith("Bearer ")) {
            return chain.filter(exchange);
        }

        JsonNode claims = readClaims(header.substring(7));
        if (claims == null || !claims.hasNonNull("userId") || !claims.hasNonNull("iat")) {
            return chain.filter(exchange);
        }

        long userId = claims.get("userId").asLong();
        long issuedAtMs = claims.get("iat").asLong() * 1000;
        if (!revocationRegistry.isRevoked(userId, issuedAtMs)) {
            return chain.filter(exchange);
        }

        ServerHttpResponse response = exchange.getResponse();
        response.setStatusCode(HttpStatus.UNAUTHORIZED);
        response.getHeaders().setContentType(MediaType.APPLICATION_JSON);
        DataBuffer body = response.bufferFactory().wrap(REVOKED_BODY);
        return response.writeWith(Mono.just(body));
    }

    private JsonNode readClaims(String token) {
        String[] parts = token.split("\\.");
        if (parts.length < 2) return null;
        try {
            return objectMapper.readTree(Base64.getUrlDecoder().decode(parts[1]));
        } catch (Exception e) {
            return null;
        }
    }

    @Override
    public int getOrder() {
        return -100;
    }
}
