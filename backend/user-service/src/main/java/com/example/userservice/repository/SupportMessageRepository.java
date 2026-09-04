package com.example.userservice.repository;

import com.example.userservice.entity.SupportMessage;
import com.example.userservice.entity.SupportMessageStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SupportMessageRepository extends JpaRepository<SupportMessage, Long> {

    List<SupportMessage> findAllByOrderByCreatedAtDesc();

    List<SupportMessage> findByStatusOrderByCreatedAtDesc(SupportMessageStatus status);

    long countByStatus(SupportMessageStatus status);
}
