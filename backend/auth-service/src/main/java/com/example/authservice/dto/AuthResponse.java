package com.example.authservice.dto;

public class AuthResponse {

    private String token;
    private String role;
    private Long userId;
    private String pseudo;

    public AuthResponse() {
    }

    public AuthResponse(
            String token,
            String role,
            Long userId,
            String pseudo
    ) {
        this.token = token;
        this.role = role;
        this.userId = userId;
        this.pseudo = pseudo;
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getPseudo() {
        return pseudo;
    }

    public void setPseudo(String pseudo) {
        this.pseudo = pseudo;
    }
}
