package com.memoryflow.dto.todo;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CreateTodoListRequest {

    @NotBlank(message = "清单名称不能为空")
    @Size(max = 100, message = "清单名称长度不能超过100")
    private String name;

    private String color;

    private String icon;
}

