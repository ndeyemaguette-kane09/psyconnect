package com.example.userservice.client;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import com.example.userservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

/**
 * Point d'entrée vers auth-service depuis user-service — sur le même
 * modèle que {@link NotificationClient}. Utilisé pour récupérer le pseudo
 * d'un patient (donnée qui n'existe que dans auth-service) quand on doit
 * afficher un pseudonyme à la place du nom réel : mode anonyme d'un patient,
 * vu par un psychologue (cf. PatientProfileServiceImpl).
 *
 * "Best effort" : si auth-service ne répond pas, on retombe sur un libellé
 * générique plutôt que de faire échouer l'affichage de la fiche patient.
 */
@Component
public class AuthServiceClient {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(AuthServiceClient.class);

    private final RestTemplate restTemplate;
    private final String authServiceUrl;

    public AuthServiceClient(
            RestTemplate restTemplate,
            @Value("${services.auth.url}") String authServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.authServiceUrl = authServiceUrl;
    }

    @CircuitBreaker(name = "authService", fallbackMethod = "fallbackGetPseudo")
    @Retry(name = "authService", fallbackMethod = "fallbackGetPseudo")
    public String getPseudo(Long authUserId) {

        HttpHeaders headers = new HttpHeaders();
        String authorization = SecurityUtils.currentAuthorizationHeader();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        @SuppressWarnings("unchecked")
        Map<String, String> body = restTemplate.exchange(
                authServiceUrl + "/users/" + authUserId + "/pseudo",
                HttpMethod.GET,
                new HttpEntity<>(headers),
                Map.class
        ).getBody();

        return body != null ? body.get("pseudo") : null;
    }

    private String fallbackGetPseudo(Long authUserId, Throwable t) {
        LOGGER.warn(
                "Pseudo introuvable pour l'utilisateur {} : auth-service indisponible "
                        + "(retry épuisé ou circuit ouvert)",
                authUserId,
                t
        );
        return null;
    }
}
