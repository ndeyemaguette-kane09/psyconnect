package com.example.userservice.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.List;

// wrapper pour PUT /psychologists/{id}/availabilities
// ApiClient Flutter encode toujours un objet JSON (Map), pas un tableau nu.
// On enveloppe donc la liste dans { "availabilities": [...] }.
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
