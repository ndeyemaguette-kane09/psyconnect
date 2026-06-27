package com.example.notificationservice.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import com.example.notificationservice.exception.ResourceNotFoundException;
import com.example.notificationservice.exception.ForbiddenOperationException;
import com.example.notificationservice.security.SecurityUtils;

import java.util.Map;

/**
 * Résout le PatientProfile.id de l'utilisateur courant à partir de son
 * authUserId (claim du JWT), en appelant user-service. Nécessaire car
 * Notification.userId stocke un PatientProfile.id, distinct de l'authUserId
 * porté par le jeton — voir user-service: GET /patients/by-auth-user/{authUserId}.
 *
 * Le jeton JWT de l'appelant est relayé tel quel vers user-service (cette
 * route y exige une authentification et vérifie elle-même que authUserId
 * correspond à l'appelant).
 */
@Component
public class OwnershipResolver {

    private final RestTemplate restTemplate;
    private final String userServiceUrl;

    public OwnershipResolver(
            RestTemplate restTemplate,
            @Value("${services.user.url}") String userServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.userServiceUrl = userServiceUrl;
    }

    @SuppressWarnings("unchecked")
    public Long resolveOwnPatientId() {

        Long authUserId = SecurityUtils.currentAuthUserId();
        String authorization = SecurityUtils.currentAuthorizationHeader();

        HttpHeaders headers = new HttpHeaders();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        try {
            Map<String, Object> body = restTemplate.exchange(
                    userServiceUrl + "/patients/by-auth-user/" + authUserId,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    Map.class
            ).getBody();

            if (body == null || body.get("id") == null) {
                throw new ResourceNotFoundException(
                        "Aucun profil patient associé à cet utilisateur"
                );
            }

            return Long.valueOf(body.get("id").toString());

        } catch (HttpClientErrorException.NotFound ex) {
            throw new ResourceNotFoundException(
                    "Aucun profil patient associé à cet utilisateur"
            );
        } catch (HttpClientErrorException.Forbidden ex) {
            throw new ForbiddenOperationException(
                    "Accès refusé lors de la résolution du profil patient"
            );
        } catch (RestClientException ex) {
            throw new RuntimeException(
                    "user-service indisponible pour la vérification de propriété (patient)",
                    ex
            );
        }
    }

    /**
     * Équivalent de {@link #resolveOwnPatientId()} pour un psychologue —
     * résout le PsychologistProfile.id de l'utilisateur courant. Nécessaire
     * pour que les notifications envoyées à un psychologue (ex. décision de
     * validation de l'admin) puissent être lues par leur propriétaire.
     */
    @SuppressWarnings("unchecked")
    public Long resolveOwnPsychologistId() {

        Long authUserId = SecurityUtils.currentAuthUserId();
        String authorization = SecurityUtils.currentAuthorizationHeader();

        HttpHeaders headers = new HttpHeaders();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        try {
            Map<String, Object> body = restTemplate.exchange(
                    userServiceUrl + "/psychologists/by-auth-user/" + authUserId,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    Map.class
            ).getBody();

            if (body == null || body.get("id") == null) {
                throw new ResourceNotFoundException(
                        "Aucun profil psychologue associé à cet utilisateur"
                );
            }

            return Long.valueOf(body.get("id").toString());

        } catch (HttpClientErrorException.NotFound ex) {
            throw new ResourceNotFoundException(
                    "Aucun profil psychologue associé à cet utilisateur"
            );
        } catch (HttpClientErrorException.Forbidden ex) {
            throw new ForbiddenOperationException(
                    "Accès refusé lors de la résolution du profil psychologue"
            );
        } catch (RestClientException ex) {
            throw new RuntimeException(
                    "user-service indisponible pour la vérification de propriété (psychologue)",
                    ex
            );
        }
    }
}
