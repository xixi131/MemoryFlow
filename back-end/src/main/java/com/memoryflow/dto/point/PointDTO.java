package com.memoryflow.dto.point;

import lombok.Data;
import lombok.Builder;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PointDTO {

    private Long id;
    private Long chapterId;
    private Long subjectId;
    private String title;
    private String content;
    private String status;
    private Boolean isLearned;
    private String learnedAt;
    private Integer currentReviewStage;
    private LocalDate nextReviewDate;
    private String lastReviewAt;
    private Boolean reviewCompleted;
    private Boolean needsReview;
    private Integer overdueDays;
    private String reviewProgressDescription;

    // 关联信息
    private String chapterTitle;
    private String subjectTitle;
    private String goalTitle;
}
