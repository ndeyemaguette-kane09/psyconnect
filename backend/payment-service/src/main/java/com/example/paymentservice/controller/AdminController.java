package com.example.paymentservice.controller;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.paymentservice.dto.PaymentAdminStatsResponse;
import com.example.paymentservice.dto.PaymentResponse;
import com.example.paymentservice.dto.PlatformSettingsResponse;
import com.example.paymentservice.entity.PaymentStatus;
import com.example.paymentservice.entity.PlatformSettings;
import com.example.paymentservice.repository.PaymentRepository;
import com.example.paymentservice.repository.PlatformSettingsRepository;
import com.example.paymentservice.service.PaymentService;

// Routes admin : paiements, commission, statistiques (sans vérification de propriété)
// Les routes admin rendez-vous restent côté appointment-service
@RestController
@RequestMapping("/admin")
public class AdminController {

    private final PaymentService paymentService;
    private final PaymentRepository paymentRepository;
    private final PlatformSettingsRepository platformSettingsRepository;

    // Une seule ligne de réglages, créée à la volée si elle n'existe pas
    private static final Long SETTINGS_ID = 1L;

    public AdminController(
            PaymentService paymentService,
            PaymentRepository paymentRepository,
            PlatformSettingsRepository platformSettingsRepository
    ) {
        this.paymentService = paymentService;
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

    // taux de commission actuel de la plateforme
    @GetMapping("/platform-settings")
    public ResponseEntity<PlatformSettingsResponse> getPlatformSettings() {
        PlatformSettings settings = getOrCreateSettings();
        PlatformSettingsResponse response = new PlatformSettingsResponse();
        response.setCommissionRatePercent(settings.getCommissionRatePercent());
        return ResponseEntity.ok(response);
    }

    // change le taux de commission, entre 0 et 100
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

    @GetMapping("/payments")
    public ResponseEntity<List<PaymentResponse>> listPayments() {
        return ResponseEntity.ok(paymentService.getAllPaymentsForAdmin());
    }

    // /stats/payments, le front fusionne avec /admin/stats/appointments
    // (appointment-service) pour reconstituer l'écran statistiques complet
    @GetMapping("/stats/payments")
    public ResponseEntity<PaymentAdminStatsResponse> getStats() {

        PaymentAdminStatsResponse stats = new PaymentAdminStatsResponse();

        stats.setTotalPayments(paymentRepository.count());
        stats.setCompletedPayments(paymentRepository.countByStatus(PaymentStatus.COMPLETED));

        BigDecimal totalRevenue = paymentRepository.findByStatus(PaymentStatus.COMPLETED)
                .stream()
                .map(payment -> payment.getAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        stats.setTotalRevenue(totalRevenue);

        // calculé avec le taux actuel, pas en dur
        BigDecimal commissionRatePercent = getOrCreateSettings().getCommissionRatePercent();
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
