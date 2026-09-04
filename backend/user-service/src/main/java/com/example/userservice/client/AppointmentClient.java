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

    private boolean fallbackHasAppointment(Long psychologistId, Long patientId, Throwable t) {
        return false;
    }

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
