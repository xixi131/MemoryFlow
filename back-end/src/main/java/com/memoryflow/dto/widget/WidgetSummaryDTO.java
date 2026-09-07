package com.memoryflow.dto.widget;

import lombok.Data;
import lombok.Builder;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 桌面小组件摘要数据
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WidgetSummaryDTO {

    private Integer totalPendingReviews;
    private Integer totalCompletedToday;
    private String reminderTime;
    /**
     * 复习提醒总开关，来自用户设置 reminder_enabled。
     * 关闭时桌面灵动岛不应再触发任何复习提醒。
     */
    private Boolean reminderEnabled;
    private List<SubjectLight> subjects;
    /**
     * 今日待复习的具体要点，供灵动岛/小组件直接展示复习内容（而不是科目名）。
     */
    private List<ReviewItem> reviewItems;

    /**
     * 单条待复习内容，与网页「今日聚焦」列表展示的信息保持一致。
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ReviewItem {
        private Long id;
        private Long subjectId;
        private Long chapterId;
        /** 要点标题，例如「子串」 */
        private String title;
        /** 所属章节标题，例如「第 1 周 · 数组与字符串基础（24 题）」 */
        private String chapterTitle;
        private String subjectTitle;
        /** 学习日期，ISO-8601 字符串 */
        private String learnedAt;
        private String nextReviewDate;
        private Boolean overdue;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SubjectLight {
        private Long id;
        private String title;
        private String icon;
        private String colorClass;
        private Integer progress;
        private Integer pendingReviewCount;
        /**
         * 灯状态: green-无待复习, yellow-今日待复习, red-有逾期
         */
        private String lightStatus;
        private String goalTitle;
    }
}
