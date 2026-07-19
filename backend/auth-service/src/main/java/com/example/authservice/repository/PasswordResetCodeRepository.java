package com.example.authservice.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.authservice.entity.PasswordResetCode;

public interface PasswordResetCodeRepository extends JpaRepository<PasswordResetCode, Long> {

    Optional<PasswordResetCode> findByUserIdAndCodeAndUsedFalse(Long userId, String code);

    // Pour invalider les anciens codes non utilisés lorsqu'un nouveau est demandé
    List<PasswordResetCode> findByUserIdAndUsedFalse(Long userId);
}
