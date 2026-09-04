package com.example.appointmentservice.service.impl;

import com.example.appointmentservice.dto.CreateRecommendationRequest;
import com.example.appointmentservice.dto.RecommendationResponse;
import com.example.appointmentservice.entity.Appointment;
import com.example.appointmentservice.entity.AppointmentStatus;
import com.example.appointmentservice.entity.SessionRecommendation;
import com.example.appointmentservice.exception.ForbiddenOperationException;
import com.example.appointmentservice.exception.ResourceNotFoundException;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.SessionRecommendationRepository;
import com.example.appointmentservice.security.SecurityUtils;
import com.example.appointmentservice.service.OwnershipResolver;
import com.example.appointmentservice.service.RecommendationService;

import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class RecommendationServiceImpl implements RecommendationService {

    private final SessionRecommendationRepository recommendationRepository;
    private final AppointmentRepository appointmentRepository;
    private final OwnershipResolver ownershipResolver;

    public RecommendationServiceImpl(
            SessionRecommendationRepository recommendationRepository,
            AppointmentRepository appointmentRepository,
            OwnershipResolver ownershipResolver
    ) {
        this.recommendationRepository = recommendationRepository;
        this.appointmentRepository = appointmentRepository;
        this.ownershipResolver = ownershipResolver;
    }

    @Override
    public RecommendationResponse createRecommendation(
            CreateRecommendationRequest request
    ) {
        if (!SecurityUtils.hasRole("PSYCHOLOGIST")) {
            throw new ForbiddenOperationException(
                    "Seul un psychologue peut créer des recommandations"
            );
        }

        Long psyId = ownershipResolver.resolveOwnPsychologistId();

        Appointment appointment = appointmentRepository
                .findById(request.getAppointmentId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Rendez-vous non trouvé"
                ));

        
        if (!psyId.equals(appointment.getPsychologistId())) {
            throw new ForbiddenOperationException(
                    "Vous ne pouvez créer des recommandations que pour vos propres rendez-vous"
            );
        }

        
        if (appointment.getStatus() != AppointmentStatus.COMPLETED) {
            throw new ForbiddenOperationException(
                    "Les recommandations ne peuvent être ajoutées qu'après une séance terminée"
            );
        }

        if (request.getContent() == null || request.getContent().isBlank()) {
            throw new IllegalArgumentException(
                    "Le contenu de la recommandation ne peut pas être vide"
            );
        }

        SessionRecommendation reco = new SessionRecommendation();
        reco.setAppointmentId(appointment.getId());
        reco.setPsychologistId(psyId);
        reco.setPatientId(appointment.getPatientId());
        reco.setContent(request.getContent().trim());

        return mapToResponse(recommendationRepository.save(reco));
    }

    @Override
    public List<RecommendationResponse> getMyPendingRecommendations() {
        if (!SecurityUtils.hasRole("PATIENT")) {
            throw new ForbiddenOperationException(
                    "Seul un patient peut consulter ses recommandations"
            );
        }

        Long patientId = ownershipResolver.resolveOwnPatientId();

        return recommendationRepository
                .findByPatientIdAndCompletedFalseOrderByCreatedAtDesc(patientId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public List<RecommendationResponse> getByAppointment(Long appointmentId) {
        Appointment appointment = appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Rendez-vous non trouvé"
                ));

        // psy ou patient du RDV
        if (SecurityUtils.hasRole("PSYCHOLOGIST")) {
            Long psyId = ownershipResolver.resolveOwnPsychologistId();
            if (!psyId.equals(appointment.getPsychologistId())) {
                throw new ForbiddenOperationException(
                        "Ce rendez-vous ne vous appartient pas"
                );
            }
        } else if (SecurityUtils.hasRole("PATIENT")) {
            Long patientId = ownershipResolver.resolveOwnPatientId();
            if (!patientId.equals(appointment.getPatientId())) {
                throw new ForbiddenOperationException(
                        "Ce rendez-vous ne vous appartient pas"
                );
            }
        } else {
            throw new ForbiddenOperationException(
                    "Accès non autorisé"
            );
        }

        return recommendationRepository
                .findByAppointmentIdOrderByCreatedAtDesc(appointmentId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    public RecommendationResponse markCompleted(Long id) {
        if (!SecurityUtils.hasRole("PATIENT")) {
            throw new ForbiddenOperationException(
                    "Seul le patient destinataire peut marquer une recommandation comme accomplie"
            );
        }

        Long patientId = ownershipResolver.resolveOwnPatientId();

        SessionRecommendation reco = recommendationRepository
                .findByIdAndPatientId(id, patientId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Recommandation non trouvée ou non destinée à ce patient"
                ));

        reco.setCompleted(true);
        return mapToResponse(recommendationRepository.save(reco));
    }

    @Override
    public void deleteRecommendation(Long id) {
        if (!SecurityUtils.hasRole("PSYCHOLOGIST")) {
            throw new ForbiddenOperationException(
                    "Seul le psychologue auteur peut supprimer une recommandation"
            );
        }

        Long psyId = ownershipResolver.resolveOwnPsychologistId();

        SessionRecommendation reco = recommendationRepository
                .findByIdAndPsychologistId(id, psyId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Recommandation non trouvée ou non créée par ce psychologue"
                ));

        recommendationRepository.delete(reco);
    }

    private RecommendationResponse mapToResponse(SessionRecommendation r) {
        RecommendationResponse resp = new RecommendationResponse();
        resp.setId(r.getId());
        resp.setAppointmentId(r.getAppointmentId());
        resp.setPsychologistId(r.getPsychologistId());
        resp.setPatientId(r.getPatientId());
        resp.setContent(r.getContent());
        resp.setCompleted(r.isCompleted());
        resp.setCreatedAt(r.getCreatedAt());
        resp.setUpdatedAt(r.getUpdatedAt());
        return resp;
    }
}
