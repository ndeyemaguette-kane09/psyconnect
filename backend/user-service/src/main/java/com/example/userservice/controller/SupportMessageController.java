package com.example.userservice.controller;

import com.example.userservice.dto.AdminReplySupportMessageRequest;
import com.example.userservice.dto.AdminResolveSupportMessageRequest;
import com.example.userservice.dto.CreateSupportMessageRequest;
import com.example.userservice.dto.SupportMessageResponse;
import com.example.userservice.service.SupportMessageService;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class SupportMessageController {

    private final SupportMessageService supportMessageService;

    public SupportMessageController(SupportMessageService supportMessageService) {
        this.supportMessageService = supportMessageService;
    }

    @PostMapping("/patients/{patientId}/support-messages")
    public ResponseEntity<SupportMessageResponse> createFromPatient(
            HttpServletRequest httpRequest,
            @PathVariable Long patientId,
            @RequestBody CreateSupportMessageRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(supportMessageService.createMessage(
                        patientId,
                        "PATIENT",
                        request.getSubject(),
                        request.getMessage(),
                        authUserId(httpRequest)
                ));
    }

    @PostMapping("/psychologists/{psychologistId}/support-messages")
    public ResponseEntity<SupportMessageResponse> createFromPsychologist(
            HttpServletRequest httpRequest,
            @PathVariable Long psychologistId,
            @RequestBody CreateSupportMessageRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(supportMessageService.createMessage(
                        psychologistId,
                        "PSYCHOLOGIST",
                        request.getSubject(),
                        request.getMessage(),
                        authUserId(httpRequest)
                ));
    }

    @GetMapping("/admin/support-messages")
    public ResponseEntity<List<SupportMessageResponse>> listMessages(
            @RequestParam(required = false) String status
    ) {
        return ResponseEntity.ok(supportMessageService.listMessages(status));
    }

    @PatchMapping("/admin/support-messages/{id}")
    public ResponseEntity<SupportMessageResponse> resolveMessage(
            @PathVariable Long id,
            @RequestBody AdminResolveSupportMessageRequest request
    ) {
        return ResponseEntity.ok(supportMessageService.resolveMessage(id, request));
    }

    @PostMapping("/admin/support-messages/{id}/reply")
    public ResponseEntity<SupportMessageResponse> replyToMessage(
            @PathVariable Long id,
            @RequestBody AdminReplySupportMessageRequest request
    ) {
        return ResponseEntity.ok(supportMessageService.replyToMessage(id, request.getReply()));
    }

    private Long authUserId(HttpServletRequest request) {
        return (Long) request.getAttribute("authUserId");
    }
}
