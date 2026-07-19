package com.example.aicompanionservice.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.function.Function;

@Service
public class JwtService {

    @Value("${jwt.secret}")
    private String secretKey;

    public String extractUsername(
            String token
    ) {

        return extractClaim(
                token,
                Claims::getSubject
        );
    }

    public String extractRole(String token) {
        return extractClaim(
                token,
                claims -> claims.get("role", String.class)
        );
    }

    public Long extractUserId(String token) {
        return extractClaim(token, claims -> {
            Object val = claims.get("userId");
            if (val == null) return null;
            if (val instanceof Long) return (Long) val;
            if (val instanceof Number) return ((Number) val).longValue();
            return Long.parseLong(val.toString());
        });
    }

    public <T> T extractClaim(
            String token,
            Function<Claims, T> claimsResolver
    ) {

        final Claims claims =
                extractAllClaims(token);

        return claimsResolver.apply(claims);
    }

    private Claims extractAllClaims(
            String token
    ) {

        return Jwts.parser()
                .setSigningKey(secretKey)
                .parseClaimsJws(token)
                .getBody();
    }

    public boolean isTokenValid(
            String token
    ) {

        try {

            extractAllClaims(token);

            return true;

        } catch (Exception e) {

            return false;
        }
    }
}
