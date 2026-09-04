package com.example.userservice.service.impl;

import com.example.userservice.client.NotificationClient;
import com.example.userservice.dto.AdminReviewReportRequest;
import com.example.userservice.dto.ReportResponse;
import com.example.userservice.entity.*;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.*;
import com.example.userservice.service.EvidenceStorageService;
import com.example.userservice.service.ReportService;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@Service
public class ReportServiceImpl implements ReportService {

    private final PsychologistReportRepository reportRepository;
    private final PatientProfileRepository patientProfileRepository;
    private final EvidenceStorageService evidenceStorage;
    private final NotificationClient notificationClient;

    public ReportServiceImpl(
            PsychologistReportRepository reportRepository,
            PatientProfileRepository patientProfileRepository,
            EvidenceStorageService evidenceStorage,
            NotificationClient notificationClient
    ) {
        this.reportRepository = reportRepository;
        this.patientProfileRepository = patientProfileRepository;
        this.evidenceStorage = evidenceStorage;
        this.notificationClient = notificationClient;
    }

    @Override
    public ReportResponse createReport(
            Long patientProfileId,
            Long psychologistProfileId,
            String reason,
            String description,
            MultipartFile evidence,
            Long callerAuthUserId
    ) {
        PatientProfile patient = patientProfileRepository.findById(patientProfileId)
                .orElseThrow(() -> new ResourceNotFoundException("Profil patient introuvable"));

        // seul le propriétaire du profil peut soumettre un signalement en son nom
        if (patient.getAuthUserId() == null
                || !patient.getAuthUserId().equals(callerAuthUserId)) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez soumettre un signalement qu'en votre propre nom"
            );
        }

        ReportReason reportReason;
        try {
            reportReason = ReportReason.valueOf(reason);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Motif de signalement invalide : " + reason);
        }

        PsychologistReport report = new PsychologistReport();
        report.setPatientProfileId(patientProfileId);
        report.setPsychologistProfileId(psychologistProfileId);
        report.setReason(reportReason);
        report.setDescription(description);

        if (evidence != null && !evidence.isEmpty()) {
            String stored = evidenceStorage.store(evidence);
            report.setEvidenceFilename(stored);
            // extension pour le Content-Type lors du téléchargement
            String originalName = evidence.getOriginalFilename();
            if (originalName != null && originalName.contains(".")) {
                report.setEvidenceExtension(
                        originalName.substring(originalName.lastIndexOf('.')).toLowerCase()
                );
            }
        }

        return mapToResponse(reportRepository.save(report));
    }

    @Override
    public List<ReportResponse> listReports(String statusFilter) {
        if (statusFilter == null || statusFilter.isBlank()) {
            return reportRepository.findAllByOrderByCreatedAtDesc()
                    .stream().map(this::mapToResponse).toList();
        }
        ReportStatus status;
        try {
            status = ReportStatus.valueOf(statusFilter.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Statut invalide : " + statusFilter);
        }
        return reportRepository.findByStatusOrderByCreatedAtDesc(status)
                .stream().map(this::mapToResponse).toList();
    }

    @Override
    public ReportResponse reviewReport(Long reportId, AdminReviewReportRequest request) {
        PsychologistReport report = findById(reportId);

        ReportStatus newStatus;
        try {
            newStatus = ReportStatus.valueOf(request.getStatus().toUpperCase());
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new IllegalArgumentException("Statut invalide : " + request.getStatus());
        }

        if (newStatus == ReportStatus.PENDING) {
            throw new IllegalArgumentException("Impossible de repasser un signalement en PENDING");
        }

        report.setStatus(newStatus);
        if (request.getAdminNote() != null) {
            report.setAdminNote(request.getAdminNote());
        }

        PsychologistReport saved = reportRepository.save(report);
        notifyPsychologist(saved, newStatus);

        return mapToResponse(saved);
    }

    private void notifyPsychologist(PsychologistReport report, ReportStatus status) {
        String title;
        String message;

        if (status == ReportStatus.REVIEWED) {
            title = "Signalement traité";
            message = "Un signalement vous concernant a été examiné par l'administration "
                    + "et une mesure a été prise. Contactez le support pour plus d'informations.";
        } else {
            title = "Signalement classé sans suite";
            message = "Un signalement vous concernant a été examiné par l'administration "
                    + "et jugé non fondé. Aucune mesure n'a été prise à votre encontre.";
        }

        notificationClient.send(
                report.getPsychologistProfileId(),
                title,
                message,
                "SYSTEM",
                "PSYCHOLOGIST"
        );
    }

    @Override
    public byte[] getEvidenceBytes(Long reportId) {
        PsychologistReport report = findById(reportId);
        if (report.getEvidenceFilename() == null) {
            throw new ResourceNotFoundException("Ce signalement n'a pas de preuve jointe");
        }
        return evidenceStorage.load(report.getEvidenceFilename());
    }

    @Override
    public String getEvidenceExtension(Long reportId) {
        return findById(reportId).getEvidenceExtension();
    }

    private PsychologistReport findById(Long id) {
        return reportRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Signalement introuvable"));
    }

    private ReportResponse mapToResponse(PsychologistReport r) {
        ReportResponse dto = new ReportResponse();
        dto.setId(r.getId());
        dto.setPatientProfileId(r.getPatientProfileId());
        dto.setPsychologistProfileId(r.getPsychologistProfileId());
        dto.setReason(r.getReason().name());
        dto.setReasonLabel(r.getReason().label());
        dto.setDescription(r.getDescription());
        dto.setHasEvidence(r.getEvidenceFilename() != null);
        dto.setStatus(r.getStatus().name());
        dto.setAdminNote(r.getAdminNote());
        dto.setCreatedAt(r.getCreatedAt());
        dto.setUpdatedAt(r.getUpdatedAt());
        return dto;
    }
}
