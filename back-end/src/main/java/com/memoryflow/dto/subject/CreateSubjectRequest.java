package com.memoryflow.dto.subject;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CreateSubjectRequest {

    @NotNull(message = "目标ID不能为空")
    private Long goalId;

    @NotBlank(message = "科目名称不能为空")
    private String title;

    /**
     * DSL格式的内容
     * @ 章节
     * @@ 要点
     * { 详细内容 }
     */
    private String content;
}
