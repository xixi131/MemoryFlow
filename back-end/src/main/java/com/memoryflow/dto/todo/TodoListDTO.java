package com.memoryflow.dto.todo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TodoListDTO {
    private Long id;
    private String name;
    private String color;
    private String icon;
    private Integer sortOrder;
    private Boolean isDefault;
}

