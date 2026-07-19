package com.example.sessionservice.client;

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

import com.example.sessionservice.dto.AppointmentDto;
import com.example.sessionservice.exception.ForbiddenOperationException;
import com.example.sessionservice.exception.ResourceNotFoundException;
import com.example.sessionservice.exception.ServiceUnavailableException;
import com.example.sessionservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

/**
 * Appels vers appointment-service :
 * - GET /appointments/{id}                         → valider le RDV
 * - PATCH /appointments/{id}/status?status=...    → marquer COMPLETED en fin de session
 *
 * Le JWT de l'utilisateur courant est toujours transmis pour que
 * appointment-service puisse vérifier l'appartenance au RDV.
 */
@Component
public class AppointmentClient {

    private static final Logger LOG = LoggerFactory.getLogger(AppointmentClient.class);

    private final RestTemplate restTemplate;
    private final String appointmentServiceUrl;

    public AppointmentClient(
            RestTemplate restTemplate,
            @Value("${services.appointment.url}") String appointmentServiceUrl
    ) {
        this.restTemplate = restTemplate;
        this.appointmentServiceUrl = appointmentServiceUrl;
    }

    @CircuitBreaker(name = "appointmentService")
    @Retry(name = "appointmentService", fallbackMethod = "fallbackGetAppointment")
    public AppointmentDto getAppointment(Long appointmentId) {
        HttpHeaders headers = authHeaders();
        try {
            return restTemplate.exchange(
                    appointmentServiceUrl + "/appointments/" + appointmentId,
                    HttpMethod.GET,
                    new HttpEntity<>(headers),
                    AppointmentDto.class
            ).getBody();
        } catch (HttpClientErrorException.NotFound ex) {
            throw new ResourceNotFoundException("Rendez-vous non trouvé");
        } catch (HttpClientErrorException.Forbidden ex) {
            throw new ForbiddenOperationException("Accès refusé à ce rendez-vous");
        } catch (RestClientException ex) {
            throw new ServiceUnavailableException("appointment-service indisponible", ex);
        }
    }

    @CircuitBreaker(name = "appointmentService")
    @Retry(name = "appointmentService")
    public void updateAppointmentStatus(Long appointmentId, String status) {
        HttpHeaders headers = authHeaders();
        try {
            restTemplate.exchange(
                    appointmentServiceUrl + "/appointments/" + appointmentId
                            + "/status?status=" + status,
                    HttpMethod.PUT,
                    new HttpEntity<>(headers),
                    Void.class
            );
        } catch (RestClientException ex) {
            // best-effort : si appointment-service est down, la session est quand même terminée
            LOG.warn("Impossible de mettre à jour le statut du RDV {} : {}", appointmentId, ex.getMessage());
        }
    }

    private HttpHeaders authHeaders() {
        HttpHeaders headers = new HttpHeaders();
        String auth = SecurityUtils.currentAuthorizationHeader();
        if (auth != null) headers.set("Authorization", auth);
        return headers;
    }

    private AppointmentDto fallbackGetAppointment(Long appointmentId, Throwable t) {
        if (t instanceof ResourceNotFoundException || t instanceof ForbiddenOperationException)
            throw (RuntimeException) t;
        LOG.warn("appointment-service indisponible pour le RDV {}", appointmentId, t);
        throw new ServiceUnavailableException(
                "Le service rendez-vous est temporairement indisponible", t);
    }
}
