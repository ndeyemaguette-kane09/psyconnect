package com.example.authservice.service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Component;

@Component
public class ResetRequestThrottle {

    private static final int MAX_REQUESTS = 3;
    private static final Duration WINDOW = Duration.ofMinutes(15);
    private static final int MAX_TRACKED_EMAILS = 10_000;

    private final Map<String, Deque<Instant>> history = new ConcurrentHashMap<>();

    public boolean allow(String email) {
        if (email == null || email.isBlank()) {
            return false;
        }

        if (history.size() > MAX_TRACKED_EMAILS) {
            purge();
        }

        String key = email.trim().toLowerCase(Locale.ROOT);
        Deque<Instant> attempts =
                history.computeIfAbsent(key, k -> new ArrayDeque<>());

        synchronized (attempts) {
            Instant cutoff = Instant.now().minus(WINDOW);
            while (!attempts.isEmpty() && attempts.peekFirst().isBefore(cutoff)) {
                attempts.pollFirst();
            }
            if (attempts.size() >= MAX_REQUESTS) {
                return false;
            }
            attempts.addLast(Instant.now());
            return true;
        }
    }

    private void purge() {
        Instant cutoff = Instant.now().minus(WINDOW);
        history.entrySet().removeIf(entry -> {
            Deque<Instant> attempts = entry.getValue();
            synchronized (attempts) {
                while (!attempts.isEmpty() && attempts.peekFirst().isBefore(cutoff)) {
                    attempts.pollFirst();
                }
                return attempts.isEmpty();
            }
        });
    }
}
