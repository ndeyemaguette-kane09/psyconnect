package com.example.notificationservice.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.notificationservice.entity.Notification;
import com.example.notificationservice.service.NotificationService;

@RestController
@RequestMapping("/notifications")
public class NotificationController {

    private final NotificationService
            notificationService;

    public NotificationController(
            NotificationService notificationService
    ) {

        this.notificationService =
                notificationService;
    }

    @PostMapping
    public ResponseEntity<Notification>
    createNotification(
            @RequestBody Notification notification
    ) {

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(
                        notificationService
                                .createNotification(notification)
                );
    }

    @GetMapping("/user/{userId}")
    public ResponseEntity<List<Notification>>
    getNotificationsByUserId(
            @PathVariable Long userId
    ) {

        return ResponseEntity.ok(
                notificationService
                        .getNotificationsByUserId(userId)
        );
    }

    @PutMapping("/{notificationId}/read")
    public ResponseEntity<Notification>
    markAsRead(
            @PathVariable Long notificationId
    ) {

        return ResponseEntity.ok(
                notificationService
                        .markAsRead(notificationId)
        );
    }
}
