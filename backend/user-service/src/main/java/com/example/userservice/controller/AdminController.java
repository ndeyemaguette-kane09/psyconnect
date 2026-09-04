package com.example.userservice.controller;

import com.example.userservice.dto.AdminStatsResponse;
import com.example.userservice.dto.PatientProfileResponse;
import com.example.userservice.dto.PsychologistProfileResponse;
import com.example.userservice.repository.PatientProfileRepository;
import com.example.userservice.repository.PsychologistProfileRepository;
import com.example.userservice.service.PatientProfileService;
import com.example.userservice.service.PsychologistProfileService;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/admin")
public class AdminController {

    private final PsychologistProfileService psychologistProfileService;
    private final PatientProfileService patientProfileService;
    private final PsychologistProfileRepository psychologistProfileRepository;
    private final PatientProfileRepository patientProfileRepository;

    public AdminController(
            PsychologistProfileService psychologistProfileService,
            PatientProfileService patientProfileService,
            PsychologistProfileRepository psychologistProfileRepository,
            PatientProfileRepository patientProfileRepository
    ) {
        this.psychologistProfileService = psychologistProfileService;
        this.patientProfileService = patientProfileService;
        this.psychologistProfileRepository = psychologistProfileRepository;
        this.patientProfileRepository = patientProfileRepository;
    }

    @GetMapping("/psychologists")
    public ResponseEntity<List<PsychologistProfileResponse>> listPsychologists() {
        return ResponseEntity.ok(
                psychologistProfileService.getAllPsychologists(null)
        );
    }

    @PatchMapping("/psychologists/{id}/verify")
    public ResponseEntity<PsychologistProfileResponse> setPsychologistVerified(
            @PathVariable Long id,
            @RequestParam boolean verified
    ) {
        return ResponseEntity.ok(
                psychologistProfileService.setProfileVerified(id, verified)
        );
    }

    @PatchMapping("/psychologists/{id}/reject")
    public ResponseEntity<PsychologistProfileResponse> setPsychologistRejected(
            @PathVariable Long id,
            @RequestParam boolean rejected
    ) {
        return ResponseEntity.ok(
                psychologistProfileService.setProfileRejected(id, rejected)
        );
    }

    @GetMapping("/patients")
    public ResponseEntity<List<PatientProfileResponse>> listPatients() {
        return ResponseEntity.ok(
                patientProfileService.getAllPatientsForAdmin()
        );
    }

    @GetMapping("/stats/profiles")
    public ResponseEntity<AdminStatsResponse> getStats() {

        AdminStatsResponse stats = new AdminStatsResponse();

        stats.setTotalPatients(patientProfileRepository.count());
        stats.setTotalPsychologists(psychologistProfileRepository.count());
        stats.setVerifiedPsychologists(
                psychologistProfileRepository.countByProfileVerified(true)
        );
        stats.setPendingPsychologists(
                psychologistProfileRepository
                        .countByProfileVerifiedAndRejected(false, false)
        );
        stats.setRejectedPsychologists(
                psychologistProfileRepository.countByRejected(true)
        );

        return ResponseEntity.ok(stats);
    }
}
