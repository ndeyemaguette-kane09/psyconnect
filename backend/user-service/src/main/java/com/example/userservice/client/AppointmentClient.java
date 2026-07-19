package com.example.userservice.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import com.example.userservice.security.SecurityUtils;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;

// Vérifie qu'un psychologue a déjà eu au moins un rendez-vous avec un patient
// donne, avant de lui ouvrir l'acces aux antecedents medicaux de ce patient
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

    // Endpoint dédié inter-service : pas de contrôle de rôle côté appointment-service,
    // on evite le 403 qui se produisait quand le psy appelait /appointments/patient/{id}
    // (endpoint reserve au patient) pour verifier sa relation avec le patient.
    @CircuitBreaker(name = "appointmentService")
    @Retry(name = "appointmentService", fallbackMethod = "fallbackHasAppointment")
    public boolean hasAppointmentBetween(Long psychologistId, Long patientId) {

        HttpHeaders headers = new HttpHeaders();
        String authorization = SecurityUtils.currentAuthorizationHeader();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        Boolean result = restTemplate.exchange(
                appointmentServiceUrl + "/appointments/exists/between"
                        + "?psychologistId=" + psychologistId
                        + "&patientId=" + patientId,
                HttpMethod.GET,
                new HttpEntity<>(headers),
                Boolean.class
        ).getBody();

        return Boolean.TRUE.equals(result);
    }

    // appointment-service indisponible : on refuse prudemment l'acces plutot
    // que de l'accorder par defaut, donnees medicales sensibles
    private boolean fallbackHasAppointment(Long psychologistId, Long patientId, Throwable t) {
        return false;
    }

    // pareil que hasAppointmentBetween, mais exige un rendez-vous COMPLETED :
    // un patient ne peut noter un psy qu'apres avoir reellement eu une seance.
    // Utilise le même endpoint inter-service dédié, avec le filtre completed.
    @CircuitBreaker(name = "appointmentService")
    @Retry(name = "appointmentService", fallbackMethod = "fallbackHasCompletedAppointment")
    public boolean hasCompletedAppointmentBetween(Long psychologistId, Long patientId) {

        HttpHeaders headers = new HttpHeaders();
        String authorization = SecurityUtils.currentAuthorizationHeader();
        if (authorization != null) {
            headers.set("Authorization", authorization);
        }

        Boolean result = restTemplate.exchange(
                appointmentServiceUrl + "/appointments/exists/between"
                        + "?psychologistId=" + psychologistId
                        + "&patientId=" + patientId
                        + "&requireCompleted=true",
                HttpMethod.GET,
                new HttpEntity<>(headers),
                Boolean.class
        ).getBody();

        return Boolean.TRUE.equals(result);
    }

    private boolean fallbackHasCompletedAppointment(Long psychologistId, Long patientId, Throwable t) {
        return false;
    }
}
