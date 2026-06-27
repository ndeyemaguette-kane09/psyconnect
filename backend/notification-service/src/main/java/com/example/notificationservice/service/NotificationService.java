package com.example.notificationservice.service;

import java.util.List;

import com.example.notificationservice.entity.Notification;

public interface NotificationService {

    Notification createNotification(
            Notification notification
    );

    List<Notification>
    getNotificationsByUserId(
            Long userId
    );

    Notification markAsRead(
            Long notificationId
    );
}
