package com.memoryflow.dto.todo;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CreateTodoSubtaskRequest {

    @NotBlank(message = "子任务标题不能为空")
    @Size(max = 255, message = "子任务标题长度不能超过255")
    private String title;
}

