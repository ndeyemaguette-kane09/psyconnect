package com.example.userservice.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class CreateOrUpdateReviewRequest {

    // Note de 1 à 5, validée dans ReviewServiceImpl
    private Integer rating;

    // optionnel
    private String comment;
}
