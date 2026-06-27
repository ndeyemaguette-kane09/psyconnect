package com.example.userservice.dto;

/**
 * Contenu binaire du justificatif d'un psychologue + son content-type
 * d'origine, renvoyé par GET /psychologists/{id}/license-document.
 */
public class LicenseDocumentResponse {

    private final byte[] data;
    private final String contentType;

    public LicenseDocumentResponse(byte[] data, String contentType) {
        this.data = data;
        this.contentType = contentType;
    }

    public byte[] getData() {
        return data;
    }

    public String getContentType() {
        return contentType;
    }
}
