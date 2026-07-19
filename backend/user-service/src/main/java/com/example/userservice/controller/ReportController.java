package com.example.userservice.controller;

import com.example.userservice.dto.AdminReviewReportRequest;
import com.example.userservice.dto.ReportResponse;
import com.example.userservice.service.ReportService;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
public class ReportController {

    private final ReportService reportService;

    public ReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    // soumission : POST /patients/{patientId}/reports?psychologistId=X
    // multipart : reason (String), description (String), file (optionnel)
    @PostMapping(
            value = "/patients/{patientId}/reports",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ResponseEntity<ReportResponse> createReport(
            HttpServletRequest httpRequest,
            @PathVariable Long patientId,
            @RequestParam Long psychologistId,
            @RequestParam String reason,
            @RequestParam(required = false) String description,
            @RequestParam(value = "file", required = false) MultipartFile file
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(reportService.createReport(
                        patientId,
                        psychologistId,
                        reason,
                        description,
                        file,
                        authUserId(httpRequest)
                ));
    }

    // liste des signalements pour l'admin, filtre optionnel ?status=PENDING
    @GetMapping("/admin/reports")
    public ResponseEntity<List<ReportResponse>> listReports(
            @RequestParam(required = false) String status
    ) {
        return ResponseEntity.ok(reportService.listReports(status));
    }

    // téléchargement de la preuve par l'admin
    @GetMapping("/admin/reports/{id}/evidence")
    public ResponseEntity<byte[]> getEvidence(@PathVariable Long id) {
        byte[] data = reportService.getEvidenceBytes(id);
        String ext = reportService.getEvidenceExtension(id);
        MediaType mediaType = resolveMediaType(ext);
        return ResponseEntity.ok()
                .contentType(mediaType)
                .body(data);
    }

    // traitement du signalement par l'admin (REVIEWED ou DISMISSED)
    @PatchMapping("/admin/reports/{id}")
    public ResponseEntity<ReportResponse> reviewReport(
            @PathVariable Long id,
            @RequestBody AdminReviewReportRequest request
    ) {
        return ResponseEntity.ok(reportService.reviewReport(id, request));
    }

    private Long authUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }

    private MediaType resolveMediaType(String ext) {
        if (ext == null) return MediaType.APPLICATION_OCTET_STREAM;
        return switch (ext.toLowerCase()) {
            case ".jpg", ".jpeg" -> MediaType.IMAGE_JPEG;
            case ".png"          -> MediaType.IMAGE_PNG;
            case ".pdf"          -> MediaType.APPLICATION_PDF;
            default              -> MediaType.APPLICATION_OCTET_STREAM;
        };
    }
}
