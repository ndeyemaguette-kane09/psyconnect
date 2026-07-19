package com.example.sessionservice.service;

import java.util.Map;

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

import com.example.sessionservice.exception.ForbiddenOperationException;
import com.example.sessionservice.exception.ResourceNotFoundException;
import com.example.sessionservice.exception.ServiceUnavailableException;
import com.example.sessionservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

@Component
public class OwnershipResolver {

    private static final Logger LOG = LoggerFactory.getLogger(OwnershipResolver.class);

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
    private Long resolveOwnProfileId(String path, String label) {
        Long authUserId = SecurityUtils.currentAuthUserId();
        HttpHeaders headers = new HttpHeaders();
        String auth = SecurityUtils.currentAuthorizationHeader();
        if (auth != null) headers.set("Authorization", auth);

        try {
            Map<String, Object> body = restTemplate.exchange(
                    userServiceUrl + path + authUserId,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    Map.class
            ).getBody();

            if (body == null || body.get("id") == null)
                throw new ResourceNotFoundException("Aucun profil " + label + " associé à cet utilisateur");

            return Long.valueOf(body.get("id").toString());
        } catch (HttpClientErrorException.NotFound ex) {
            throw new ResourceNotFoundException("Aucun profil " + label + " associé à cet utilisateur");
        } catch (HttpClientErrorException.Forbidden ex) {
            throw new ForbiddenOperationException("Accès refusé lors de la résolution du profil " + label);
        } catch (RestClientException ex) {
            throw new ServiceUnavailableException("user-service indisponible (" + label + ")", ex);
        }
    }

    private Long fallbackResolvePatientId(Throwable t) { return handleFallback("patient", t); }
    private Long fallbackResolvePsychologistId(Throwable t) { return handleFallback("psychologue", t); }

    private Long handleFallback(String label, Throwable t) {
        if (t instanceof ResourceNotFoundException || t instanceof ForbiddenOperationException)
            throw (RuntimeException) t;
        LOG.warn("user-service indisponible pour la résolution du profil {}", label, t);
        throw new ServiceUnavailableException(
                "Le service utilisateur est temporairement indisponible", t);
    }
}
