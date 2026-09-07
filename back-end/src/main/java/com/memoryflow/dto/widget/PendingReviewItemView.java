package com.memoryflow.dto.widget;

import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 待复习要点的扁平投影，由 PointMapper 的 JOIN 查询直接填充。
 * 只包含灵动岛/小组件展示一条复习内容所需的字段。
 */
@Data
public class PendingReviewItemView {
    private Long id;
    private Long subjectId;
    private Long chapterId;
    private String title;
    private String chapterTitle;
    private String subjectTitle;
    private LocalDateTime learnedAt;
    private LocalDate nextReviewDate;
}
