package com.example.authservice.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;
import java.util.LinkedHashMap;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>>
    handleValidationExceptions(
            MethodArgumentNotValidException ex
    ) {

        Map<String, String> errors = new HashMap<>();

        ex.getBindingResult()
                .getFieldErrors()
                .forEach(error ->
                        errors.put(
                                error.getField(),
                                error.getDefaultMessage()
                        )
                );

        return ResponseEntity.badRequest().body(errors);
    }

    // Traitement prioritaire sur RuntimeException : compte désactivé par l'admin.
    // Renvoie HTTP 403 + errorCode "ACCOUNT_BANNED" pour que Flutter affiche
    // un message clair avec les coordonnées de l'administrateur.
    @ExceptionHandler(BannedAccountException.class)
    public ResponseEntity<Map<String, String>>
    handleBannedAccount(BannedAccountException ex) {

        Map<String, String> error = new LinkedHashMap<>();
        error.put("message", ex.getMessage());
        error.put("errorCode", "ACCOUNT_BANNED");

        return ResponseEntity
                .status(HttpStatus.FORBIDDEN)
                .body(error);
    }

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<Map<String, String>>
    handleRuntimeException(
            RuntimeException ex
    ) {

        Map<String, String> error = new HashMap<>();

        error.put("message", ex.getMessage());

        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(error);
    }
}