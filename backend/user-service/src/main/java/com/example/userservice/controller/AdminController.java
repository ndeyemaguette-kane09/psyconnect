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

/**
 * Endpoints réservés au rôle ADMIN : validation des profils psychologue,
 * vue d'ensemble des comptes patients/psychologues, statistiques.
 * Protégés par {@code SecurityConfig} : {@code /admin/**} exige
 * {@code hasRole("ADMIN")}.
 */
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

    /**
     * Refuse (ou remet en attente) une demande de validation — distinct de
     * {@code /verify?verified=false}, qui est un no-op sur un profil déjà en
     * attente (profileVerified vaut déjà false).
     */
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

    // Renommé /stats -> /stats/profiles : auth-service et appointment-service
    // exposent chacun leur propre /admin/stats, ce qui rendrait le routage
    // gateway ambigu si les 3 chemins restaient identiques (cf. api-gateway
    // application.properties, routes admin-*).
    @GetMapping("/stats/profiles")
    public ResponseEntity<AdminStatsResponse> getStats() {

        AdminStatsResponse stats = new AdminStatsResponse();

        stats.setTotalPatients(patientProfileRepository.count());
        stats.setTotalPsychologists(psychologistProfileRepository.count());
        stats.setVerifiedPsychologists(
                psychologistProfileRepository.countByProfileVerified(true)
        );
        // "En attente" exclut désormais les profils explicitement refusés
        // (rejected=true) : avant l'ajout de ce champ, un refus n'était pas
        // distinguable d'une demande jamais traitée.
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
