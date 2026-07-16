package com.memoryflow.dto.todo;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TodoTrendPointDTO {
    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate date;
    private Integer createdTasks;
    private Integer completedTasks;
}
