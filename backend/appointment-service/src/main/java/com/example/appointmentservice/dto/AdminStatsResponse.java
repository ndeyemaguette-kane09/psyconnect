package com.example.appointmentservice.dto;

// stats RDV pour l'onglet admin "Stats" ; les stats paiement/commission sont
// dans payment-service (PaymentAdminStatsResponse), le front fusionne les deux
public class AdminStatsResponse {

    private long totalAppointments;
    private long pendingAppointments;
    private long confirmedAppointments;
    private long completedAppointments;
    private long cancelledAppointments;
    private long rejectedAppointments;

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
}
