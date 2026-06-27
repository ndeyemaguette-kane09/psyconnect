package com.example.userservice.controller;

import com.example.userservice.dto.CreatePsychologistProfileRequest;
import com.example.userservice.dto.LicenseDocumentResponse;
import com.example.userservice.dto.PsychologistProfileResponse;
import com.example.userservice.service.PsychologistProfileService;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import jakarta.servlet.http.HttpServletRequest;

import java.util.List;

@RestController
@RequestMapping("/psychologists")
public class PsychologistProfileController {

    private final PsychologistProfileService
            psychologistProfileService;

    public PsychologistProfileController(
            PsychologistProfileService psychologistProfileService
    ) {

        this.psychologistProfileService =
                psychologistProfileService;
    }

    @PostMapping
    public ResponseEntity<PsychologistProfileResponse>
    createPsychologistProfile(
            HttpServletRequest httpRequest,
            @RequestBody
            CreatePsychologistProfileRequest request
    ) {

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(
                        psychologistProfileService
                                .createPsychologistProfile(
                                        request,
                                        currentAuthUserId(httpRequest)
                                )
                );
    }

    @GetMapping("/{id}")
    public ResponseEntity<PsychologistProfileResponse>
    getPsychologistProfile(
            @PathVariable Long id
    ) {

        return ResponseEntity.ok(
                psychologistProfileService
                        .getPsychologistProfile(id)
        );
    }

    @GetMapping("/by-auth-user/{authUserId}")
    public ResponseEntity<PsychologistProfileResponse>
    getPsychologistProfileByAuthUserId(
            HttpServletRequest httpRequest,
            @PathVariable Long authUserId
    ) {

        return ResponseEntity.ok(
                psychologistProfileService
                        .getPsychologistProfileByAuthUserId(
                                authUserId,
                                currentAuthUserId(httpRequest)
                        )
        );
    }

    @GetMapping
    public ResponseEntity<
            List<PsychologistProfileResponse>
            >
    getAllPsychologists(
            @RequestParam(required = false) Boolean verifiedOnly
    ) {

        return ResponseEntity.ok(
                psychologistProfileService
                        .getAllPsychologists(verifiedOnly)
        );
    }

    @PutMapping("/{id}")
    public ResponseEntity<PsychologistProfileResponse>
    updatePsychologistProfile(
            HttpServletRequest httpRequest,
            @PathVariable Long id,

            @RequestBody
            CreatePsychologistProfileRequest request
    ) {

        return ResponseEntity.ok(
                psychologistProfileService
                        .updatePsychologistProfile(
                                id,
                                request,
                                currentAuthUserId(httpRequest)
                        )
        );
    }

    /**
     * Réservé au propriétaire du profil (vérifié côté service via
     * callerAuthUserId) : envoie ou remplace le justificatif joint à
     * l'inscription (diplôme, carte professionnelle).
     */
    @PostMapping(
            value = "/{id}/license-document",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ResponseEntity<PsychologistProfileResponse>
    uploadLicenseDocument(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file
    ) {

        return ResponseEntity.ok(
                psychologistProfileService
                        .uploadLicenseDocument(
                                id,
                                file,
                                currentAuthUserId(httpRequest)
                        )
        );
    }

    /**
     * Accessible au propriétaire du profil OU à un ADMIN (cf.
     * SecurityConfig : ce chemin précis exige authenticated(), contrairement
     * au GET /psychologists/** générique qui est public).
     */
    @GetMapping("/{id}/license-document")
    public ResponseEntity<byte[]> getLicenseDocument(
            HttpServletRequest httpRequest,
            @PathVariable Long id
    ) {

        LicenseDocumentResponse document =
                psychologistProfileService.getLicenseDocument(
                        id,
                        currentAuthUserId(httpRequest),
                        httpRequest.isUserInRole("ADMIN")
                );

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(document.getContentType()))
                .body(document.getData());
    }

    private Long currentAuthUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}