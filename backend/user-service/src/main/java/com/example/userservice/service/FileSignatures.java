package com.example.userservice.service;

import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;

// type réel d'un fichier d'après ses premiers octets, pas d'après ce que déclare le client
public final class FileSignatures {

    private FileSignatures() {
    }

    public static String detectContentType(MultipartFile file) {
        byte[] head = new byte[8];
        int read;
        try (InputStream in = file.getInputStream()) {
            read = in.readNBytes(head, 0, head.length);
        } catch (IOException e) {
            return null;
        }

        if (read >= 4 && head[0] == '%' && head[1] == 'P' && head[2] == 'D' && head[3] == 'F') {
            return "application/pdf";
        }
        if (read >= 8 && (head[0] & 0xFF) == 0x89 && head[1] == 'P' && head[2] == 'N' && head[3] == 'G'
                && head[4] == 0x0D && head[5] == 0x0A && head[6] == 0x1A && head[7] == 0x0A) {
            return "image/png";
        }
        if (read >= 3 && (head[0] & 0xFF) == 0xFF && (head[1] & 0xFF) == 0xD8 && (head[2] & 0xFF) == 0xFF) {
            return "image/jpeg";
        }
        return null;
    }

    public static String extensionFor(String contentType) {
        switch (contentType) {
            case "application/pdf":
                return ".pdf";
            case "image/png":
                return ".png";
            default:
                return ".jpg";
        }
    }
}
