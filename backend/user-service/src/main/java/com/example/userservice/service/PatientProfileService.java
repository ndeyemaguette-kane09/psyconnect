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

    /** Réservé à l'ADMIN : liste tous les profils patients, sans contrôle de propriété. */
    java.util.List<PatientProfileResponse> getAllPatientsForAdmin();

    /** Lecture du solde PsyConnect — propriétaire uniquement. */
    WalletResponse getWallet(Long patientId, Long callerAuthUserId);

    /**
     * Dépôt simulé (Wave/Orange Money) vers le solde PsyConnect, initié par
     * le patient lui-même depuis l'écran "Mon solde".
     */
    WalletResponse depositToWallet(
            Long patientId, Double amount, String method, Long callerAuthUserId
    );

    /**
     * Retrait simulé du solde PsyConnect vers Wave/Orange Money — l'opération
     * inverse du dépôt. Échoue si le solde est insuffisant.
     */
    WalletResponse withdrawFromWallet(
            Long patientId, Double amount, String method, Long callerAuthUserId
    );

    /**
     * Débite le solde pour payer un rendez-vous — appelé par
     * appointment-service (le JWT relayé est celui du patient qui paie, donc
     * le contrôle de propriété s'applique de la même façon). Échoue si le
     * solde est insuffisant.
     */
    WalletResponse debitWallet(Long patientId, Double amount, Long callerAuthUserId);

    /**
     * Crédite le solde suite au remboursement d'un rendez-vous annulé —
     * appelé par appointment-service.
     */
    WalletResponse creditWallet(Long patientId, Double amount, Long callerAuthUserId);

    /**
     * Relevé des mouvements du solde PsyConnect (dépôts, retraits, débits,
     * crédits), du plus récent au plus ancien — propriétaire uniquement.
     */
    java.util.List<WalletTransactionResponse> getWalletTransactions(
            Long patientId, Long callerAuthUserId
    );
}