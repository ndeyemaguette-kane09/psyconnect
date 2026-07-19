package com.example.videoservice.handler;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Serveur de signaling WebRTC minimal.
 *
 * Principe : chaque room est identifiée par l'appointmentId.
 * Ce handler relaie tous les messages (SDP offer/answer + ICE candidates)
 * vers tous les autres participants de la même room.
 *
 * Il ne valide pas le contenu des messages : la logique WebRTC est
 * entièrement côté client (Flutter). Ce service est un simple relay.
 *
 * Capacité : 2 participants par room (psy + patient).
 * Si un 3e arrive, il reçoit les messages mais ne perturbera pas
 * les deux premiers (le P2P WebRTC est between the two first peers).
 */
@Component
public class SignalingHandler extends TextWebSocketHandler {

    // roomId -> ensemble des sessions WebSocket actives
    private final Map<String, Set<WebSocketSession>> rooms = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String roomId = extractRoomId(session);
        rooms.computeIfAbsent(roomId, k -> ConcurrentHashMap.newKeySet()).add(session);
        System.out.printf("[video-service] session %s joined room %s (room size: %d)%n",
                session.getId(), roomId, rooms.get(roomId).size());
    }

    @Override
    protected void handleTextMessage(WebSocketSession sender, TextMessage message) {
        String roomId = extractRoomId(sender);
        Set<WebSocketSession> room = rooms.getOrDefault(roomId, Set.of());

        // relayer à tous les AUTRES participants de la room
        for (WebSocketSession target : room) {
            if (!target.getId().equals(sender.getId()) && target.isOpen()) {
                try {
                    target.sendMessage(message);
                } catch (IOException e) {
                    System.err.printf("[video-service] failed to relay to %s: %s%n",
                            target.getId(), e.getMessage());
                }
            }
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String roomId = extractRoomId(session);
        Set<WebSocketSession> room = rooms.get(roomId);
        if (room != null) {
            room.remove(session);
            if (room.isEmpty()) {
                rooms.remove(roomId);
                System.out.printf("[video-service] room %s closed%n", roomId);
            }
        }
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) {
        System.err.printf("[video-service] transport error on session %s: %s%n",
                session.getId(), exception.getMessage());
    }

    /**
     * Extrait le roomId depuis le chemin URI.
     * URL attendue : /signal/{roomId}
     */
    private String extractRoomId(WebSocketSession session) {
        String path = session.getUri().getPath();
        return path.substring(path.lastIndexOf('/') + 1);
    }
}
