package com.example.authservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import jakarta.mail.internet.MimeMessage;

@Component
public class PasswordResetMailer {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(PasswordResetMailer.class);

    private final JavaMailSender mailSender;
    private final String from;
    private final String fromName;

    public PasswordResetMailer(
            JavaMailSender mailSender,
            @Value("${app.mail.from:no-reply@psyconnect.sn}") String from,
            @Value("${app.mail.from-name:PsyConnect}") String fromName
    ) {
        this.mailSender = mailSender;
        this.from = from;
        this.fromName = fromName;
    }

    @Async
    public void sendResetCode(String to, String code, int validityMinutes) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper =
                    new MimeMessageHelper(message, false, "UTF-8");

            helper.setFrom(from, fromName);
            helper.setTo(to);
            helper.setSubject("Réinitialisation de votre mot de passe PsyConnect");
            helper.setText(buildHtml(code, validityMinutes), true);

            mailSender.send(message);
            LOGGER.info("Email de réinitialisation envoyé à {}", to);
        } catch (Exception e) {
            LOGGER.error("Échec de l'envoi de l'email de réinitialisation à {}", to, e);
        }
    }

    private String buildHtml(String code, int validityMinutes) {
        return """
                <!doctype html>
                <html lang="fr">
                <body style="margin:0;padding:0;background:#F7F5F2;">
                  <table role="presentation" width="100%%" cellpadding="0" cellspacing="0"
                         style="background:#F7F5F2;padding:32px 16px;">
                    <tr><td align="center">
                      <table role="presentation" width="100%%" cellpadding="0" cellspacing="0"
                             style="max-width:520px;background:#FFFFFF;border:1px solid #E7E4DE;">
                        <tr><td style="background:#0D7B6E;padding:22px 26px;">
                          <div style="font-family:Helvetica,Arial,sans-serif;font-size:11px;
                                      letter-spacing:2px;color:rgba(255,255,255,.75);
                                      text-transform:uppercase;">PsyConnect</div>
                          <div style="font-family:Helvetica,Arial,sans-serif;font-size:22px;
                                      font-weight:700;color:#FFFFFF;margin-top:6px;">
                            Réinitialisation de mot de passe</div>
                        </td></tr>
                        <tr><td style="padding:26px;">
                          <p style="font-family:Helvetica,Arial,sans-serif;font-size:15px;
                                    line-height:1.6;color:#1A1A2E;margin:0 0 20px;">
                            Vous avez demandé à réinitialiser votre mot de passe.
                            Saisissez le code ci-dessous dans l'application&nbsp;:
                          </p>
                          <div style="border:1px solid #E7E4DE;border-left:3px solid #0D7B6E;
                                      padding:18px;text-align:center;">
                            <div style="font-family:Helvetica,Arial,sans-serif;font-size:34px;
                                        font-weight:700;letter-spacing:10px;color:#06413A;">%s</div>
                          </div>
                          <p style="font-family:Helvetica,Arial,sans-serif;font-size:13px;
                                    line-height:1.6;color:#4A4A5E;margin:20px 0 0;">
                            Ce code est valable %d minutes et ne peut servir qu'une seule fois.
                          </p>
                          <p style="font-family:Helvetica,Arial,sans-serif;font-size:13px;
                                    line-height:1.6;color:#4A4A5E;margin:12px 0 0;">
                            Si vous n'êtes pas à l'origine de cette demande, ignorez ce message&nbsp;:
                            votre mot de passe reste inchangé. Ne communiquez ce code à personne.
                          </p>
                        </td></tr>
                        <tr><td style="border-top:1px solid #E7E4DE;padding:16px 26px;">
                          <div style="font-family:Helvetica,Arial,sans-serif;font-size:11px;
                                      color:#7A7A8C;">
                            Message automatique, merci de ne pas y répondre.
                          </div>
                        </td></tr>
                      </table>
                    </td></tr>
                  </table>
                </body>
                </html>
                """.formatted(code, validityMinutes);
    }
}
