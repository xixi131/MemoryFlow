package com.memoryflow.dto.todo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TodoStatsDTO {
    private Integer totalTasks;
    private Integer pendingTasks;
    private Integer completedTasks;
    private Integer dueToday;
    private Integer dueTomorrow;
    private Integer overdueTasks;
    private Integer highPriorityPending;
    private Integer createdThisWeek;
    private Integer completedThisWeek;
    private Double weekCompletionRate;
}

