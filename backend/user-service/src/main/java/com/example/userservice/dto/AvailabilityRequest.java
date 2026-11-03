package com.example.userservice.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

// une plage hebdo, envoyée en liste dans PUT /psychologists/{id}/availabilities
// endHour > startHour est vérifié dans AvailabilityServiceImpl
public class AvailabilityRequest {

    @NotNull
    @Min(1) @Max(7)
    private Integer dayOfWeek; // 1=Lundi ... 7=Dimanche

    @NotNull
    @Min(0) @Max(23)
    private Integer startHour;

    @NotNull
    @Min(1) @Max(24)
    private Integer endHour;

    @NotNull
    @Min(15) @Max(240)
    private Integer slotDurationMinutes; // 30, 45, 60, 90, 120

    public Integer getDayOfWeek() { return dayOfWeek; }
    public void setDayOfWeek(Integer dayOfWeek) { this.dayOfWeek = dayOfWeek; }

    public Integer getStartHour() { return startHour; }
    public void setStartHour(Integer startHour) { this.startHour = startHour; }

    public Integer getEndHour() { return endHour; }
    public void setEndHour(Integer endHour) { this.endHour = endHour; }

    public Integer getSlotDurationMinutes() { return slotDurationMinutes; }
    public void setSlotDurationMinutes(Integer slotDurationMinutes) {
        this.slotDurationMinutes = slotDurationMinutes;
    }
}
