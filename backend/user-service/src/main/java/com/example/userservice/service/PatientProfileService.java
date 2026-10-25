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

    WalletResponse creditWalletAsService(Long patientId, Double amount);

    // relevé des mouvements, plus recent en premier, proprietaire uniquement
    java.util.List<WalletTransactionResponse> getWalletTransactions(
            Long patientId, Long callerAuthUserId
    );
}