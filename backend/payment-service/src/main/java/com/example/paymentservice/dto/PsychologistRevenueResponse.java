package com.example.paymentservice.dto;

import java.math.BigDecimal;

// revenu du psy, net = apres commission
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
