package com.example.userservice.service;

import com.example.userservice.dto.PatientProfileResponse;
import com.example.userservice.dto.CreatePatientProfileRequest;
import com.example.userservice.dto.WalletResponse;
import com.example.userservice.dto.WalletTransactionResponse;

public interface PatientProfileService {

    PatientProfileResponse createPatientProfile(
            CreatePatientProfileRequest request,
            Long callerAuthUserId
    );

    /**
     * @param callerIsPsychologist true si l'appelant a le rôle PSYCHOLOGIST
     *                             (autorise la lecture même sans être le
     *                             propriétaire du profil ; déclenche le
     *                             masquage du nom réel si mode anonyme).
     * @param callerIsAdmin        true si l'appelant a le rôle ADMIN
     *                             (autorise la lecture, jamais de masquage :
     *                             l'admin garde toujours la vraie identité).
     */
    PatientProfileResponse getPatientProfile(
            Long id,
            Long callerAuthUserId,
            boolean callerIsPsychologist,
            boolean callerIsAdmin
    );

    PatientProfileResponse getPatientProfileByAuthUserId(
            Long authUserId,
            Long callerAuthUserId
    );

    PatientProfileResponse updatePatientProfile(
            Long id,
            CreatePatientProfileRequest request,
            Long callerAuthUserId
    );

    // Admin uniquement : liste tous les patients sans vérification de propriété
    java.util.List<PatientProfileResponse> getAllPatientsForAdmin();

    // lecture du solde, proprietaire uniquement
    WalletResponse getWallet(Long patientId, Long callerAuthUserId);

    // Dépôt effectué par le patient lui-même
    WalletResponse depositToWallet(
            Long patientId, Double amount, String method, Long callerAuthUserId
    );

    // Retrait simulé, inverse du dépôt. Échoue si le solde est insuffisant
    WalletResponse withdrawFromWallet(
            Long patientId, Double amount, String method, Long callerAuthUserId
    );

    // Débite pour payer un rendez-vous, échoue si le solde est insuffisant
    WalletResponse debitWallet(Long patientId, Double amount, Long callerAuthUserId);

    // credite quand un RDV est remboursé
    WalletResponse creditWallet(Long patientId, Double amount, Long callerAuthUserId);

    // relevé des mouvements, plus recent en premier, proprietaire uniquement
    java.util.List<WalletTransactionResponse> getWalletTransactions(
            Long patientId, Long callerAuthUserId
    );
}