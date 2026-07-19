package com.example.aicompanionservice.config;

import com.example.aicompanionservice.service.CompanionPrompts;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ChatClientConfig {

    /**
     * Le ChatModel (OllamaChatModel) est auto-configure par Spring AI a
     * partir de spring.ai.ollama.* dans application.properties. On construit
     * ici le ChatClient avec le prompt systeme par defaut : il sera ajoute
     * automatiquement devant chaque conversation, sans avoir a le repeter
     * dans CompanionService.
     */
    @Bean
    public ChatClient chatClient(ChatModel chatModel) {
        return ChatClient.builder(chatModel)
                .defaultSystem(CompanionPrompts.SYSTEM_PROMPT)
                .build();
    }
}
