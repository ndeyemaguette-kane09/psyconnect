package com.example.userservice.service.impl;

import com.example.userservice.client.NotificationClient;
import com.example.userservice.dto.AdminResolveSupportMessageRequest;
import com.example.userservice.dto.SupportMessageResponse;
import com.example.userservice.entity.*;
import com.example.userservice.exception.ForbiddenOperationException;
import com.example.userservice.exception.ResourceNotFoundException;
import com.example.userservice.repository.*;
import com.example.userservice.service.SupportMessageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class SupportMessageServiceImpl implements SupportMessageService {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(SupportMessageServiceImpl.class);

    private final SupportMessageRepository supportMessageRepository;
    private final PatientProfileRepository patientProfileRepository;
    private final PsychologistProfileRepository psychologistProfileRepository;
    private final NotificationClient notificationClient;

    public SupportMessageServiceImpl(
            SupportMessageRepository supportMessageRepository,
            PatientProfileRepository patientProfileRepository,
            PsychologistProfileRepository psychologistProfileRepository,
            NotificationClient notificationClient
    ) {
        this.supportMessageRepository = supportMessageRepository;
        this.patientProfileRepository = patientProfileRepository;
        this.psychologistProfileRepository = psychologistProfileRepository;
        this.notificationClient = notificationClient;
    }

    @Override
    public SupportMessageResponse createMessage(
            Long senderProfileId,
            String senderRole,
            String subject,
            String message,
            Long callerAuthUserId
    ) {
        SupportMessageSenderRole role;
        try {
            role = SupportMessageSenderRole.valueOf(senderRole);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Rôle d'expéditeur invalide : " + senderRole);
        }

        if (role == SupportMessageSenderRole.PATIENT) {
            PatientProfile patient = patientProfileRepository.findById(senderProfileId)
                    .orElseThrow(() -> new ResourceNotFoundException("Profil patient introuvable"));
            if (patient.getAuthUserId() == null
                    || !patient.getAuthUserId().equals(callerAuthUserId)) {
                throw new ForbiddenOperationException(
                        "Vous ne pouvez envoyer un message qu'en votre propre nom"
                );
            }
        } else {
            PsychologistProfile psychologist = psychologistProfileRepository.findById(senderProfileId)
                    .orElseThrow(() -> new ResourceNotFoundException("Profil psychologue introuvable"));
            if (psychologist.getAuthUserId() == null
                    || !psychologist.getAuthUserId().equals(callerAuthUserId)) {
                throw new ForbiddenOperationException(
                        "Vous ne pouvez envoyer un message qu'en votre propre nom"
                );
            }
        }

        if (subject == null || subject.isBlank()) {
            throw new IllegalArgumentException("Le sujet est obligatoire");
        }
        if (message == null || message.isBlank()) {
            throw new IllegalArgumentException("Le message est obligatoire");
        }

        SupportMessage entity = new SupportMessage();
        entity.setSenderProfileId(senderProfileId);
        entity.setSenderRole(role);
        entity.setSubject(subject.trim());
        entity.setMessage(message.trim());

        return mapToResponse(supportMessageRepository.save(entity));
    }

    @Override
    public List<SupportMessageResponse> listMessages(String statusFilter) {
        if (statusFilter == null || statusFilter.isBlank()) {
            return supportMessageRepository.findAllByOrderByCreatedAtDesc()
                    .stream().map(this::mapToResponse).toList();
        }
        SupportMessageStatus status;
        try {
            status = SupportMessageStatus.valueOf(statusFilter.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Statut invalide : " + statusFilter);
        }
        return supportMessageRepository.findByStatusOrderByCreatedAtDesc(status)
                .stream().map(this::mapToResponse).toList();
    }

    @Override
    public SupportMessageResponse resolveMessage(Long messageId, AdminResolveSupportMessageRequest request) {
        SupportMessage entity = supportMessageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message introuvable"));

        SupportMessageStatus newStatus;
        try {
            newStatus = SupportMessageStatus.valueOf(request.getStatus().toUpperCase());
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new IllegalArgumentException("Statut invalide : " + request.getStatus());
        }

        entity.setStatus(newStatus);
        if (request.getAdminNote() != null) {
            entity.setAdminNote(request.getAdminNote());
        }

        return mapToResponse(supportMessageRepository.save(entity));
    }

    @Override
    public SupportMessageResponse replyToMessage(Long messageId, String reply) {
        SupportMessage entity = supportMessageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message introuvable"));

        if (reply == null || reply.isBlank()) {
            throw new IllegalArgumentException("La réponse ne peut pas être vide");
        }

        entity.setAdminReply(reply.trim());
        entity.setRepliedAt(LocalDateTime.now());
        entity.setStatus(SupportMessageStatus.RESOLVED);
        SupportMessage saved = supportMessageRepository.save(entity);

        String title = "Réponse à votre message : " + saved.getSubject();
        try {
            notificationClient.send(
                    saved.getSenderProfileId(),
                    title,
                    saved.getAdminReply(),
                    "SUPPORT_REPLY",
                    saved.getSenderRole().name()
            );
        } catch (Exception e) {
            LOGGER.warn("Notification de réponse non envoyée pour le message {} : {}",
                    messageId, e.getMessage());
        }

        return mapToResponse(saved);
    }

    private SupportMessageResponse mapToResponse(SupportMessage e) {
        SupportMessageResponse dto = new SupportMessageResponse();
        dto.setId(e.getId());
        dto.setSenderProfileId(e.getSenderProfileId());
        dto.setSenderRole(e.getSenderRole().name());
        dto.setSubject(e.getSubject());
        dto.setMessage(e.getMessage());
        dto.setStatus(e.getStatus().name());
        dto.setAdminNote(e.getAdminNote());
        dto.setAdminReply(e.getAdminReply());
        dto.setRepliedAt(e.getRepliedAt());
        dto.setCreatedAt(e.getCreatedAt());
        dto.setUpdatedAt(e.getUpdatedAt());

        if (e.getSenderRole() == SupportMessageSenderRole.PATIENT) {
            patientProfileRepository.findById(e.getSenderProfileId()).ifPresent(p -> {
                if (p.getUserProfile() != null) {
                    dto.setSenderName(p.getUserProfile().getFirstName() + " " + p.getUserProfile().getLastName());
                    dto.setSenderPhone(p.getUserProfile().getPhoneNumber());
                }
            });
        } else {
            psychologistProfileRepository.findById(e.getSenderProfileId()).ifPresent(p -> {
                if (p.getUserProfile() != null) {
                    dto.setSenderName(p.getUserProfile().getFirstName() + " " + p.getUserProfile().getLastName());
                    dto.setSenderPhone(p.getUserProfile().getPhoneNumber());
                }
            });
        }

        return dto;
    }
}
