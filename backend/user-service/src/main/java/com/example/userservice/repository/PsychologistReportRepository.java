package com.example.userservice.repository;

import com.example.userservice.entity.PsychologistReport;
import com.example.userservice.entity.ReportStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PsychologistReportRepository extends JpaRepository<PsychologistReport, Long> {

    List<PsychologistReport> findAllByOrderByCreatedAtDesc();

    List<PsychologistReport> findByStatusOrderByCreatedAtDesc(ReportStatus status);

    long countByStatus(ReportStatus status);
}
