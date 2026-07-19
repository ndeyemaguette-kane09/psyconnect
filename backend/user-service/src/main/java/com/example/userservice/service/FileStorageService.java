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

// stockage simple sur disque des justificatifs psy
// on garde que le nom du fichier, pas le chemin
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

    // Sauvegarde avec un nom généré (UUID + extension), renvoie ce nom
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
            // protection basique contre path traversal, au cas où
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
            // best-effort, un fichier orphelin c'est pas bloquant
        }
    }
}
