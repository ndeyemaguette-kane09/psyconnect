package com.example.authservice.dto;

// devCode est null en temps normal. Il n'est rempli que si
// app.password-reset.expose-code-in-response=true (mode démo/dev tant
// qu'aucun envoi d'email réel n'est branché) — voir AuthService.forgotPassword.
// À désactiver (mettre la propriété à false) dès qu'un vrai envoi d'email existe :
// renvoyer le code dans la réponse HTTP permet à quiconque connaissant un
// email de réinitialiser ce compte sans jamais y avoir accès.
public class ForgotPasswordResponse {

    private String message;
    private String devCode;

    public ForgotPasswordResponse() {
    }

    public ForgotPasswordResponse(String message, String devCode) {
        this.message = message;
        this.devCode = devCode;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getDevCode() {
        return devCode;
    }

    public void setDevCode(String devCode) {
        this.devCode = devCode;
    }
}
