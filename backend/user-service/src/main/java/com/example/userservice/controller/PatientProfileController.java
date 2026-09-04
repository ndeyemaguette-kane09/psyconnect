package com.example.userservice.controller;

import com.example.userservice.dto.CreatePatientProfileRequest;
import com.example.userservice.dto.PatientProfileResponse;
import com.example.userservice.dto.WalletAmountRequest;
import com.example.userservice.dto.WalletResponse;
import com.example.userservice.dto.WalletTransactionResponse;
import com.example.userservice.service.PatientProfileService;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/patients")
public class PatientProfileController {

    private final PatientProfileService patientProfileService;

    public PatientProfileController(
            PatientProfileService patientProfileService
    ) {

        this.patientProfileService = patientProfileService;
    }

    @PostMapping
    public ResponseEntity<PatientProfileResponse>
    createPatientProfile(
            HttpServletRequest httpRequest,
            @RequestBody
            CreatePatientProfileRequest request
    ) {

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(
                        patientProfileService
                                .createPatientProfile(
                                        request,
                                        currentAuthUserId(httpRequest)
                                )
                );
    }

    @GetMapping("/{id}")
    public ResponseEntity<PatientProfileResponse>
    getPatientProfile(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {

        return ResponseEntity.ok(
                patientProfileService
                        .getPatientProfile(
                                id,
                                currentAuthUserId(httpRequest),
                                httpRequest.isUserInRole("PSYCHOLOGIST"),
                                httpRequest.isUserInRole("ADMIN")
                        )
        );
    }

    @GetMapping("/by-auth-user/{authUserId}")
    public ResponseEntity<PatientProfileResponse>
    getPatientProfileByAuthUserId(
            HttpServletRequest httpRequest,
            @PathVariable Long authUserId
    ) {

        return ResponseEntity.ok(
                patientProfileService
                        .getPatientProfileByAuthUserId(
                                authUserId,
                                currentAuthUserId(httpRequest)
                        )
        );
    }

    @PutMapping("/{id}")
    public ResponseEntity<PatientProfileResponse>
    updatePatientProfile(
            HttpServletRequest httpRequest,
            @PathVariable Long id,

            @RequestBody
            CreatePatientProfileRequest request
    ) {

        return ResponseEntity.ok(
                patientProfileService
                        .updatePatientProfile(
                                id,
                                request,
                                currentAuthUserId(httpRequest)
                        )
        );
    }

    @GetMapping("/{id}/wallet")
    public ResponseEntity<WalletResponse> getWallet(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(
                patientProfileService.getWallet(id, currentAuthUserId(httpRequest))
        );
    }

    @PostMapping("/{id}/wallet/deposit")
    public ResponseEntity<WalletResponse> depositToWallet(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestBody WalletAmountRequest request
    ) {
        return ResponseEntity.ok(
                patientProfileService.depositToWallet(
                        id, request.getAmount(), request.getMethod(),
                        currentAuthUserId(httpRequest)
                )
        );
    }

    @PostMapping("/{id}/wallet/withdraw")
    public ResponseEntity<WalletResponse> withdrawFromWallet(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestBody WalletAmountRequest request
    ) {
        return ResponseEntity.ok(
                patientProfileService.withdrawFromWallet(
                        id, request.getAmount(), request.getMethod(),
                        currentAuthUserId(httpRequest)
                )
        );
    }

    @PostMapping("/{id}/wallet/debit")
    public ResponseEntity<WalletResponse> debitWallet(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestBody WalletAmountRequest request
    ) {
        return ResponseEntity.ok(
                patientProfileService.debitWallet(
                        id, request.getAmount(), currentAuthUserId(httpRequest)
                )
        );
    }

    @PostMapping("/{id}/wallet/credit")
    public ResponseEntity<WalletResponse> creditWallet(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestBody WalletAmountRequest request
    ) {
        return ResponseEntity.ok(
                patientProfileService.creditWallet(
                        id, request.getAmount(), currentAuthUserId(httpRequest)
                )
        );
    }

    @GetMapping("/{id}/wallet/transactions")
    public ResponseEntity<java.util.List<WalletTransactionResponse>> getWalletTransactions(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(
                patientProfileService.getWalletTransactions(
                        id, currentAuthUserId(httpRequest)
                )
        );
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
