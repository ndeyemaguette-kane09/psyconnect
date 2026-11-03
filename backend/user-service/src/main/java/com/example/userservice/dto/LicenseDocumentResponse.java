package com.example.userservice.dto;

// octets du justificatif et son content-type d'origine
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
