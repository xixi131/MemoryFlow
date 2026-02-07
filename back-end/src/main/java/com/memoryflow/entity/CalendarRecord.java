package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@TableName("calendar_records")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CalendarRecord {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("record_date")
    private LocalDate recordDate;

    @Builder.Default
    private CalendarRecordStatus status = CalendarRecordStatus.partial;

    @TableField("study_minutes")
    @Builder.Default
    private Integer studyMinutes = 0;

    @TableField("points_completed")
    @Builder.Default
    private Integer pointsCompleted = 0;

    @TableField("words_learned")
    @Builder.Default
    private Integer wordsLearned = 0;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    public enum CalendarRecordStatus {
        completed("completed"),
        partial("partial"),
        missed("missed");

        @EnumValue
        private final String value;

        CalendarRecordStatus(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }
}
