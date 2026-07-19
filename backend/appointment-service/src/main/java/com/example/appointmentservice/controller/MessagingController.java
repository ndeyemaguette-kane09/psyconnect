package com.example.appointmentservice.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.appointmentservice.dto.ConversationResponse;
import com.example.appointmentservice.dto.MessageResponse;
import com.example.appointmentservice.dto.SendMessageRequest;
import com.example.appointmentservice.dto.StartConversationRequest;
import com.example.appointmentservice.service.MessagingService;

import jakarta.validation.Valid;

// Messagerie patient-psychologue, même principe que paiement/visio
@RestController
@RequestMapping("/messages")
public class MessagingController {

    private final MessagingService messagingService;

    public MessagingController(MessagingService messagingService) {
        this.messagingService = messagingService;
    }

    @GetMapping("/conversations")
    public ResponseEntity<List<ConversationResponse>> listMyConversations() {
        return ResponseEntity.ok(messagingService.listMyConversations());
    }

    // Crée la conversation si elle n'existe pas encore, sinon la retourne
    @PostMapping("/conversations")
    public ResponseEntity<ConversationResponse> startOrGetConversation(
            @Valid @RequestBody StartConversationRequest request
    ) {
        return ResponseEntity.ok(messagingService.startOrGetConversation(request));
    }

    @GetMapping("/conversations/{id}/messages")
    public ResponseEntity<List<MessageResponse>> listMessages(@PathVariable Long id) {
        return ResponseEntity.ok(messagingService.listMessages(id));
    }

    @PostMapping("/conversations/{id}/messages")
    public ResponseEntity<MessageResponse> sendMessage(
            @PathVariable Long id,
            @Valid @RequestBody SendMessageRequest request
    ) {
        return ResponseEntity.ok(messagingService.sendMessage(id, request));
    }

    @PatchMapping("/conversations/{id}/read")
    public ResponseEntity<Void> markConversationRead(@PathVariable Long id) {
        messagingService.markConversationRead(id);
        return ResponseEntity.noContent().build();
    }
}
