package com.memoryflow.dto.todo;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class CreateTodoTaskRequest {

    @NotBlank(message = "任务标题不能为空")
    @Size(max = 255, message = "任务标题长度不能超过255")
    private String title;

    private String descriptionMd;

    private Long listId;

    /**
     * high / medium / low / none
     */
    private String priority;

    /**
     * YYYY-MM-DD
     */
    private String dueDate;

    /**
     * HH:mm 或 HH:mm:ss
     */
    private String dueTime;

    private Integer sortOrder;

    private List<Long> tagIds;
}

