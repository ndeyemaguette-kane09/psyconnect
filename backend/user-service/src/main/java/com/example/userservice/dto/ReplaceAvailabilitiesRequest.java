package com.example.userservice.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.List;

// ApiClient Flutter n'envoie que des objets JSON, d'où { "availabilities": [...] }
public class ReplaceAvailabilitiesRequest {

    @NotNull
    @Valid
    private List<AvailabilityRequest> availabilities;

    public List<AvailabilityRequest> getAvailabilities() {
        return availabilities;
    }

    public void setAvailabilities(List<AvailabilityRequest> availabilities) {
        this.availabilities = availabilities;
    }
}
