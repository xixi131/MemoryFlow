package com.memoryflow.dto.todo;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TodoTrendCountDTO {
    private LocalDate date;
    private Integer taskCount;
}
