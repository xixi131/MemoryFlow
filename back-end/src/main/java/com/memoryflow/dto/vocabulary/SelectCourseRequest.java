package com.memoryflow.dto.vocabulary;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class SelectCourseRequest {
    @NotNull(message = "课程ID不能为空")
    private Long courseId;

    @Min(value = 1, message = "每日目标至少为1")
    private Integer dailyGoal = 20;
}
