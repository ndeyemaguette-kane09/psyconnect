package com.example.appointmentservice.controller;

import com.example.appointmentservice.dto.AdminStatsResponse;
import com.example.appointmentservice.dto.AppointmentResponse;
import com.example.appointmentservice.dto.PaymentResponse;
import com.example.appointmentservice.dto.PlatformSettingsResponse;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.PaymentStatus;
import com.example.appointmentservice.entity.PlatformSettings;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.PaymentRepository;
import com.example.appointmentservice.repository.PlatformSettingsRepository;
import com.example.appointmentservice.service.AppointmentService;
import com.example.appointmentservice.service.PaymentService;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/**
 * Endpoints réservés au rôle ADMIN : vue globale des rendez-vous et des
 * paiements (sans contrôle de propriété), statistiques. Protégés par
 * {@code SecurityConfig} : {@code /admin/**} exige {@code hasRole("ADMIN")}.
 */
@RestController
@RequestMapping("/admin")
public class AdminController {

    private final AppointmentService appointmentService;
    private final PaymentService paymentService;
    private final AppointmentRepository appointmentRepository;
    private final PaymentRepository paymentRepository;
    private final PlatformSettingsRepository platformSettingsRepository;

    /** Une seule ligne de réglages en base — id fixe, créée à la volée. */
    private static final Long SETTINGS_ID = 1L;

    public AdminController(
            AppointmentService appointmentService,
            PaymentService paymentService,
            AppointmentRepository appointmentRepository,
            PaymentRepository paymentRepository,
            PlatformSettingsRepository platformSettingsRepository
    ) {
        this.appointmentService = appointmentService;
        this.paymentService = paymentService;
        this.appointmentRepository = appointmentRepository;
        this.paymentRepository = paymentRepository;
        this.platformSettingsRepository = platformSettingsRepository;
    }

    private PlatformSettings getOrCreateSettings() {
        return platformSettingsRepository.findById(SETTINGS_ID)
                .orElseGet(() -> {
                    PlatformSettings settings = new PlatformSettings();
                    settings.setId(SETTINGS_ID);
                    return platformSettingsRepository.save(settings);
                });
    }

    /**
     * Réservé à l'ADMIN : consulte le taux de commission actuel de la
     * plateforme.
     */
    @GetMapping("/platform-settings")
    public ResponseEntity<PlatformSettingsResponse> getPlatformSettings() {
        PlatformSettings settings = getOrCreateSettings();
        PlatformSettingsResponse response = new PlatformSettingsResponse();
        response.setCommissionRatePercent(settings.getCommissionRatePercent());
        return ResponseEntity.ok(response);
    }

    /**
     * Réservé à l'ADMIN : règle le taux de commission (0 à 100) prélevé sur
     * chaque paiement réussi — surfacé dans l'onglet Config du frontend.
     */
    @PutMapping("/platform-settings/commission-rate")
    public ResponseEntity<PlatformSettingsResponse> setCommissionRate(
            @RequestParam BigDecimal commissionRatePercent
    ) {
        if (commissionRatePercent.compareTo(BigDecimal.ZERO) < 0
                || commissionRatePercent.compareTo(new BigDecimal("100")) > 0) {
            throw new IllegalArgumentException(
                    "commissionRatePercent doit être compris entre 0 et 100"
            );
        }

        PlatformSettings settings = getOrCreateSettings();
        settings.setCommissionRatePercent(commissionRatePercent);
        PlatformSettings saved = platformSettingsRepository.save(settings);

        PlatformSettingsResponse response = new PlatformSettingsResponse();
        response.setCommissionRatePercent(saved.getCommissionRatePercent());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/appointments")
    public ResponseEntity<List<AppointmentResponse>> listAppointments(
            @RequestParam(required = false) String status
    ) {
        return ResponseEntity.ok(
                appointmentService.getAllAppointmentsForAdmin(status)
        );
    }

    @GetMapping("/payments")
    public ResponseEntity<List<PaymentResponse>> listPayments() {
        return ResponseEntity.ok(
                paymentService.getAllPaymentsForAdmin()
        );
    }

    // Renommé /stats -> /stats/appointments : auth-service et user-service
    // exposent chacun leur propre /admin/stats, ce qui rendrait le routage
    // gateway ambigu si les 3 chemins restaient identiques (cf. api-gateway
    // application.properties, routes admin-*).
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

        stats.setTotalPayments(paymentRepository.count());
        stats.setCompletedPayments(
                paymentRepository.countByStatus(PaymentStatus.COMPLETED)
        );

        BigDecimal totalRevenue = paymentRepository.findByStatus(PaymentStatus.COMPLETED)
                .stream()
                .map(payment -> payment.getAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        stats.setTotalRevenue(totalRevenue);

        // Part de revenus de l'administrateur : appliquée au taux de
        // commission courant (réglable via
        // PUT /admin/platform-settings/commission-rate), pas figée en dur.
        BigDecimal commissionRatePercent =
                getOrCreateSettings().getCommissionRatePercent();
        BigDecimal platformRevenue = totalRevenue
                .multiply(commissionRatePercent)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        BigDecimal psychologistRevenue = totalRevenue.subtract(platformRevenue);

        stats.setCommissionRatePercent(commissionRatePercent);
        stats.setPlatformRevenue(platformRevenue);
        stats.setPsychologistRevenue(psychologistRevenue);

        return ResponseEntity.ok(stats);
    }
}
