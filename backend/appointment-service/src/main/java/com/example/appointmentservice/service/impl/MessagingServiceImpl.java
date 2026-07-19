package com.example.appointmentservice.service.impl;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.example.appointmentservice.dto.ConversationResponse;
import com.example.appointmentservice.dto.MessageResponse;
import com.example.appointmentservice.dto.SendMessageRequest;
import com.example.appointmentservice.dto.StartConversationRequest;
import com.example.appointmentservice.entity.Conversation;
import com.example.appointmentservice.entity.Message;
import com.example.appointmentservice.exception.ForbiddenOperationException;
import com.example.appointmentservice.exception.ResourceNotFoundException;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.ConversationRepository;
import com.example.appointmentservice.repository.MessageRepository;
import com.example.appointmentservice.security.SecurityUtils;
import com.example.appointmentservice.service.MessagingService;
import com.example.appointmentservice.service.OwnershipResolver;

// Conversation possible uniquement si patient et psychologue ont déjà un rendez-vous ensemble
// chaque conversation reservee a ses 2 participants
@Service
public class MessagingServiceImpl implements MessagingService {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final AppointmentRepository appointmentRepository;
    private final OwnershipResolver ownershipResolver;

    public MessagingServiceImpl(
            ConversationRepository conversationRepository,
            MessageRepository messageRepository,
            AppointmentRepository appointmentRepository,
            OwnershipResolver ownershipResolver
    ) {
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.appointmentRepository = appointmentRepository;
        this.ownershipResolver = ownershipResolver;
    }

    private void checkParticipant(Conversation conversation) {

        if (SecurityUtils.hasRole("PATIENT")
                && ownershipResolver.resolveOwnPatientId().equals(conversation.getPatientId())) {
            return;
        }

        if (SecurityUtils.hasRole("PSYCHOLOGIST")
                && ownershipResolver.resolveOwnPsychologistId().equals(conversation.getPsychologistId())) {
            return;
        }

        throw new ForbiddenOperationException(
                "Cette conversation ne vous appartient pas"
        );
    }

    @Override
    public List<ConversationResponse> listMyConversations() {

        List<Conversation> conversations;

        if (SecurityUtils.hasRole("PATIENT")) {
            Long patientId = ownershipResolver.resolveOwnPatientId();
            conversations = conversationRepository.findByPatientIdOrderByLastMessageAtDesc(patientId);
        } else if (SecurityUtils.hasRole("PSYCHOLOGIST")) {
            Long psychologistId = ownershipResolver.resolveOwnPsychologistId();
            conversations = conversationRepository.findByPsychologistIdOrderByLastMessageAtDesc(psychologistId);
        } else {
            throw new ForbiddenOperationException(
                    "Seuls les patients et psychologues ont accès à la messagerie"
            );
        }

        return conversations.stream()
                .map(this::mapToConversationResponse)
                .collect(Collectors.toList());
    }

    @Override
    public ConversationResponse startOrGetConversation(StartConversationRequest request) {

        Long patientId;
        Long psychologistId;

        if (SecurityUtils.hasRole("PATIENT")) {
            patientId = ownershipResolver.resolveOwnPatientId();
            psychologistId = request.getOtherProfileId();
        } else if (SecurityUtils.hasRole("PSYCHOLOGIST")) {
            psychologistId = ownershipResolver.resolveOwnPsychologistId();
            patientId = request.getOtherProfileId();
        } else {
            throw new ForbiddenOperationException(
                    "Seuls les patients et psychologues ont accès à la messagerie"
            );
        }

        boolean hasRelationship =
                appointmentRepository.existsByPatientIdAndPsychologistId(patientId, psychologistId);

        if (!hasRelationship) {
            throw new ForbiddenOperationException(
                    "Impossible de démarrer une conversation sans rendez-vous en commun"
            );
        }

        Conversation conversation = conversationRepository
                .findByPatientIdAndPsychologistId(patientId, psychologistId)
                .orElseGet(() -> {
                    Conversation created = new Conversation();
                    created.setPatientId(patientId);
                    created.setPsychologistId(psychologistId);
                    return conversationRepository.save(created);
                });

        return mapToConversationResponse(conversation);
    }

    @Override
    public List<MessageResponse> listMessages(Long conversationId) {

        Conversation conversation = findConversationOrThrow(conversationId);

        checkParticipant(conversation);

        return messageRepository.findByConversationIdOrderBySentAtAsc(conversationId)
                .stream()
                .map(this::mapToMessageResponse)
                .collect(Collectors.toList());
    }

    @Override
    public MessageResponse sendMessage(Long conversationId, SendMessageRequest request) {

        Conversation conversation = findConversationOrThrow(conversationId);

        checkParticipant(conversation);

        Message message = new Message();
        message.setConversationId(conversationId);
        message.setSenderAuthUserId(SecurityUtils.currentAuthUserId());
        message.setContent(request.getContent());

        Message savedMessage = messageRepository.save(message);

        conversation.setLastMessageAt(savedMessage.getSentAt());
        conversationRepository.save(conversation);

        return mapToMessageResponse(savedMessage);
    }

    @Override
    public void markConversationRead(Long conversationId) {

        Conversation conversation = findConversationOrThrow(conversationId);

        checkParticipant(conversation);

        Long myAuthUserId = SecurityUtils.currentAuthUserId();

        List<Message> unread = messageRepository
                .findByConversationIdAndSenderAuthUserIdNotAndReadAtIsNull(conversationId, myAuthUserId);

        LocalDateTime now = LocalDateTime.now();
        unread.forEach(m -> m.setReadAt(now));
        messageRepository.saveAll(unread);
    }

    private Conversation findConversationOrThrow(Long conversationId) {
        return conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation non trouvée"));
    }

    private ConversationResponse mapToConversationResponse(Conversation conversation) {

        ConversationResponse response = new ConversationResponse();

        response.setId(conversation.getId());
        response.setPatientId(conversation.getPatientId());
        response.setPsychologistId(conversation.getPsychologistId());
        response.setCreatedAt(conversation.getCreatedAt());
        response.setLastMessageAt(conversation.getLastMessageAt());

        Optional<Message> lastMessage =
                messageRepository.findFirstByConversationIdOrderBySentAtDesc(conversation.getId());
        response.setLastMessagePreview(lastMessage.map(Message::getContent).orElse(null));

        Long myAuthUserId = SecurityUtils.currentAuthUserId();
        response.setUnreadCount(
                messageRepository.countByConversationIdAndSenderAuthUserIdNotAndReadAtIsNull(
                        conversation.getId(),
                        myAuthUserId
                )
        );

        return response;
    }

    private MessageResponse mapToMessageResponse(Message message) {

        MessageResponse response = new MessageResponse();

        response.setId(message.getId());
        response.setConversationId(message.getConversationId());
        response.setSenderAuthUserId(message.getSenderAuthUserId());
        response.setContent(message.getContent());
        response.setSentAt(message.getSentAt());
        response.setReadAt(message.getReadAt());

        return response;
    }
}
