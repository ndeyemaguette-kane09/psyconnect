package com.example.paymentservice.dto;

import java.math.BigDecimal;
import java.util.List;

// portefeuille du psychologue : solde disponible (revenu net - retraits),
// + historique des retraits du plus recent au plus ancien.
public class PsychologistWalletResponse {

    private BigDecimal availableBalance;
    private BigDecimal totalNetRevenue;
    private BigDecimal totalWithdrawn;
    private BigDecimal commissionRatePercent;
    private List<WithdrawalResponse> withdrawals;

    public BigDecimal getAvailableBalance() { return availableBalance; }
    public void setAvailableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; }

    public BigDecimal getTotalNetRevenue() { return totalNetRevenue; }
    public void setTotalNetRevenue(BigDecimal totalNetRevenue) { this.totalNetRevenue = totalNetRevenue; }

    public BigDecimal getTotalWithdrawn() { return totalWithdrawn; }
    public void setTotalWithdrawn(BigDecimal totalWithdrawn) { this.totalWithdrawn = totalWithdrawn; }

    public BigDecimal getCommissionRatePercent() { return commissionRatePercent; }
    public void setCommissionRatePercent(BigDecimal commissionRatePercent) { this.commissionRatePercent = commissionRatePercent; }

    public List<WithdrawalResponse> getWithdrawals() { return withdrawals; }
    public void setWithdrawals(List<WithdrawalResponse> withdrawals) { this.withdrawals = withdrawals; }
}
