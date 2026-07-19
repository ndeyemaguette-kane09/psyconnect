package com.example.paymentservice.client;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import com.example.paymentservice.dto.AppointmentSummary;
import com.example.paymentservice.exception.ForbiddenOperationException;
import com.example.paymentservice.exception.ResourceNotFoundException;
import com.example.paymentservice.exception.ServiceUnavailableException;
import com.example.paymentservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

// appels vers appointment-service pour valider un RDV avant paiement / lister
// les RDV d'un psy pour calculer son revenu. Le JWT de l'appelant est relayé
// donc appointment-service refait ses propres controles d'ownership
@Component
public class AppointmentClient {

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
    @Retry(name = "appointmentService", fallbackMethod = "fallbackGetById")
    public AppointmentSummary getAppointmentById(Long appointmentId) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", SecurityUtils.currentAuthorizationHeader());

        return restTemplate.exchange(
                appointmentServiceUrl + "/appointments/" + appointmentId,
                HttpMethod.GET,
                new HttpEntity<>(headers),
                AppointmentSummary.class
        ).getBody();
    }

    @CircuitBreaker(name = "appointmentService")
    @Retry(name = "appointmentService", fallbackMethod = "fallbackGetByPsychologistId")
    public List<AppointmentSummary> getAppointmentsByPsychologistId(Long psychologistId) {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", SecurityUtils.currentAuthorizationHeader());

        AppointmentSummary[] result = restTemplate.exchange(
                appointmentServiceUrl + "/appointments/psychologist/" + psychologistId,
                HttpMethod.GET,
                new HttpEntity<>(headers),
                AppointmentSummary[].class
        ).getBody();

        return result == null ? List.of() : List.of(result);
    }

    private AppointmentSummary fallbackGetById(Long appointmentId, Exception ex) {
        if (ex instanceof HttpClientErrorException.NotFound) {
            throw new ResourceNotFoundException("Rendez-vous non trouvé");
        }
        if (ex instanceof HttpClientErrorException.Forbidden) {
            throw new ForbiddenOperationException("Accès refusé à ce rendez-vous");
        }
        throw new ServiceUnavailableException("Le service de rendez-vous est indisponible, réessayez plus tard", ex);
    }

    private List<AppointmentSummary> fallbackGetByPsychologistId(Long psychologistId, Exception ex) {
        if (ex instanceof HttpClientErrorException.Forbidden) {
            throw new ForbiddenOperationException("Accès refusé à ces rendez-vous");
        }
        throw new ServiceUnavailableException("Le service de rendez-vous est indisponible, réessayez plus tard", ex);
    }
}
