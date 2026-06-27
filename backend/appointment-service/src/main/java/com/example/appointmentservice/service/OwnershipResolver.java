package com.example.appointmentservice.service;

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

import com.example.appointmentservice.exception.ForbiddenOperationException;
import com.example.appointmentservice.exception.ResourceNotFoundException;
import com.example.appointmentservice.exception.ServiceUnavailableException;
import com.example.appointmentservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

import java.util.Map;

/**
 * Résout l'identité métier (PatientProfile.id / PsychologistProfile.id) de
 * l'utilisateur courant à partir de son authUserId (claim du JWT), en
 * appelant user-service. Nécessaire car appointment-service ne stocke que
 * des identifiants de profil (patientId/psychologistId), distincts de
 * l'authUserId porté par le jeton — voir user-service:
 * GET /patients/by-auth-user/{authUserId} et GET /psychologists/by-auth-user/{authUserId}.
 *
 * Le jeton JWT de l'appelant est relayé tel quel vers user-service (ces deux
 * routes y exigent une authentification et vérifient elles-mêmes que
 * authUserId correspond à l'appelant).
 *
 * Cet appel HTTP synchrone est exécuté à chaque contrôle de propriété ; c'est
 * le point de couplage le plus sensible aux pannes/latences de user-service
 * dans tout appointment-service. Il est donc protégé par Resilience4j :
 * - {@code @Retry} : ré-essaie automatiquement un échec transitoire (config
 *   "userService" dans application.properties) ;
 * - {@code @CircuitBreaker} : si le taux d'échec récent dépasse le seuil
 *   configuré, le circuit s'ouvre et les appels suivants échouent
 *   immédiatement (sans solliciter davantage un user-service déjà en
 *   difficulté) jusqu'à la prochaine fenêtre de test (half-open).
 * Dans les deux cas d'échec final, {@link #fallbackResolvePatientId} /
 * {@link #fallbackResolvePsychologistId} traduisent l'échec technique en
 * {@link ServiceUnavailableException} (HTTP 503), distincte d'un 404/403
 * métier.
 *
 * Le fallbackMethod est attaché à {@code @Retry} (l'aspect le plus EXTERNE :
 * l'ordre par défaut de Resilience4j est Retry(CircuitBreaker(...))), pas à
 * {@code @CircuitBreaker}. Si on l'attachait à {@code @CircuitBreaker}, son
 * exécution (même si elle relance l'exception ici) interviendrait à
 * l'intérieur de chaque tentative de retry plutôt qu'une seule fois après
 * épuisement réel des tentatives — voir {@link
 * com.example.appointmentservice.client.NotificationClient}, où la même
 * erreur (fallback sur @CircuitBreaker qui n'aurait pas relancé l'exception)
 * empêchait silencieusement tout réessai.
 */
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
            // Échec d'infrastructure (timeout, connexion refusée, 5xx...) :
            // c'est cette exception-là que Retry/CircuitBreaker comptabilisent
            // comme un échec (voir resilience4j.retry/circuitbreaker.instances
            // .userService.ignore-exceptions, qui exclut volontairement
            // ResourceNotFoundException et ForbiddenOperationException
            // ci-dessus : un 404/403 n'est pas une panne de user-service).
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

    /**
     * Invoqué par Resilience4j quand les tentatives de retry sont épuisées
     * (échecs successifs de user-service) ou quand le circuit breaker est
     * ouvert (CallNotPermittedException : on n'a même pas tenté l'appel).
     * Les exceptions métier (404/403) ne devraient jamais arriver ici
     * puisqu'elles sont exclues du périmètre retry/circuit breaker côté
     * configuration ; le test défensif ci-dessous les laisse simplement
     * remonter telles quelles si jamais la configuration changeait.
     */
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
