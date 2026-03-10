package com.memoryflow.dto.todo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TodoTaskDTO {
    private Long id;
    private Long listId;
    private String title;
    private String descriptionMd;
    private String status;
    private String priority;
    private LocalDate dueDate;
    private LocalTime dueTime;
    private Integer sortOrder;
    private String completedAt;
    private String createdAt;
    private String updatedAt;

    private Boolean overdue;
    private Boolean dueToday;
    private Boolean dueTomorrow;

    private Integer subtaskTotal;
    private Integer subtaskCompleted;
    private Integer subtaskProgress;

    private List<TodoTagDTO> tags;
    private List<TodoSubtaskDTO> subtasks;
}

