package com.memoryflow.dto.goal;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class CreateGoalRequest {

    @NotBlank(message = "目标名称不能为空")
    private String title;

    private String labelType = "priority"; // priority, daily, longterm

    private String dueDate; // YYYY-MM-DD
}
