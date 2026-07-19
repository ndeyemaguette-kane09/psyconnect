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

// stockage des preuves photo/PDF jointes aux signalements (repertoire separe
// de FileStorageService pour ne pas melanger justificatifs psy et preuves patients)
@Component
public class EvidenceStorageService {

    private final Path root;

    public EvidenceStorageService(
            @Value("${app.uploads.report-evidences-dir:uploads/report-evidences}")
            String uploadsDir
    ) {
        this.root = Paths.get(uploadsDir).toAbsolutePath().normalize();
        try {
            Files.createDirectories(root);
        } catch (IOException e) {
            throw new IllegalStateException(
                    "Impossible de créer le dossier des preuves de signalement : " + root, e);
        }
    }

    // renvoie le nom généré (UUID + extension originale)
    public String store(MultipartFile file) {
        String original = StringUtils.cleanPath(
                file.getOriginalFilename() == null ? "evidence" : file.getOriginalFilename());
        String extension = "";
        int dot = original.lastIndexOf('.');
        if (dot >= 0) extension = original.substring(dot);
        String generatedName = UUID.randomUUID() + extension;
        Path target = root.resolve(generatedName).normalize();
        if (!target.getParent().equals(root)) {
            throw new IllegalArgumentException("Nom de fichier invalide.");
        }
        try {
            Files.copy(file.getInputStream(), target);
        } catch (IOException e) {
            throw new IllegalStateException("Impossible d'enregistrer la preuve.", e);
        }
        return generatedName;
    }

    public byte[] load(String storedFileName) {
        try {
            return Files.readAllBytes(root.resolve(storedFileName).normalize());
        } catch (IOException e) {
            throw new ResourceNotFoundException("Fichier preuve introuvable.");
        }
    }

    public void delete(String storedFileName) {
        if (storedFileName == null) return;
        try {
            Files.deleteIfExists(root.resolve(storedFileName).normalize());
        } catch (IOException ignored) {
        }
    }
}
