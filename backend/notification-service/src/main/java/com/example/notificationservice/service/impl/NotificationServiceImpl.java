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

    // Retourne le rôle de l'utilisateur courant ("PATIENT" ou "PSYCHOLOGIST"),
    // ou null si aucun rôle connu.
    private String currentRole() {
        if (SecurityUtils.hasRole("PATIENT")) return "PATIENT";
        if (SecurityUtils.hasRole("PSYCHOLOGIST")) return "PSYCHOLOGIST";
        return null;
    }

    // Une notification appartient à un profil identifié par (userId, userRole).
    // Sans le rôle, patientProfileId=3 et psychologistProfileId=3 seraient
    // indiscernables — un psy verrait les notifs du patient ayant le même id.
    private void checkOwnership(Long notificationUserId, String notificationUserRole) {

        String role = currentRole();
        boolean owns = false;

        if ("PATIENT".equals(role) && "PATIENT".equals(notificationUserRole)) {
            owns = ownershipResolver.resolveOwnPatientId().equals(notificationUserId);
        } else if ("PSYCHOLOGIST".equals(role) && "PSYCHOLOGIST".equals(notificationUserRole)) {
            owns = ownershipResolver.resolveOwnPsychologistId().equals(notificationUserId);
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

        String role = currentRole();
        if (role == null) {
            throw new ForbiddenOperationException("Rôle non reconnu");
        }

        // checkOwnership implicite : on ne retourne que les notifs qui correspondent
        // au rôle courant, donc un psy ne verra jamais les notifs d'un patient
        // même si leurs profileId numériques coïncident.
        Long ownId = "PATIENT".equals(role)
                ? ownershipResolver.resolveOwnPatientId()
                : ownershipResolver.resolveOwnPsychologistId();

        if (!ownId.equals(userId)) {
            throw new ForbiddenOperationException(
                    "Cette notification ne vous appartient pas"
            );
        }

        return notificationRepository
                .findByUserIdAndUserRole(userId, role);
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

        checkOwnership(notification.getUserId(), notification.getUserRole());

        notification.setIsRead(true);

        return notificationRepository
                .save(notification);
    }
}
