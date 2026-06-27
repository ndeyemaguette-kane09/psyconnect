package com.example.appointmentservice.service.impl;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.example.appointmentservice.dto.ConversationResponse;
import com.example.appointmentservice.dto.MessageResponse;
import com.example.appointmentservice.dto.SendMessageRequest;
import com.example.appointmentservice.dto.StartConversationRequest;
import com.example.appointmentservice.entity.Conversation;
import com.example.appointmentservice.entity.Message;
import com.example.appointmentservice.repository.AppointmentRepository;
import com.example.appointmentservice.repository.ConversationRepository;
import com.example.appointmentservice.repository.MessageRepository;
import com.example.appointmentservice.service.OwnershipResolver;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MessagingServiceImplTest {

    @Mock
    private ConversationRepository conversationRepository;

    @Mock
    private MessageRepository messageRepository;

    @Mock
    private AppointmentRepository appointmentRepository;

    @Mock
    private OwnershipResolver ownershipResolver;

    private MessagingServiceImpl messagingService;

    /** Conservée pour pouvoir poser l'attribut "authUserId" après le setUp, selon le scénario. */
    private MockHttpServletRequest mockRequest;

    @BeforeEach
    void setUp() {
        messagingService = new MessagingServiceImpl(
                conversationRepository,
                messageRepository,
                appointmentRepository,
                ownershipResolver
        );

        mockRequest = new MockHttpServletRequest();
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(mockRequest));
    }

    @AfterEach
    void tearDown() {
        RequestContextHolder.resetRequestAttributes();
        SecurityContextHolder.clearContext();
    }

    private void authenticateAsPatientOwning(Long ownPatientId, Long authUserId) {
        SecurityContextHolder.getContext().setAuthentication(
                new TestingAuthenticationToken("patient", null, "ROLE_PATIENT")
        );
        when(ownershipResolver.resolveOwnPatientId()).thenReturn(ownPatientId);
        mockRequest.setAttribute("authUserId", authUserId);
    }

    private void authenticateAsPsychologistOwning(Long ownPsychologistId, Long authUserId) {
        SecurityContextHolder.getContext().setAuthentication(
                new TestingAuthenticationToken("psychologist", null, "ROLE_PSYCHOLOGIST")
        );
        when(ownershipResolver.resolveOwnPsychologistId()).thenReturn(ownPsychologistId);
        mockRequest.setAttribute("authUserId", authUserId);
    }

    private Conversation buildConversation(Long id, Long patientId, Long psychologistId) {
        Conversation conversation = new Conversation();
        conversation.setId(id);
        conversation.setPatientId(patientId);
        conversation.setPsychologistId(psychologistId);
        conversation.setCreatedAt(LocalDateTime.now());
        conversation.setLastMessageAt(LocalDateTime.now());
        return conversation;
    }

    @Test
    void listMyConversations_asPatient_returnsOwnConversationsSortedByActivity() {

        authenticateAsPatientOwning(10L, 1000L);

        Conversation conversation = buildConversation(1L, 10L, 20L);

        when(conversationRepository.findByPatientIdOrderByLastMessageAtDesc(10L))
                .thenReturn(List.of(conversation));
        when(messageRepository.findFirstByConversationIdOrderBySentAtDesc(1L))
                .thenReturn(Optional.empty());
        when(messageRepository.countByConversationIdAndSenderAuthUserIdNotAndReadAtIsNull(1L, 1000L))
                .thenReturn(0L);

        List<ConversationResponse> result = messagingService.listMyConversations();

        assertEquals(1, result.size());
        assertEquals(10L, result.get(0).getPatientId());
        assertEquals(20L, result.get(0).getPsychologistId());
    }

    @Test
    void startOrGetConversation_noSharedAppointment_throwsForbidden() {

        authenticateAsPatientOwning(10L, 1000L);

        when(appointmentRepository.existsByPatientIdAndPsychologistId(10L, 20L)).thenReturn(false);

        StartConversationRequest request = new StartConversationRequest();
        request.setOtherProfileId(20L);

        assertThrows(RuntimeException.class, () -> messagingService.startOrGetConversation(request));

        verify(conversationRepository, never()).save(any());
    }

    @Test
    void startOrGetConversation_existingConversation_returnsExistingWithoutCreating() {

        authenticateAsPatientOwning(10L, 1000L);

        Conversation existing = buildConversation(5L, 10L, 20L);

        when(appointmentRepository.existsByPatientIdAndPsychologistId(10L, 20L)).thenReturn(true);
        when(conversationRepository.findByPatientIdAndPsychologistId(10L, 20L))
                .thenReturn(Optional.of(existing));
        when(messageRepository.findFirstByConversationIdOrderBySentAtDesc(5L))
                .thenReturn(Optional.empty());
        when(messageRepository.countByConversationIdAndSenderAuthUserIdNotAndReadAtIsNull(5L, 1000L))
                .thenReturn(0L);

        StartConversationRequest request = new StartConversationRequest();
        request.setOtherProfileId(20L);

        ConversationResponse response = messagingService.startOrGetConversation(request);

        assertEquals(5L, response.getId());
        verify(conversationRepository, never()).save(any());
    }

    @Test
    void startOrGetConversation_newRelationship_createsConversation() {

        authenticateAsPsychologistOwning(20L, 2000L);

        when(appointmentRepository.existsByPatientIdAndPsychologistId(10L, 20L)).thenReturn(true);
        when(conversationRepository.findByPatientIdAndPsychologistId(10L, 20L))
                .thenReturn(Optional.empty());
        when(conversationRepository.save(any(Conversation.class))).thenAnswer(invocation -> {
            Conversation saved = invocation.getArgument(0);
            saved.setId(99L);
            saved.setCreatedAt(LocalDateTime.now());
            saved.setLastMessageAt(saved.getCreatedAt());
            return saved;
        });
        when(messageRepository.findFirstByConversationIdOrderBySentAtDesc(99L))
                .thenReturn(Optional.empty());
        when(messageRepository.countByConversationIdAndSenderAuthUserIdNotAndReadAtIsNull(99L, 2000L))
                .thenReturn(0L);

        StartConversationRequest request = new StartConversationRequest();
        request.setOtherProfileId(10L);

        ConversationResponse response = messagingService.startOrGetConversation(request);

        assertEquals(99L, response.getId());
        assertEquals(10L, response.getPatientId());
        assertEquals(20L, response.getPsychologistId());
    }

    @Test
    void listMessages_notParticipant_throwsForbidden() {

        authenticateAsPatientOwning(999L, 1000L);

        Conversation conversation = buildConversation(1L, 10L, 20L);

        when(conversationRepository.findById(1L)).thenReturn(Optional.of(conversation));

        assertThrows(RuntimeException.class, () -> messagingService.listMessages(1L));
    }

    @Test
    void listMessages_conversationNotFound_throws() {

        when(conversationRepository.findById(404L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> messagingService.listMessages(404L));
    }

    @Test
    void sendMessage_success_updatesLastMessageAtAndReturnsMappedResponse() {

        authenticateAsPatientOwning(10L, 1000L);

        Conversation conversation = buildConversation(1L, 10L, 20L);

        when(conversationRepository.findById(1L)).thenReturn(Optional.of(conversation));
        when(messageRepository.save(any(Message.class))).thenAnswer(invocation -> {
            Message saved = invocation.getArgument(0);
            saved.setId(50L);
            saved.setSentAt(LocalDateTime.now());
            return saved;
        });

        SendMessageRequest request = new SendMessageRequest();
        request.setContent("Bonjour docteur");

        MessageResponse response = messagingService.sendMessage(1L, request);

        assertEquals(50L, response.getId());
        assertEquals("Bonjour docteur", response.getContent());
        assertEquals(1000L, response.getSenderAuthUserId());
        assertNotNull(conversation.getLastMessageAt());

        verify(conversationRepository).save(conversation);
    }

    @Test
    void sendMessage_notParticipant_throwsAndDoesNotSave() {

        authenticateAsPatientOwning(999L, 1000L);

        Conversation conversation = buildConversation(1L, 10L, 20L);

        when(conversationRepository.findById(1L)).thenReturn(Optional.of(conversation));

        SendMessageRequest request = new SendMessageRequest();
        request.setContent("Intrusion");

        assertThrows(RuntimeException.class, () -> messagingService.sendMessage(1L, request));

        verify(messageRepository, never()).save(any());
    }

    @Test
    void markConversationRead_marksOnlyMessagesFromOtherParticipant() {

        authenticateAsPatientOwning(10L, 1000L);

        Conversation conversation = buildConversation(1L, 10L, 20L);

        Message unread1 = new Message();
        unread1.setId(1L);
        unread1.setConversationId(1L);
        unread1.setSenderAuthUserId(2000L);

        Message unread2 = new Message();
        unread2.setId(2L);
        unread2.setConversationId(1L);
        unread2.setSenderAuthUserId(2000L);

        when(conversationRepository.findById(1L)).thenReturn(Optional.of(conversation));
        when(messageRepository.findByConversationIdAndSenderAuthUserIdNotAndReadAtIsNull(1L, 1000L))
                .thenReturn(List.of(unread1, unread2));

        messagingService.markConversationRead(1L);

        assertNotNull(unread1.getReadAt());
        assertNotNull(unread2.getReadAt());
        verify(messageRepository).saveAll(List.of(unread1, unread2));
    }
}
