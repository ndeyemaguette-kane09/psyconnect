package com.example.aicompanionservice.service;

import com.example.aicompanionservice.dto.ChatRequest;
import com.example.aicompanionservice.dto.ChatResponse;
import com.example.aicompanionservice.dto.ChatTurn;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CompanionService {

    private final ChatClient chatClient;
    private final RiskDetectionService riskDetectionService;

    public CompanionService(
            ChatClient chatClient,
            RiskDetectionService riskDetectionService
    ) {
        this.chatClient = chatClient;
        this.riskDetectionService = riskDetectionService;
    }

    public ChatResponse respond(ChatRequest request) {

        // Garde-fou en premier : si le dernier message de l'utilisateur (ou
        // l'historique recent qu'il vient d'envoyer) contient un signal de
        // detresse, on ne contacte JAMAIS le modele. On renvoie directement
        // le message fixe, deterministe, avec les numeros d'urgence.
        if (riskDetectionService.isRisky(request.message())) {
            return new ChatResponse(CompanionPrompts.SAFETY_FALLBACK_MESSAGE, true);
        }

        List<Message> messages = request.historyOrEmpty().stream()
                .<Message>map(this::toSpringAiMessage)
                .toList();

        String reply = chatClient.prompt()
                .messages(messages)
                .user(request.message())
                .call()
                .content();

        return new ChatResponse(reply, false);
    }

    private Message toSpringAiMessage(ChatTurn turn) {
        return "assistant".equals(turn.role())
                ? new AssistantMessage(turn.content())
                : new UserMessage(turn.content());
    }
}
