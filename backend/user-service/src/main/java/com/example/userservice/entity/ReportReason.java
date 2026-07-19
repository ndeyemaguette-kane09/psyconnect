package com.example.userservice.entity;

public enum ReportReason {

    PRIX_ABUSIF,
    COMPORTEMENT_INAPPROPRIE,
    FAUSSES_INFORMATIONS,
    DEMANDE_PAIEMENT_HORS_APP,
    AUTRE;

    public String label() {
        return switch (this) {
            case PRIX_ABUSIF -> "Tarif abusif";
            case COMPORTEMENT_INAPPROPRIE -> "Comportement inapproprié";
            case FAUSSES_INFORMATIONS -> "Fausses informations (diplômes, expérience)";
            case DEMANDE_PAIEMENT_HORS_APP -> "Paiement demandé hors application";
            case AUTRE -> "Autre";
        };
    }
}
