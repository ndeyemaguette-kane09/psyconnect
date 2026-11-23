package com.example.appointmentservice.dto;

import com.example.appointmentservice.entity.ConsultationType;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ChangeConsultationTypeRequest {

    @NotNull(message = "La modalité de consultation est obligatoire")
    private ConsultationType consultationType;
}
