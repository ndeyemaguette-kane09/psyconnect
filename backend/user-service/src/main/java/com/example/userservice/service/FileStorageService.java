package com.example.userservice.service;

import com.example.userservice.exception.ResourceNotFoundException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

/**
 * Stockage minimal sur disque des justificatifs (diplôme / carte
 * professionnelle) envoyés par les psychologues à l'inscription. Pas de
 * dépendance externe (S3, etc.) : un simple dossier local, configurable via
 * app.uploads.license-documents-dir, suffit pour le besoin actuel.
 *
 * On ne garde que le NOM de fichier généré (pas le chemin absolu) dans
 * l'entité : le chemin absolu dépend de la machine qui fait tourner le
 * service, donc le stocker en base le rendrait invalide dès qu'on change de
 * machine ou de conteneur.
 */
@Component
public class FileStorageService {

    private final Path root;

    public FileStorageService(
            @Value("${app.uploads.license-documents-dir:uploads/license-documents}")
            String uploadsDir
    ) {
        this.root = Paths.get(uploadsDir).toAbsolutePath().normalize();
        try {
            Files.createDirectories(root);
        } catch (IOException e) {
            throw new IllegalStateException(
                    "Impossible de créer le dossier de stockage des justificatifs : " + root, e);
        }
    }

    /**
     * Sauvegarde le fichier sous un nom généré (UUID) en conservant
     * l'extension d'origine, et renvoie ce nom (à stocker en base).
     */
    public String store(MultipartFile file) {
        String original = StringUtils.cleanPath(
                file.getOriginalFilename() == null ? "" : file.getOriginalFilename());
        String extension = "";
        int dot = original.lastIndexOf('.');
        if (dot >= 0) {
            extension = original.substring(dot);
        }
        String generatedName = UUID.randomUUID() + extension;
        Path target = root.resolve(generatedName).normalize();

        if (!target.getParent().equals(root)) {
            // Protection basique contre un nom de fichier malicieux
            // (path traversal) — ne devrait jamais arriver puisque le nom
            // est généré par nous, mais coûte rien à vérifier.
            throw new IllegalArgumentException("Nom de fichier invalide.");
        }

        try {
            Files.copy(file.getInputStream(), target);
        } catch (IOException e) {
            throw new IllegalStateException("Impossible d'enregistrer le justificatif.", e);
        }
        return generatedName;
    }

    public byte[] load(String storedFileName) {
        try {
            Path target = root.resolve(storedFileName).normalize();
            return Files.readAllBytes(target);
        } catch (IOException e) {
            throw new ResourceNotFoundException("Justificatif introuvable.");
        }
    }

    public void delete(String storedFileName) {
        if (storedFileName == null) return;
        try {
            Files.deleteIfExists(root.resolve(storedFileName).normalize());
        } catch (IOException ignored) {
            // Best-effort : un fichier orphelin sur disque n'est pas
            // bloquant, on ne veut pas faire échouer l'opération métier
            // (remplacement/suppression du profil) pour ça.
        }
    }
}
