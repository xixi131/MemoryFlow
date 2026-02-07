package com.memoryflow.dto.vocabulary;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class LearnWordRequest {
    @NotNull(message = "单词ID不能为空")
    private Long wordId;

    private Long courseId;
}
