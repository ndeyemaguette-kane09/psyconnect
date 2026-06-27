package com.example.authservice.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.authservice.entity.Role;
import com.example.authservice.entity.User;

public interface UserRepository  extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    Optional<User> findByPseudo(String pseudo);

    long countByRole(Role role);
    long countByEnabled(boolean enabled);
}
