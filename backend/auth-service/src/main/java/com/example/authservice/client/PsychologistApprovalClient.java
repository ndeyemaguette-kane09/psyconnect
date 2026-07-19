package com.example.authservice.client;

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

// Appelé depuis AuthService.login() pour savoir si un psychologue peut se
// connecter. Utilise le JWT qui vient d'être généré pour cet utilisateur
// (jamais renvoyé au client si on bloque) pour appeler l'endpoint
// "by-auth-user" de user-service, qui est en self-only (callerAuthUserId ==
// authUserId du chemin) → ça passe forcément puisque c'est son propre token
@Component
public class PsychologistApprovalClient {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(PsychologistApprovalClient.class);

    private final RestTemplate restTemplate;
    private final String userServiceUrl;

    public PsychologistApprovalClient(
            RestTemplate restTemplate,
            @Value("${services.user.url}") String userServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.userServiceUrl = userServiceUrl;
    }

    public enum ApprovalStatus {
        // Pas encore de profil créé (inscription en cours, étape 2 pas
        // encore passée) → on laisse toujours passer
        NO_PROFILE,
        // Profil existant, ni vérifié ni rejeté → connexion bloquée
        PENDING,
        REJECTED,
        APPROVED
    }

    @SuppressWarnings("unchecked")
    public ApprovalStatus checkApprovalStatus(Long authUserId, String bearerToken) {

        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", bearerToken);

        try {
            Map<String, Object> body = restTemplate.exchange(
                    userServiceUrl + "/psychologists/by-auth-user/" + authUserId,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    Map.class
            ).getBody();

            if (body == null) {
                return ApprovalStatus.NO_PROFILE;
            }

            boolean rejected = Boolean.TRUE.equals(body.get("rejected"));
            boolean verified = Boolean.TRUE.equals(body.get("profileVerified"));

            if (rejected) {
                return ApprovalStatus.REJECTED;
            }

            return verified ? ApprovalStatus.APPROVED : ApprovalStatus.PENDING;

        } catch (HttpClientErrorException.NotFound ex) {
            return ApprovalStatus.NO_PROFILE;
        } catch (RestClientException ex) {
            // Panne réseau / user-service indisponible : on bloque par
            // sécurité plutôt que de laisser passer un psychologue qu'on
            // ne peut pas vérifier (pas de retry/circuit breaker ici ;
            // à revisiter si ça devient un vrai point de friction)
            LOGGER.warn(
                    "user-service indisponible pour la verification du statut psychologue (authUserId={})",
                    authUserId,
                    ex
            );
            throw new RuntimeException(
                    "Le service de vérification est temporairement indisponible. "
                            + "Merci de réessayer dans quelques instants."
            );
        }
    }
}
