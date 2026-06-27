package com.example.appointmentservice.dto;

import java.math.BigDecimal;

public class AdminStatsResponse {

    private long totalAppointments;
    private long pendingAppointments;
    private long confirmedAppointments;
    private long completedAppointments;
    private long cancelledAppointments;
    private long rejectedAppointments;

    private long totalPayments;
    private long completedPayments;
    private BigDecimal totalRevenue;

    // Part de revenus de l'administrateur — demande explicite : préciser
    // que la plateforme prélève une commission plutôt que de n'afficher
    // que le revenu brut total. Taux réglable via
    // PUT /admin/platform-settings/commission-rate (cf. AdminController).
    private BigDecimal commissionRatePercent;
    private BigDecimal platformRevenue;
    private BigDecimal psychologistRevenue;

    public long getTotalAppointments() {
        return totalAppointments;
    }

    public void setTotalAppointments(long totalAppointments) {
        this.totalAppointments = totalAppointments;
    }

    public long getPendingAppointments() {
        return pendingAppointments;
    }

    public void setPendingAppointments(long pendingAppointments) {
        this.pendingAppointments = pendingAppointments;
    }

    public long getConfirmedAppointments() {
        return confirmedAppointments;
    }

    public void setConfirmedAppointments(long confirmedAppointments) {
        this.confirmedAppointments = confirmedAppointments;
    }

    public long getCompletedAppointments() {
        return completedAppointments;
    }

    public void setCompletedAppointments(long completedAppointments) {
        this.completedAppointments = completedAppointments;
    }

    public long getCancelledAppointments() {
        return cancelledAppointments;
    }

    public void setCancelledAppointments(long cancelledAppointments) {
        this.cancelledAppointments = cancelledAppointments;
    }

    public long getRejectedAppointments() {
        return rejectedAppointments;
    }

    public void setRejectedAppointments(long rejectedAppointments) {
        this.rejectedAppointments = rejectedAppointments;
    }

    public long getTotalPayments() {
        return totalPayments;
    }

    public void setTotalPayments(long totalPayments) {
        this.totalPayments = totalPayments;
    }

    public long getCompletedPayments() {
        return completedPayments;
    }

    public void setCompletedPayments(long completedPayments) {
        this.completedPayments = completedPayments;
    }

    public BigDecimal getTotalRevenue() {
        return totalRevenue;
    }

    public void setTotalRevenue(BigDecimal totalRevenue) {
        this.totalRevenue = totalRevenue;
    }

    public BigDecimal getCommissionRatePercent() {
        return commissionRatePercent;
    }

    public void setCommissionRatePercent(BigDecimal commissionRatePercent) {
        this.commissionRatePercent = commissionRatePercent;
    }

    public BigDecimal getPlatformRevenue() {
        return platformRevenue;
    }

    public void setPlatformRevenue(BigDecimal platformRevenue) {
        this.platformRevenue = platformRevenue;
    }

    public BigDecimal getPsychologistRevenue() {
        return psychologistRevenue;
    }

    public void setPsychologistRevenue(BigDecimal psychologistRevenue) {
        this.psychologistRevenue = psychologistRevenue;
    }
}
