package com.example.paymentservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import com.example.paymentservice.exception.ForbiddenOperationException;
import com.example.paymentservice.exception.ResourceNotFoundException;
import com.example.paymentservice.exception.ServiceUnavailableException;
import com.example.paymentservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

import java.math.BigDecimal;
import java.util.Map;

// Résout l'identifiant de profil (patient ou psychologue) via l'id JWT, en appelant user-service.
// Retry + circuit breaker actifs car ce composant est sollicité à chaque requête.
@Component
public class OwnershipResolver {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(OwnershipResolver.class);

    private final RestTemplate restTemplate;
    private final String userServiceUrl;

    public OwnershipResolver(
            RestTemplate restTemplate,
            @Value("${services.user.url}") String userServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.userServiceUrl = userServiceUrl;
    }

    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackResolvePatientId")
    public Long resolveOwnPatientId() {
        return resolveOwnProfileId("/patients/by-auth-user/", "patient");
    }

    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackResolvePsychologistId")
    public Long resolveOwnPsychologistId() {
        return resolveOwnProfileId("/psychologists/by-auth-user/", "psychologue");
    }

    @SuppressWarnings("unchecked")
    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackConsultationPrice")
    public BigDecimal getConsultationPrice(Long psychologistId) {

        HttpHeaders headers = new HttpHeaders();
        String authorization = SecurityUtils.currentAuthorizationHeader();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        try {
            Map<String, Object> body = restTemplate.exchange(
                    userServiceUrl + "/psychologists/" + psychologistId,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    Map.class
            ).getBody();

            if (body == null || body.get("consultationPrice") == null) {
                return null;
            }

            return new BigDecimal(body.get("consultationPrice").toString());

        } catch (HttpClientErrorException.NotFound ex) {
            throw new ResourceNotFoundException("Psychologue introuvable");
        } catch (RestClientException ex) {
            throw new ServiceUnavailableException(
                    "user-service indisponible pour la lecture du tarif du psychologue",
                    ex
            );
        }
    }

    private BigDecimal fallbackConsultationPrice(Long psychologistId, Throwable t) {
        if (t instanceof ResourceNotFoundException || t instanceof ForbiddenOperationException) {
            throw (RuntimeException) t;
        }
        throw new ServiceUnavailableException(
                "Le service utilisateur est temporairement indisponible, merci de réessayer dans quelques instants",
                t
        );
    }

    @SuppressWarnings("unchecked")
    private Long resolveOwnProfileId(String path, String profileLabel) {

        Long authUserId = SecurityUtils.currentAuthUserId();
        String authorization = SecurityUtils.currentAuthorizationHeader();

        HttpHeaders headers = new HttpHeaders();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        try {
            Map<String, Object> body = restTemplate.exchange(
                    userServiceUrl + path + authUserId,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    Map.class
            ).getBody();

            if (body == null || body.get("id") == null) {
                throw new ResourceNotFoundException(
                        "Aucun profil " + profileLabel + " associé à cet utilisateur"
                );
            }

            return Long.valueOf(body.get("id").toString());

        } catch (HttpClientErrorException.NotFound ex) {
            throw new ResourceNotFoundException(
                    "Aucun profil " + profileLabel + " associé à cet utilisateur"
            );
        } catch (HttpClientErrorException.Forbidden ex) {
            throw new ForbiddenOperationException(
                    "Accès refusé lors de la résolution du profil " + profileLabel
            );
        } catch (RestClientException ex) {
            // Panne réseau — le retry se chargera de réessayer
            throw new ServiceUnavailableException(
                    "user-service indisponible pour la vérification de propriété (" + profileLabel + ")",
                    ex
            );
        }
    }

    private Long fallbackResolvePatientId(Throwable t) {
        return handleFallback("patient", t);
    }

    private Long fallbackResolvePsychologistId(Throwable t) {
        return handleFallback("psychologue", t);
    }

    // Appelé quand tous les essais ont échoué ou que le circuit est ouvert
    private Long handleFallback(String profileLabel, Throwable t) {

        if (t instanceof ResourceNotFoundException || t instanceof ForbiddenOperationException) {
            throw (RuntimeException) t;
        }

        LOGGER.warn(
                "user-service indisponible (retry épuisé ou circuit ouvert) pour la résolution du profil {}",
                profileLabel,
                t
        );

        throw new ServiceUnavailableException(
                "Le service utilisateur est temporairement indisponible, merci de réessayer dans quelques instants",
                t
        );
    }
}
