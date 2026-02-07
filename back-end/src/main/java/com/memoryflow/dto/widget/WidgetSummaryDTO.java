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
    private List<SubjectLight> subjects;

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
