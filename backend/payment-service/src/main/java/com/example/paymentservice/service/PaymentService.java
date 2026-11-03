package com.example.paymentservice.service;

import java.math.BigDecimal;
import java.util.List;

import com.example.paymentservice.dto.CreatePaymentRequest;
import com.example.paymentservice.dto.PaymentResponse;
import com.example.paymentservice.dto.PaymentTransactionDto;
import com.example.paymentservice.dto.PsychologistRevenueResponse;
import com.example.paymentservice.dto.PsychologistWalletResponse;
import com.example.paymentservice.dto.WithdrawalResponse;

public interface PaymentService {

    PaymentResponse createPayment(CreatePaymentRequest request);

    PaymentResponse getPaymentById(Long id);

    List<PaymentResponse> getPaymentsByAppointmentId(Long appointmentId);

    PsychologistRevenueResponse getPsychologistRevenue(Long psychologistId);

    // portefeuille du psy : solde dispo + historique retraits
    PsychologistWalletResponse getPsychologistWallet(Long psychologistId);

    // retrait simulé : enregistre le mouvement sans vrai virement
    WithdrawalResponse withdraw(Long psychologistId, BigDecimal amount, String method);

    List<PaymentResponse> getAllPaymentsForAdmin();

    // patientId fourni par l'appelant (appointment-service connaît déjà
    // le patient du rendez-vous, pas besoin d'aller le rechercher)
    BigDecimal refundCompletedPayments(Long appointmentId, Long patientId);

    // paiements reçus par un psy, du plus récent au plus ancien
    List<PaymentTransactionDto> getTransactionsByPsychologistId(Long psychologistId);
}
