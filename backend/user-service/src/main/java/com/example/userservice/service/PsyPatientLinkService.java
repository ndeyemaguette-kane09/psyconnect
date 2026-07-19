package com.example.userservice.service;

import java.util.List;

public interface PsyPatientLinkService {

    // ajoute un patient à la liste de suivi du psy.
    // callerAuthUserId doit correspondre au psy propriétaire de psyProfileId.
    void addFollowedPatient(Long psyProfileId, Long patientProfileId, Long callerAuthUserId);

    // retire le patient du suivi.
    void removeFollowedPatient(Long psyProfileId, Long patientProfileId, Long callerAuthUserId);

    // Retourne la liste des patientProfileId suivis par ce psychologue.
    // le psy peut voir sa propre liste ; l'admin peut aussi (pour la supervision).
    List<Long> getFollowedPatientIds(Long psyProfileId, Long callerAuthUserId);

    // vérifie si le lien existe (endpoint public pour que le frontend sache
    // quel état afficher sans charger toute la liste).
    boolean isFollowing(Long psyProfileId, Long patientProfileId);
}
