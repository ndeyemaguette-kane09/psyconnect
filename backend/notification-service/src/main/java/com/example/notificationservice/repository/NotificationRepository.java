package com.example.notificationservice.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.notificationservice.entity.Notification;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    
    List<Notification> findByUserId(Long userId);

    // filtre par (userId, userRole) pour éviter la collision entre patientProfileId
    // et psychologistProfileId qui peuvent avoir la même valeur numérique
    List<Notification> findByUserIdAndUserRole(Long userId, String userRole);
}
