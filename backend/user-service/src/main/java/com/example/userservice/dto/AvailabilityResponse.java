package com.example.userservice.dto;

public class AvailabilityResponse {

    private Long id;
    private Long psychologistProfileId;
    private Integer dayOfWeek;      // 1=Lundi ... 7=Dimanche
    private Integer startHour;
    private Integer endHour;
    private Integer slotDurationMinutes;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getPsychologistProfileId() { return psychologistProfileId; }
    public void setPsychologistProfileId(Long psychologistProfileId) {
        this.psychologistProfileId = psychologistProfileId;
    }

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
