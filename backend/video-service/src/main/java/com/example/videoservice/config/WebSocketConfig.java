package com.example.videoservice.config;

import com.example.videoservice.handler.SignalingHandler;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

/**
 * Enregistre le SignalingHandler sur /signal/{roomId}.
 *
 * Pas de SockJS : Flutter utilise un WebSocket natif (dart:io / web_socket_channel)
 * qui n'a pas besoin du fallback HTTP long-polling de SockJS.
 *
 * AllowedOrigins("*") : acceptable pour un projet académique local.
 * En production, restreindre à l'origine de l'app.
 */
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    @Autowired
    private SignalingHandler signalingHandler;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(signalingHandler, "/signal/*")
                .setAllowedOrigins("*");
    }
}
