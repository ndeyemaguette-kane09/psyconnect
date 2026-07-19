package com.example.paymentservice.dto;

import java.math.BigDecimal;

public class PlatformSettingsResponse {

    private BigDecimal commissionRatePercent;

    public BigDecimal getCommissionRatePercent() {
        return commissionRatePercent;
    }

    public void setCommissionRatePercent(BigDecimal commissionRatePercent) {
        this.commissionRatePercent = commissionRatePercent;
    }
}
