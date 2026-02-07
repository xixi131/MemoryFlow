package com.memoryflow.dto.point;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CreatePointRequest {

    @NotNull(message = "章节ID不能为空")
    private Long chapterId;

    @NotBlank(message = "要点标题不能为空")
    private String title;

    private String content;
}
