package com.example.userservice.service;

import com.example.userservice.dto.AdminResolveSupportMessageRequest;
import com.example.userservice.dto.SupportMessageResponse;

import java.util.List;

public interface SupportMessageService {
    SupportMessageResponse createMessage(
            Long senderProfileId, String senderRole, String subject,
            String message, Long callerAuthUserId
    );
    List<SupportMessageResponse> listMessages(String statusFilter);
    SupportMessageResponse resolveMessage(Long messageId, AdminResolveSupportMessageRequest request);
    SupportMessageResponse replyToMessage(Long messageId, String reply);
}
