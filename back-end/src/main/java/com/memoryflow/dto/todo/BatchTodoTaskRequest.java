package com.memoryflow.dto.todo;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

import java.util.List;

@Data
public class BatchTodoTaskRequest {

    @NotEmpty(message = "任务ID列表不能为空")
    private List<Long> taskIds;

    /**
     * complete / uncomplete / delete / move-list / set-priority
     */
    @NotBlank(message = "批量操作类型不能为空")
    private String action;

    /**
     * action=move-list 时使用
     */
    private Long listId;

    /**
     * action=set-priority 时使用，high/medium/low/none
     */
    private String priority;
}

