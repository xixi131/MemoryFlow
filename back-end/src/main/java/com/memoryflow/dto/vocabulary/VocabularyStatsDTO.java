package com.memoryflow.dto.vocabulary;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VocabularyStatsDTO {
    private Integer totalLearned;        // 总学习单词数
    private Integer todayLearned;        // 今日新学单词数
    private Integer todayReviewed;       // 今日复习单词数
    private Integer pendingReviewCount;  // 待复习单词数
    private Integer totalCourses;        // 学习中的课程数
    private Integer streak;              // 连续学习天数
}
