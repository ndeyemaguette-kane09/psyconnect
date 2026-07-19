package com.example.userservice.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.userservice.entity.Broadcast;

public interface BroadcastRepository extends JpaRepository<Broadcast, Long> {

    // toutes les annonces, du plus récent au plus ancien
    List<Broadcast> findAllByOrderBySentAtDesc();

    // annonces ciblant une audience donnée OU ALL : utilisé pour filtrer
    // ce qu'un patient ou un psy doit voir (il ne voit pas les annonces
    // adressées à l'audience opposée)
    List<Broadcast> findByAudienceInOrderBySentAtDesc(List<String> audiences);
}
