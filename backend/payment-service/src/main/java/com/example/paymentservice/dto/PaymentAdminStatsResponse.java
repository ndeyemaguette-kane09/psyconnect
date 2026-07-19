package com.example.paymentservice.dto;

import java.math.BigDecimal;

// stats paiement/commission pour l'onglet admin "Stats" ; les stats RDV
// restent côté appointment-service (GET /admin/stats/appointments), le
// front fusionne les deux réponses
public class PaymentAdminStatsResponse {

    private long totalPayments;
    private long completedPayments;
    private BigDecimal totalRevenue;

    private BigDecimal commissionRatePercent;
    private BigDecimal platformRevenue;
    private BigDecimal psychologistRevenue;

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
