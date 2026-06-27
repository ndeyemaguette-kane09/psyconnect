package com.example.notificationservice.service.impl;

import java.util.List;

import org.springframework.stereotype.Service;

import com.example.notificationservice.entity.Notification;
import com.example.notificationservice.exception.ForbiddenOperationException;
import com.example.notificationservice.exception.ResourceNotFoundException;
import com.example.notificationservice.repository.NotificationRepository;
import com.example.notificationservice.security.SecurityUtils;
import com.example.notificationservice.service.NotificationService;
import com.example.notificationservice.service.OwnershipResolver;

@Service
public class NotificationServiceImpl
        implements NotificationService {

    private final NotificationRepository
            notificationRepository;

    private final OwnershipResolver ownershipResolver;

    public NotificationServiceImpl(
            NotificationRepository notificationRepository,
            OwnershipResolver ownershipResolver
    ) {

        this.notificationRepository =
                notificationRepository;

        this.ownershipResolver = ownershipResolver;
    }

    /**
     * Une notification appartient soit à un patient (userId =
     * PatientProfile.id), soit à un psychologue (userId =
     * PsychologistProfile.id) — ex. décision de validation de l'admin
     * (accepté/refusé). On résout l'identité propriétaire selon le rôle du
     * jeton courant plutôt que de supposer PATIENT dans tous les cas.
     */
    private void checkOwnership(Long notificationUserId) {

        boolean owns;

        if (SecurityUtils.hasRole("PATIENT")) {
            owns = ownershipResolver.resolveOwnPatientId().equals(notificationUserId);
        } else if (SecurityUtils.hasRole("PSYCHOLOGIST")) {
            owns = ownershipResolver.resolveOwnPsychologistId().equals(notificationUserId);
        } else {
            owns = false;
        }

        if (!owns) {
            throw new ForbiddenOperationException(
                    "Cette notification ne vous appartient pas"
            );
        }
    }

    @Override
    public Notification createNotification(
            Notification notification
    ) {

        notification.setIsRead(false);

        return notificationRepository
                .save(notification);
    }

    @Override
    public List<Notification>
    getNotificationsByUserId(
            Long userId
    ) {

        checkOwnership(userId);

        return notificationRepository
                .findByUserId(userId);
    }

    @Override
    public Notification markAsRead(
            Long notificationId
    ) {

        Notification notification =
                notificationRepository
                        .findById(notificationId)
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Notification introuvable"
                                )
                        );

        checkOwnership(notification.getUserId());

        notification.setIsRead(true);

        return notificationRepository
                .save(notification);
    }
}
