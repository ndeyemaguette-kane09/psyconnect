package com.example.userservice.service.impl;

import com.example.userservice.client.AuthServiceClient;
import com.example.userservice.client.NotificationClient;
import com.example.userservice.dto.CreatePatientProfileRequest;
import com.example.userservice.dto.PatientProfileResponse;
import com.example.userservice.dto.WalletResponse;
import com.example.userservice.dto.WalletTransactionResponse;
import com.example.userservice.entity.PatientProfile;
import com.example.userservice.entity.UserProfile;
import com.example.userservice.entity.WalletTransaction;
import com.example.userservice.entity.WalletTransactionType;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.repository.UserProfileRepository;
import com.example.userservice.repository.WalletTransactionRepository;
import com.example.userservice.service.PatientProfileService;

import org.springframework.stereotype.Service;

@Service
public class PatientProfileServiceImpl
        implements PatientProfileService {

    private final PatientProfileRepository
            patientProfileRepository;

    private final UserProfileRepository
            userProfileRepository;

    private final AuthServiceClient authServiceClient;

    private final NotificationClient notificationClient;

    private final WalletTransactionRepository walletTransactionRepository;

    public PatientProfileServiceImpl(
            PatientProfileRepository patientProfileRepository,
            UserProfileRepository userProfileRepository,
            AuthServiceClient authServiceClient,
            NotificationClient notificationClient,
            WalletTransactionRepository walletTransactionRepository
    ) {

        this.patientProfileRepository =
                patientProfileRepository;

        this.userProfileRepository =
                userProfileRepository;

        this.authServiceClient = authServiceClient;

        this.notificationClient = notificationClient;

        this.walletTransactionRepository = walletTransactionRepository;
    }

    @Override
    public PatientProfileResponse createPatientProfile(
            CreatePatientProfileRequest request,
            Long callerAuthUserId
    ) {

        UserProfile userProfile =
                userProfileRepository.findByAuthUserId(
                        callerAuthUserId
                ).orElseThrow(() ->
                        new ResourceNotFoundException(
                                "User profile not found"
                        )
                );

        PatientProfile patientProfile =
                new PatientProfile();

        patientProfile.setUserProfile(
                userProfile
        );

        patientProfile.setAuthUserId(
                userProfile.getAuthUserId()
        );

        patientProfile.setEmergencyContactName(
                request.getEmergencyContactName()
        );

        patientProfile.setEmergencyContactPhone(
                request.getEmergencyContactPhone()
        );

        patientProfile.setMedicalHistory(
                request.getMedicalHistory()
        );

        patientProfile.setPreferredLanguage(
                request.getPreferredLanguage()
        );

        patientProfile.setAnonymousMode(
                request.getAnonymousMode()
        );

        PatientProfile savedProfile =
                patientProfileRepository.save(
                        patientProfile
                );

        userProfile.setProfileCompleted(true);

        userProfileRepository.save(userProfile);

        return mapToResponse(savedProfile);
    }

    @Override
    public PatientProfileResponse getPatientProfile(
            Long id,
            Long callerAuthUserId,
            boolean callerIsPsychologist,
            boolean callerIsAdmin
    ) {

        PatientProfile patientProfile =
                patientProfileRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Patient profile not found"
                                )
                        );

        boolean isOwner = patientProfile.getAuthUserId() != null
                && patientProfile.getAuthUserId().equals(callerAuthUserId);

        // Propriétaire, psychologue ou administrateur peuvent lire la fiche
        if (!isOwner && !callerIsPsychologist && !callerIsAdmin) {
            throw new ForbiddenOperationException(
                    "Ce profil patient ne vous appartient pas"
            );
        }

        PatientProfileResponse response = mapToResponse(patientProfile);

        // Mode anonyme : masque le nom réel côté psychologue uniquement
        // (l'admin garde une vue complète pour la modération).
        if (!isOwner
                && callerIsPsychologist
                && Boolean.TRUE.equals(patientProfile.getAnonymousMode())) {

            String pseudo = authServiceClient.getPseudo(
                    patientProfile.getAuthUserId()
            );

            response.setFirstName(
                    pseudo != null ? pseudo : "Patient anonyme"
            );
            response.setLastName("");
        }

        return response;
    }

    @Override
    public PatientProfileResponse getPatientProfileByAuthUserId(
            Long authUserId,
            Long callerAuthUserId
    ) {

        if (!authUserId.equals(callerAuthUserId)) {
            throw new ForbiddenOperationException(
                    "Ce profil patient ne vous appartient pas"
            );
        }

        PatientProfile patientProfile =
                patientProfileRepository.findByAuthUserId(authUserId)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Patient profile not found"
                                )
                        );

        return mapToResponse(patientProfile);
    }

    @Override
    public PatientProfileResponse updatePatientProfile(
            Long id,
            CreatePatientProfileRequest request,
            Long callerAuthUserId
    ) {

        PatientProfile patientProfile =
                patientProfileRepository.findById(id)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Patient profile not found"
                                )
                        );

        checkOwnership(patientProfile, callerAuthUserId);

        patientProfile.setEmergencyContactName(
                request.getEmergencyContactName()
        );

        patientProfile.setEmergencyContactPhone(
                request.getEmergencyContactPhone()
        );

        patientProfile.setMedicalHistory(
                request.getMedicalHistory()
        );

        patientProfile.setPreferredLanguage(
                request.getPreferredLanguage()
        );

        patientProfile.setAnonymousMode(
                request.getAnonymousMode()
        );

        PatientProfile updatedProfile =
                patientProfileRepository.save(
                        patientProfile
                );

        return mapToResponse(updatedProfile);
    }

    @Override
    public java.util.List<PatientProfileResponse> getAllPatientsForAdmin() {

        return patientProfileRepository.findAll()
                .stream()
                .map(this::mapToResponse)
                .collect(java.util.stream.Collectors.toList());
    }

    private void checkOwnership(PatientProfile patientProfile, Long callerAuthUserId) {

        if (patientProfile.getAuthUserId() == null
                || !patientProfile.getAuthUserId().equals(callerAuthUserId)) {
            throw new ForbiddenOperationException(
                    "Ce profil patient ne vous appartient pas"
            );
        }
    }

    @Override
    public WalletResponse getWallet(Long patientId, Long callerAuthUserId) {

        PatientProfile patientProfile = findOwnedPatientProfile(patientId, callerAuthUserId);

        return mapToWalletResponse(patientProfile);
    }

    @Override
    public WalletResponse depositToWallet(
            Long patientId, Double amount, String method, Long callerAuthUserId
    ) {

        validatePositiveAmount(amount);

        PatientProfile patientProfile = findOwnedPatientProfile(patientId, callerAuthUserId);

        double newBalance = currentBalance(patientProfile) + amount;
        patientProfile.setWalletBalance(newBalance);
        patientProfileRepository.save(patientProfile);

        recordTransaction(
                patientProfile, WalletTransactionType.DEPOSIT, amount, newBalance, method
        );

        notificationClient.send(
                patientId,
                "Recharge effectuée",
                "Votre solde PsyConnect a été rechargé de " + formatAmount(amount)
                        + " F CFA" + (method != null ? " via " + method : "")
                        + ". Nouveau solde : " + formatAmount(newBalance) + " F CFA.",
                "PAYMENT",
                "PATIENT"
        );

        return mapToWalletResponse(patientProfile);
    }

    @Override
    public WalletResponse withdrawFromWallet(
            Long patientId, Double amount, String method, Long callerAuthUserId
    ) {

        validatePositiveAmount(amount);

        PatientProfile patientProfile = findOwnedPatientProfile(patientId, callerAuthUserId);

        double balance = currentBalance(patientProfile);
        if (balance < amount) {
            throw new RuntimeException(
                    "Solde PsyConnect insuffisant pour ce retrait (solde actuel : "
                            + formatAmount(balance) + " F CFA)"
            );
        }

        double newBalance = balance - amount;
        patientProfile.setWalletBalance(newBalance);
        patientProfileRepository.save(patientProfile);

        recordTransaction(
                patientProfile, WalletTransactionType.WITHDRAWAL, amount, newBalance, method
        );

        notificationClient.send(
                patientId,
                "Retrait effectué",
                formatAmount(amount) + " F CFA ont été retirés de votre solde "
                        + "PsyConnect" + (method != null ? " vers " + method : "")
                        + ". Nouveau solde : " + formatAmount(newBalance) + " F CFA.",
                "PAYMENT",
                "PATIENT"
        );

        return mapToWalletResponse(patientProfile);
    }

    @Override
    public WalletResponse debitWallet(Long patientId, Double amount, Long callerAuthUserId) {

        validatePositiveAmount(amount);

        PatientProfile patientProfile = findOwnedPatientProfile(patientId, callerAuthUserId);

        double balance = currentBalance(patientProfile);
        if (balance < amount) {
            throw new RuntimeException(
                    "Solde PsyConnect insuffisant pour ce paiement (solde actuel : "
                            + formatAmount(balance) + " F CFA). Rechargez votre solde "
                            + "avant de payer ce rendez-vous."
            );
        }

        double newBalance = balance - amount;
        patientProfile.setWalletBalance(newBalance);
        patientProfileRepository.save(patientProfile);

        recordTransaction(
                patientProfile, WalletTransactionType.DEBIT, amount, newBalance, null
        );

        return mapToWalletResponse(patientProfile);
    }

    @Override
    public WalletResponse creditWallet(Long patientId, Double amount, Long callerAuthUserId) {

        validatePositiveAmount(amount);

        PatientProfile patientProfile = findOwnedPatientProfile(patientId, callerAuthUserId);

        double newBalance = currentBalance(patientProfile) + amount;
        patientProfile.setWalletBalance(newBalance);
        patientProfileRepository.save(patientProfile);

        recordTransaction(
                patientProfile, WalletTransactionType.CREDIT, amount, newBalance, null
        );

        return mapToWalletResponse(patientProfile);
    }

    @Override
    public java.util.List<WalletTransactionResponse> getWalletTransactions(
            Long patientId, Long callerAuthUserId
    ) {

        PatientProfile patientProfile = findOwnedPatientProfile(patientId, callerAuthUserId);

        return walletTransactionRepository
                .findByPatientProfileIdOrderByCreatedAtDesc(patientProfile.getId())
                .stream()
                .map(this::mapToTransactionResponse)
                .collect(java.util.stream.Collectors.toList());
    }

    private void recordTransaction(
            PatientProfile patientProfile,
            WalletTransactionType type,
            double amount,
            double balanceAfter,
            String method
    ) {

        WalletTransaction transaction = new WalletTransaction();
        transaction.setPatientProfile(patientProfile);
        transaction.setType(type);
        transaction.setAmount(amount);
        transaction.setBalanceAfter(balanceAfter);
        transaction.setMethod(method);

        walletTransactionRepository.save(transaction);
    }

    private WalletTransactionResponse mapToTransactionResponse(WalletTransaction transaction) {

        WalletTransactionResponse response = new WalletTransactionResponse();
        response.setId(transaction.getId());
        response.setType(transaction.getType().name());
        response.setAmount(transaction.getAmount());
        response.setBalanceAfter(transaction.getBalanceAfter());
        response.setMethod(transaction.getMethod());
        response.setCreatedAt(transaction.getCreatedAt());
        return response;
    }

    private PatientProfile findOwnedPatientProfile(Long patientId, Long callerAuthUserId) {

        PatientProfile patientProfile =
                patientProfileRepository.findById(patientId)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Patient profile not found"
                                )
                        );

        checkOwnership(patientProfile, callerAuthUserId);

        return patientProfile;
    }

    private double currentBalance(PatientProfile patientProfile) {
        return patientProfile.getWalletBalance() != null
                ? patientProfile.getWalletBalance()
                : 0.0;
    }

    private void validatePositiveAmount(Double amount) {
        if (amount == null || amount <= 0) {
            throw new RuntimeException("Le montant doit être supérieur à zéro");
        }
    }

    private String formatAmount(double amount) {
        return amount == Math.floor(amount)
                ? String.valueOf((long) amount)
                : String.valueOf(amount);
    }

    private WalletResponse mapToWalletResponse(PatientProfile patientProfile) {

        WalletResponse response = new WalletResponse();
        response.setPatientId(patientProfile.getId());
        response.setBalance(currentBalance(patientProfile));
        return response;
    }

    private PatientProfileResponse mapToResponse(
            PatientProfile patientProfile
    ) {

        PatientProfileResponse response =
                new PatientProfileResponse();

        response.setId(
                patientProfile.getId()
        );

        response.setFirstName(
                patientProfile
                        .getUserProfile()
                        .getFirstName()
        );

        response.setLastName(
                patientProfile
                        .getUserProfile()
                        .getLastName()
        );

        response.setProfilePicture(
                patientProfile
                        .getUserProfile()
                        .getProfilePicture()
        );

        response.setEmergencyContactName(
                patientProfile.getEmergencyContactName()
        );

        response.setEmergencyContactPhone(
                patientProfile.getEmergencyContactPhone()
        );

        response.setMedicalHistory(
                patientProfile.getMedicalHistory()
        );

        response.setPreferredLanguage(
                patientProfile.getPreferredLanguage()
        );

        response.setAnonymousMode(
                patientProfile.getAnonymousMode()
        );

        response.setAuthUserId(
                patientProfile.getAuthUserId()
        );

        return response;
    }
}