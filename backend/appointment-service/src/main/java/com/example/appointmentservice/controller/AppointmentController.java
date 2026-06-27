package com.example.appointmentservice.controller;

import com.example.appointmentservice.dto.AppointmentResponse;
import com.example.appointmentservice.dto.CreateAppointmentRequest;
import com.example.appointmentservice.dto.RescheduleAppointmentRequest;
import com.example.appointmentservice.service.AppointmentService;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/appointments")
public class AppointmentController {

    private final AppointmentService
            appointmentService;

    public AppointmentController(
            AppointmentService appointmentService
    ) {

        this.appointmentService =
                appointmentService;
    }

    @PostMapping
    public ResponseEntity<AppointmentResponse>
    createAppointment(
            @Valid @RequestBody
            CreateAppointmentRequest request
    ) {

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(
                        appointmentService
                                .createAppointment(request)
                );
    }

    @GetMapping("/{id}")
    public ResponseEntity<AppointmentResponse>
    getAppointmentById(
            @PathVariable Long id
    ) {

        return ResponseEntity.ok(
                appointmentService
                        .getAppointmentById(id)
        );
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<AppointmentResponse>
    updateAppointmentStatus(
            @PathVariable Long id,

            @RequestParam String status
    ) {

        return ResponseEntity.ok(
                appointmentService
                        .updateAppointmentStatus(
                                id,
                                status
                        )
        );
    }

    @PutMapping("/{id}/reschedule")
    public ResponseEntity<AppointmentResponse>
    rescheduleAppointment(
            @PathVariable Long id,

            @Valid @RequestBody
            RescheduleAppointmentRequest request
    ) {

        return ResponseEntity.ok(
                appointmentService
                        .rescheduleAppointment(id, request)
        );
    }

    @GetMapping("/psychologist/{id}")
    public ResponseEntity<List<AppointmentResponse>>
    getAppointmentsByPsychologistId(
            @PathVariable Long id
    ) {

        return ResponseEntity.ok(
                appointmentService
                        .getAppointmentsByPsychologistId(id)
        );
    }

    @GetMapping("/patient/{id}")
    public ResponseEntity<List<AppointmentResponse>>
    getAppointmentsByPatientId(
            @PathVariable Long id
    ) {

        return ResponseEntity.ok(
                appointmentService
                        .getAppointmentsByPatientId(id)
        );
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAppointment(
            @PathVariable Long id
    ) {

        appointmentService.deleteAppointment(id);

        return ResponseEntity.noContent().build();
    }
}
