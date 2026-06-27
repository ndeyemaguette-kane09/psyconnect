package com.example.authservice.service;

import com.example.authservice.dto.AdminStatsResponse;
import com.example.authservice.dto.UserAdminResponse;

import java.util.List;

public interface AdminService {

    List<UserAdminResponse> listUsers();

    UserAdminResponse setUserEnabled(Long id, boolean enabled, String callerEmail);

    void deleteUser(Long id, String callerEmail);

    UserAdminResponse resetPassword(Long id, String newPassword, String callerEmail);

    AdminStatsResponse getStats();
}
