package com.memoryflow.dto.todo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TodoSubtaskDTO {
    private Long id;
    private Long taskId;
    private String title;
    private String status;
    private Integer sortOrder;
    private String completedAt;
}

