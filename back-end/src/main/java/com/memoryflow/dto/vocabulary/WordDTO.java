package com.memoryflow.dto.vocabulary;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WordDTO {
    private Long id;
    private String word;
    private String phonetic;
    private String definition;
    private String translation;
    private String tag;
    private Integer collins;
    private Integer oxford;
    private Integer bnc;
    private Integer frq;
    private String pos;
    private String audioUrl;
    private String exchange;
    private String detail;

    // 用户学习状态
    private Boolean isLearned;
    private Integer currentReviewStage;
    private String nextReviewDate;
    private Integer familiarity;
    private Integer correctCount;
    private Integer wrongCount;
}
