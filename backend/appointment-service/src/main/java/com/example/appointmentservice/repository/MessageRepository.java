package com.example.appointmentservice.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.appointmentservice.entity.Message;

public interface MessageRepository extends JpaRepository<Message, Long> {

    List<Message> findByConversationIdOrderBySentAtAsc(Long conversationId);

    Optional<Message> findFirstByConversationIdOrderBySentAtDesc(Long conversationId);

    /** Messages non envoyés par moi et pas encore lus — utilisé pour le badge "non lu". */
    long countByConversationIdAndSenderAuthUserIdNotAndReadAtIsNull(
            Long conversationId,
            Long senderAuthUserId
    );

    List<Message> findByConversationIdAndSenderAuthUserIdNotAndReadAtIsNull(
            Long conversationId,
            Long senderAuthUserId
    );
}
