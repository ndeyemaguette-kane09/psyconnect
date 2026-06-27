package com.example.appointmentservice.service;

import java.util.List;

import com.example.appointmentservice.dto.CreatePaymentRequest;
import com.example.appointmentservice.dto.PaymentResponse;

public interface PaymentService {

    PaymentResponse createPayment(CreatePaymentRequest request);

    PaymentResponse getPaymentById(Long id);

    List<PaymentResponse> getPaymentsByAppointmentId(Long appointmentId);

    /** Réservé à l'ADMIN : liste tous les paiements, sans contrôle de propriété. */
    List<PaymentResponse> getAllPaymentsForAdmin();

    /**
     * Marque comme REFUNDED tous les paiements COMPLETED liés à ce
     * rendez-vous et crédite le montant correspondant sur le solde
     * PsyConnect du patient (cf. WalletClient). Appelé par
     * AppointmentServiceImpl lors d'une annulation respectant le délai de
     * remboursement (plus de 48h avant le RDV). Ne fait rien s'il n'existe
     * aucun paiement COMPLETED, ce qui rend l'appel sûr même pour un
     * rendez-vous jamais payé.
     *
     * @return le montant total crédité (0 si rien à rembourser).
     */
    Double refundCompletedPayments(Long appointmentId);
}
