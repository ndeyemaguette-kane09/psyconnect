package com.example.userservice.controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.userservice.dto.BroadcastDto;
import com.example.userservice.dto.BroadcastRequest;
import com.example.userservice.service.BroadcastService;

@RestController
public class BroadcastController {

    private final BroadcastService broadcastService;

    public BroadcastController(BroadcastService broadcastService) {
        this.broadcastService = broadcastService;
    }

    // ── ADMIN : envoi d'un broadcast ─────────────────────────────────────────
    // POST /admin/notifications/broadcast — réservé ADMIN (couvert par /admin/**)
    // 1. compte les cibles (rapide, synchrone)
    // 2. lance l'envoi en arrière-plan (@Async — ne bloque pas)
    // 3. répond immédiatement avec le nombre estimé de destinataires
    @PostMapping("/admin/notifications/broadcast")
    public ResponseEntity<Map<String, Object>> broadcast(
            @RequestBody BroadcastRequest request
    ) {
        int count = broadcastService.countTargets(request);
        broadcastService.sendAsync(request); // fire-and-forget
        return ResponseEntity.accepted().body(Map.of(
                "sent", count,
                "message", "Annonce en cours d'envoi à " + count + " destinataire(s)."
        ));
    }

    // ── ADMIN : historique de tous les broadcasts ─────────────────────────────
    // GET /admin/notifications/broadcasts — réservé ADMIN
    @GetMapping("/admin/notifications/broadcasts")
    public ResponseEntity<List<BroadcastDto>> adminListBroadcasts() {
        return ResponseEntity.ok(broadcastService.getBroadcastsForCurrentUser());
    }

    // ── Utilisateurs authentifiés : lire les annonces qui les concernent ─────
    // GET /users/broadcasts — utilise le préfixe /users/** déjà routé par la
    // gateway vers user-service, évite d'ajouter une nouvelle route gateway.
    // Le service filtre automatiquement selon le rôle JWT de l'appelant.
    @GetMapping("/users/broadcasts")
    public ResponseEntity<List<BroadcastDto>> listBroadcasts() {
        return ResponseEntity.ok(broadcastService.getBroadcastsForCurrentUser());
    }
}
