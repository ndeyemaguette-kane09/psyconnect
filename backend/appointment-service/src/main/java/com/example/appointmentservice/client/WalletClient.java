package com.example.appointmentservice.client;

import java.util.HashMap;
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

import com.example.appointmentservice.exception.InsufficientBalanceException;
import com.example.appointmentservice.exception.ServiceUnavailableException;
import com.example.appointmentservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

/**
 * Client vers le solde géré côté user-service (PatientProfile.walletBalance) :
 * débite lors d'un paiement, crédite lors d'un remboursement.
 *
 * Même modèle que {@link com.example.appointmentservice.service.OwnershipResolver} :
 * le JWT de l'appelant courant est relayé tel quel vers user-service, qui
 * vérifie lui-même la propriété du patientId. Réutilise l'instance
 * Resilience4j "userService" ; un solde insuffisant est une erreur métier
 * (402), pas une panne, donc exclue du retry/circuit breaker (cf.
 * application.properties, ignore-exceptions).
 */
@Component
public class WalletClient {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(WalletClient.class);

    private final RestTemplate restTemplate;
    private final String userServiceUrl;

    public WalletClient(
            RestTemplate restTemplate,
            @Value("${services.user.url}") String userServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.userServiceUrl = userServiceUrl;
    }

    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackDebit")
    public void debit(Long patientId, Double amount) {
        call(patientId, "debit", amount);
    }

    @CircuitBreaker(name = "userService")
    @Retry(name = "userService", fallbackMethod = "fallbackCredit")
    public void credit(Long patientId, Double amount) {
        call(patientId, "credit", amount);
    }

    @SuppressWarnings("unchecked")
    private void call(Long patientId, String operation, Double amount) {

        Map<String, Object> body = new HashMap<>();
        body.put("amount", amount);

        HttpHeaders headers = new HttpHeaders();
        String authorization = SecurityUtils.currentAuthorizationHeader();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        try {
            restTemplate.exchange(
                    userServiceUrl + "/patients/" + patientId + "/wallet/" + operation,
                    HttpMethod.POST,
                    new HttpEntity<>(body, headers),
                    Map.class
            );
        } catch (HttpClientErrorException.NotFound ex) {
            throw new InsufficientBalanceException(
                    "Profil patient introuvable côté solde PsyConnect"
            );
        } catch (HttpClientErrorException ex) {
            // Couvre 400 (montant invalide) et 402 (solde insuffisant) :
            // Spring ne fournit pas de sous-classe dédiée pour 402 (Payment
            // Required), contrairement à BadRequest/NotFound/Forbidden, donc
            // on retombe sur le type générique et on lit le code réellement
            // renvoyé via extractMessage (corps de la réponse). NotFound
            // doit rester catché séparément AVANT ce bloc (sous-classe de
            // HttpClientErrorException, sinon code mort/erreur de compil).
            throw new InsufficientBalanceException(extractMessage(ex));
        } catch (RestClientException ex) {
            // Échec d'infrastructure (timeout, connexion refusée, 5xx...) :
            // c'est cette exception-là que Retry/CircuitBreaker comptabilisent.
            throw new ServiceUnavailableException(
                    "user-service indisponible pour l'opération sur le solde ("
                            + operation + ")",
                    ex
            );
        }
    }

    private String extractMessage(HttpClientErrorException ex) {
        try {
            String responseBody = ex.getResponseBodyAsString();
            int idx = responseBody.indexOf("\"message\"");
            if (idx >= 0) {
                int start = responseBody.indexOf('"', idx + 9) + 1;
                int end = responseBody.indexOf('"', start);
                if (start > 0 && end > start) {
                    return responseBody.substring(start, end);
                }
            }
        } catch (Exception ignored) {
            // Best-effort : si le parsing échoue, on retombe sur le message générique.
        }
        return "Solde PsyConnect insuffisant ou opération refusée";
    }

    private void fallbackDebit(Long patientId, Double amount, Throwable t) {
        handleFallback("débit", t);
    }

    private void fallbackCredit(Long patientId, Double amount, Throwable t) {
        handleFallback("crédit", t);
    }

    private void handleFallback(String operation, Throwable t) {

        if (t instanceof InsufficientBalanceException) {
            throw (InsufficientBalanceException) t;
        }

        LOGGER.warn(
                "Opération de {} sur le solde PsyConnect impossible (retry épuisé "
                        + "ou circuit ouvert) : user-service indisponible",
                operation,
                t
        );

        throw new ServiceUnavailableException(
                "Le service utilisateur est temporairement indisponible, merci de "
                        + "réessayer dans quelques instants",
                t
        );
    }
}
