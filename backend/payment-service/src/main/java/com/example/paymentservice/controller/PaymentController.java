package com.example.paymentservice.controller;

import java.math.BigDecimal;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.paymentservice.dto.CreatePaymentRequest;
import com.example.paymentservice.dto.PaymentResponse;
import com.example.paymentservice.dto.PaymentTransactionDto;
import com.example.paymentservice.dto.PsychologistRevenueResponse;
import com.example.paymentservice.dto.PsychologistWalletResponse;
import com.example.paymentservice.dto.WithdrawalResponse;
import com.example.paymentservice.service.PaymentService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/payments")
public class PaymentController {

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
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

    // revenu brut + net d'un psy, total et du mois en cours
    @GetMapping("/psychologist/{psychologistId}/revenue")
    public ResponseEntity<PsychologistRevenueResponse> getPsychologistRevenue(
            @PathVariable Long psychologistId
    ) {
        return ResponseEntity.ok(paymentService.getPsychologistRevenue(psychologistId));
    }

    // portefeuille du psy : solde disponible + historique des retraits
    @GetMapping("/psychologist/{psychologistId}/wallet")
    public ResponseEntity<PsychologistWalletResponse> getPsychologistWallet(
            @PathVariable Long psychologistId
    ) {
        return ResponseEntity.ok(paymentService.getPsychologistWallet(psychologistId));
    }

    // retrait simulé : le psy demande à virer son solde vers un compte externe
    // method : ORANGE_MONEY | WAVE | BANK_TRANSFER
    @PostMapping("/psychologist/{psychologistId}/withdraw")
    public ResponseEntity<WithdrawalResponse> withdraw(
            @PathVariable Long psychologistId,
            @RequestParam BigDecimal amount,
            @RequestParam String method
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(paymentService.withdraw(psychologistId, amount, method));
    }

    // historique détaillé des paiements reçus : 1 ligne = 1 RDV payé ou remboursé
    // le pseudo du patient est résolu côté Flutter (GET /patients/{id})
    @GetMapping("/psychologist/{psychologistId}/transactions")
    public ResponseEntity<List<PaymentTransactionDto>> getTransactionsByPsychologistId(
            @PathVariable Long psychologistId
    ) {
        return ResponseEntity.ok(paymentService.getTransactionsByPsychologistId(psychologistId));
    }

    // appelé par appointment-service après une annulation à +48h du RDV ;
    // patientId est fourni par l'appelant qui le connaît déjà
    @PostMapping("/appointment/{appointmentId}/refund")
    public ResponseEntity<BigDecimal> refundCompletedPayments(
            @PathVariable Long appointmentId,
            @RequestParam Long patientId
    ) {
        return ResponseEntity.ok(
                paymentService.refundCompletedPayments(appointmentId, patientId)
        );
    }
}
