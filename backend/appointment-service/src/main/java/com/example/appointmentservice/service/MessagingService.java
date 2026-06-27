package com.example.appointmentservice.service;

import java.util.List;

import com.example.appointmentservice.dto.ConversationResponse;
import com.example.appointmentservice.dto.MessageResponse;
import com.example.appointmentservice.dto.SendMessageRequest;
import com.example.appointmentservice.dto.StartConversationRequest;

public interface MessagingService {

    List<ConversationResponse> listMyConversations();

    ConversationResponse startOrGetConversation(StartConversationRequest request);

    List<MessageResponse> listMessages(Long conversationId);

    MessageResponse sendMessage(Long conversationId, SendMessageRequest request);

    void markConversationRead(Long conversationId);
}
