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

    @PostMapping("/admin/notifications/broadcast")
    public ResponseEntity<Map<String, Object>> broadcast(
            @RequestBody BroadcastRequest request
    ) {
        int count = broadcastService.countTargets(request);
        broadcastService.sendAsync(request);
        return ResponseEntity.accepted().body(Map.of(
                "sent", count,
                "message", "Annonce en cours d'envoi à " + count + " destinataire(s)."
        ));
    }

    @GetMapping("/admin/notifications/broadcasts")
    public ResponseEntity<List<BroadcastDto>> adminListBroadcasts() {
        return ResponseEntity.ok(broadcastService.getBroadcastsForCurrentUser());
    }

    @GetMapping("/users/broadcasts")
    public ResponseEntity<List<BroadcastDto>> listBroadcasts() {
        return ResponseEntity.ok(broadcastService.getBroadcastsForCurrentUser());
    }
}
