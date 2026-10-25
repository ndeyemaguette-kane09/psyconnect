package com.example.sessionservice.security;

import java.util.Date;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;

@Component
public class ServiceTokenProvider {

    private static final long VALIDITY_MS = 5 * 60 * 1000;

    private final String secretKey;

    public ServiceTokenProvider(@Value("${jwt.secret}") String secretKey) {
        this.secretKey = secretKey;
    }

    public String authorizationHeader() {
        Date now = new Date();
        String token = Jwts.builder()
                .setSubject("session-service")
                .claim("role", "SERVICE")
                .setIssuedAt(now)
                .setExpiration(new Date(now.getTime() + VALIDITY_MS))
                .signWith(SignatureAlgorithm.HS256, secretKey)
                .compact();
        return "Bearer " + token;
    }
}
