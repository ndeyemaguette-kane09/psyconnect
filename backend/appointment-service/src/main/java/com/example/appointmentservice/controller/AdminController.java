package com.example.appointmentservice.controller;

import com.example.appointmentservice.dto.AdminStatsResponse;
import com.example.appointmentservice.dto.AppointmentResponse;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.service.AppointmentService;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

// Routes admin pour les rendez-vous, sans vérification de propriété
// paiements/commission/stats paiement -> payment-service (GET /admin/payments,
// /admin/platform-settings, /admin/stats/payments)
@RestController
@RequestMapping("/admin")
public class AdminController {

    private final AppointmentService appointmentService;
    private final AppointmentRepository appointmentRepository;

    public AdminController(
            AppointmentService appointmentService,
            AppointmentRepository appointmentRepository
    ) {
        this.appointmentService = appointmentService;
        this.appointmentRepository = appointmentRepository;
    }

    @GetMapping("/appointments")
    public ResponseEntity<List<AppointmentResponse>> listAppointments(
            @RequestParam(required = false) String status
    ) {
        return ResponseEntity.ok(
                appointmentService.getAllAppointmentsForAdmin(status)
        );
    }

    // /stats/appointments, le front fusionne avec /admin/stats/payments
    // (payment-service) pour reconstituer l'écran statistiques complet
    @GetMapping("/stats/appointments")
    public ResponseEntity<AdminStatsResponse> getStats() {

        AdminStatsResponse stats = new AdminStatsResponse();

        stats.setTotalAppointments(appointmentRepository.count());
        stats.setPendingAppointments(
                appointmentRepository.countByStatus(AppointmentStatus.PENDING)
        );
        stats.setConfirmedAppointments(
                appointmentRepository.countByStatus(AppointmentStatus.CONFIRMED)
        );
        stats.setCompletedAppointments(
                appointmentRepository.countByStatus(AppointmentStatus.COMPLETED)
        );
        stats.setCancelledAppointments(
                appointmentRepository.countByStatus(AppointmentStatus.CANCELLED)
        );
        stats.setRejectedAppointments(
                appointmentRepository.countByStatus(AppointmentStatus.REJECTED)
        );

        return ResponseEntity.ok(stats);
    }
}
