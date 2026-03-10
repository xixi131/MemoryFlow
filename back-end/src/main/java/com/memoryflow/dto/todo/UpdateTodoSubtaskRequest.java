package com.memoryflow.dto.todo;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UpdateTodoSubtaskRequest {

    @Size(max = 255, message = "子任务标题长度不能超过255")
    private String title;

    /**
     * todo / completed
     */
    private String status;

    private Integer sortOrder;
}

