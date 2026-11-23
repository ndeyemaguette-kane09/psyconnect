package com.example.authservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.authservice.entity.AccessRevocation;

public interface AccessRevocationRepository extends JpaRepository<AccessRevocation, Long> {
}
