package com.example.userservice.service;

import com.example.userservice.dto.AdminReviewReportRequest;
import com.example.userservice.dto.ReportResponse;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

public interface ReportService {

    // soumission d'un signalement par un patient (callerAuthUserId vérifié = propriétaire du profil)
    ReportResponse createReport(
            Long patientProfileId,
            Long psychologistProfileId,
            String reason,
            String description,
            MultipartFile evidence,   // nullable
            Long callerAuthUserId
    );

    List<ReportResponse> listReports(String statusFilter); // null = tous

    ReportResponse reviewReport(Long reportId, AdminReviewReportRequest request);

    // données binaires de la preuve + extension pour le Content-Type
    byte[] getEvidenceBytes(Long reportId);
    String getEvidenceExtension(Long reportId);
}
