package com.example.appointmentservice.dto;

import java.math.BigDecimal;

/**
 * Revenu d'un psychologue, calculé à partir de ses paiements COMPLETED.
 * Revenu NET (après commission), pas le brut payé par les patients ; le
 * taux est renvoyé pour que l'écran puisse expliquer l'écart brut/net.
 */
public class PsychologistRevenueResponse {

    private BigDecimal commissionRatePercent;

    private BigDecimal totalGrossRevenue;
    private BigDecimal totalNetRevenue;

    private BigDecimal currentMonthGrossRevenue;
    private BigDecimal currentMonthNetRevenue;

    public BigDecimal getCommissionRatePercent() {
        return commissionRatePercent;
    }

    public void setCommissionRatePercent(BigDecimal commissionRatePercent) {
        this.commissionRatePercent = commissionRatePercent;
    }

    public BigDecimal getTotalGrossRevenue() {
        return totalGrossRevenue;
    }

    public void setTotalGrossRevenue(BigDecimal totalGrossRevenue) {
        this.totalGrossRevenue = totalGrossRevenue;
    }

    public BigDecimal getTotalNetRevenue() {
        return totalNetRevenue;
    }

    public void setTotalNetRevenue(BigDecimal totalNetRevenue) {
        this.totalNetRevenue = totalNetRevenue;
    }

    public BigDecimal getCurrentMonthGrossRevenue() {
        return currentMonthGrossRevenue;
    }

    public void setCurrentMonthGrossRevenue(BigDecimal currentMonthGrossRevenue) {
        this.currentMonthGrossRevenue = currentMonthGrossRevenue;
    }

    public BigDecimal getCurrentMonthNetRevenue() {
        return currentMonthNetRevenue;
    }

    public void setCurrentMonthNetRevenue(BigDecimal currentMonthNetRevenue) {
        this.currentMonthNetRevenue = currentMonthNetRevenue;
    }
}
