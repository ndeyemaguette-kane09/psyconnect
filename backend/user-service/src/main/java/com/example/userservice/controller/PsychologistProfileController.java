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

    /**
     * Liste des psys disponibles pour urgence (vérifiés + availableForEmergency=true).
     * Endpoint public (comme GET /psychologists), pas besoin d'être connecté.
     */
    @GetMapping("/emergency")
    public ResponseEntity<List<PsychologistProfileResponse>> getEmergencyPsychologists() {
        return ResponseEntity.ok(
                psychologistProfileService.getEmergencyPsychologists()
        );
    }

    /**
     * Le psy active ou désactive son mode urgence.
     * ?available=true/false  &freeSession=true/false
     * Seul le propriétaire du profil peut le faire.
     */
    @PutMapping("/{id}/emergency")
    public ResponseEntity<PsychologistProfileResponse> setEmergencyAvailability(
            HttpServletRequest httpRequest,
            @PathVariable Long id,
            @RequestParam boolean available,
            @RequestParam(defaultValue = "false") boolean freeSession
    ) {
        return ResponseEntity.ok(
                psychologistProfileService.setEmergencyAvailability(
                        id, available, freeSession, currentAuthUserId(httpRequest)
                )
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

    // envoie ou remplace le justificatif, que le proprietaire du profil
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

    // ici faut etre connecté, contrairement au GET generique qui est public
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