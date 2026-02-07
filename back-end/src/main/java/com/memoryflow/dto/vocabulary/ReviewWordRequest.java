package com.memoryflow.dto.vocabulary;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class ReviewWordRequest {
    @NotNull(message = "单词ID不能为空")
    private Long wordId;

    @NotNull(message = "请指定是否答对")
    private Boolean correct;  // true=答对, false=答错
}
