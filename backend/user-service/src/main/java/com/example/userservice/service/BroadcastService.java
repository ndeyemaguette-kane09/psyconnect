package com.example.userservice.service;

import java.util.List;

import com.example.userservice.dto.BroadcastDto;
import com.example.userservice.dto.BroadcastRequest;

public interface BroadcastService {

    // compte les profils ciblés (synchrone, rapide — juste une requête COUNT)
    int countTargets(BroadcastRequest request);

    // persiste l'annonce puis envoie les notifications en arrière-plan (@Async)
    void sendAsync(BroadcastRequest request);

    // toutes les annonces visibles par le rôle courant (PATIENTS voit ALL+PATIENTS,
    // PSYCHOLOGISTS voit ALL+PSYCHOLOGISTS, ADMIN voit tout)
    List<BroadcastDto> getBroadcastsForCurrentUser();
}
