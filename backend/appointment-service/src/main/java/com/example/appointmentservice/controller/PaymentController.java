package com.example.appointmentservice.controller;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.appointmentservice.dto.CreatePaymentRequest;
import com.example.appointmentservice.dto.PaymentResponse;
import com.example.appointmentservice.dto.PsychologistRevenueResponse;
import com.example.appointmentservice.entity.Payment;
import com.example.appointmentservice.entity.PaymentStatus;
import com.example.appointmentservice.entity.PlatformSettings;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.PaymentRepository;
import com.example.appointmentservice.repository.PlatformSettingsRepository;
import com.example.appointmentservice.service.PaymentService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/payments")
public class PaymentController {

    private final PaymentService paymentService;
    private final PaymentRepository paymentRepository;
    private final AppointmentRepository appointmentRepository;
    private final PlatformSettingsRepository platformSettingsRepository;

    /** Une seule ligne de réglages en base — même id fixe que AdminController. */
    private static final Long SETTINGS_ID = 1L;

    public PaymentController(
            PaymentService paymentService,
            PaymentRepository paymentRepository,
            AppointmentRepository appointmentRepository,
            PlatformSettingsRepository platformSettingsRepository
    ) {
        this.paymentService = paymentService;
        this.paymentRepository = paymentRepository;
        this.appointmentRepository = appointmentRepository;
        this.platformSettingsRepository = platformSettingsRepository;
    }

    @PostMapping
    public ResponseEntity<PaymentResponse> createPayment(
            @Valid @RequestBody CreatePaymentRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(paymentService.createPayment(request));
    }

    @GetMapping("/{id}")
    public ResponseEntity<PaymentResponse> getPaymentById(
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(paymentService.getPaymentById(id));
    }

    @GetMapping("/appointment/{appointmentId}")
    public ResponseEntity<List<PaymentResponse>> getPaymentsByAppointmentId(
            @PathVariable Long appointmentId
    ) {
        return ResponseEntity.ok(
                paymentService.getPaymentsByAppointmentId(appointmentId)
        );
    }

    // Revenu (brut + net) d'un psychologue, total et sur le mois en cours.
    // Même convention que GET /appointments/psychologist/{id} : l'id est
    // passé en chemin, pas déduit du JWT.
    @GetMapping("/psychologist/{psychologistId}/revenue")
    public ResponseEntity<PsychologistRevenueResponse> getPsychologistRevenue(
            @PathVariable Long psychologistId
    ) {
        List<Long> appointmentIds = appointmentRepository
                .findByPsychologistId(psychologistId)
                .stream()
                .map(appointment -> appointment.getId())
                .collect(Collectors.toList());

        List<Payment> completedPayments = appointmentIds.isEmpty()
                ? List.of()
                : paymentRepository.findByAppointmentIdInAndStatus(
                        appointmentIds, PaymentStatus.COMPLETED
                );

        BigDecimal totalGross = completedPayments.stream()
                .map(Payment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        YearMonth currentMonth = YearMonth.now();
        BigDecimal monthGross = completedPayments.stream()
                .filter(payment -> payment.getCreatedAt() != null
                        && YearMonth.from(payment.getCreatedAt()).equals(currentMonth))
                .map(Payment::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal commissionRatePercent = getOrCreateSettings()
                .getCommissionRatePercent();

        PsychologistRevenueResponse response = new PsychologistRevenueResponse();
        response.setCommissionRatePercent(commissionRatePercent);
        response.setTotalGrossRevenue(totalGross);
        response.setTotalNetRevenue(
                applyCommission(totalGross, commissionRatePercent)
        );
        response.setCurrentMonthGrossRevenue(monthGross);
        response.setCurrentMonthNetRevenue(
                applyCommission(monthGross, commissionRatePercent)
        );

        return ResponseEntity.ok(response);
    }

    /** Revenu net = brut - commission plateforme, même calcul que AdminController. */
    private BigDecimal applyCommission(BigDecimal gross, BigDecimal commissionRatePercent) {
        BigDecimal commission = gross
                .multiply(commissionRatePercent)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        return gross.subtract(commission);
    }

    private PlatformSettings getOrCreateSettings() {
        return platformSettingsRepository.findById(SETTINGS_ID)
                .orElseGet(() -> {
                    PlatformSettings settings = new PlatformSettings();
                    settings.setId(SETTINGS_ID);
                    return platformSettingsRepository.save(settings);
                });
    }
}
