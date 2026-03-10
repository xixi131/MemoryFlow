package com.memoryflow.dto.todo;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class UpdateTodoTaskStatusRequest {

    @NotNull(message = "completed 不能为空")
    private Boolean completed;
}

