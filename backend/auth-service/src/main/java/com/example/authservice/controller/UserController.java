package com.example.authservice.controller;

import com.example.authservice.entity.User;
import com.example.authservice.repository.UserRepository;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/users")
public class UserController {

    private final UserRepository userRepository;

    public UserController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @GetMapping("/profile")
    public Map<String, Object> getProfile(
            Authentication authentication
    ) {

        return Map.of(
                "email", authentication.getName(),
                "message", "Protected profile access successful"
        );
    }

    @GetMapping("/{id}/pseudo")
    public ResponseEntity<Map<String, String>> getPseudo(
            @PathVariable Long id
    ) {

        return userRepository.findById(id)
                .map(User::getPseudo)
                .map(pseudo -> ResponseEntity.ok(Map.of("pseudo", pseudo)))
                .orElse(ResponseEntity.notFound().build());
    }
}
