package com.memoryflow.dto.calendar;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CalendarRecordDTO {
    private LocalDate date;
    private String status; // completed, partial, missed, none
    private Integer studyMinutes;
    private Integer pointsCompleted;
    private Integer wordsLearned;
    private Boolean isToday;
}
