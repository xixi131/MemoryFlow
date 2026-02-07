package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import com.memoryflow.config.EbbinghausConfig;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@TableName("points")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Point {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("chapter_id")
    private Long chapterId;

    @TableField("subject_id")
    private Long subjectId;

    @TableField("user_id")
    private Long userId;

    private String title;

    @TableField("content") // 对应数据库 MEDIUMTEXT 类型
    private String content;

    @Builder.Default
    private PointStatus status = PointStatus.pending;

    @TableField("is_learned")
    @Builder.Default
    private Boolean isLearned = false;

    @TableField("learned_at")
    private LocalDateTime learnedAt;

    @TableField("current_review_stage")
    @Builder.Default
    private Integer currentReviewStage = 0;

    @TableField("next_review_date")
    private LocalDate nextReviewDate;

    @TableField("last_review_at")
    private LocalDateTime lastReviewAt;

    @TableField("review_completed")
    @Builder.Default
    private Boolean reviewCompleted = false;

    @TableField("sort_order")
    @Builder.Default
    private Integer sortOrder = 0;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    // ========== 枚举 ==========

    public enum PointStatus {
        pending("pending"),
        in_progress("in-progress"),
        completed("completed");

        @EnumValue
        private final String value;

        PointStatus(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    // ========== 充血模型方法 - 艾宾浩斯核心逻辑 ==========

    /**
     * 标记为已学习（首次学习）
     * 触发艾宾浩斯复习计划
     */
    public void markAsLearned(EbbinghausConfig config) {
        if (!this.isLearned) {
            this.isLearned = true;
            this.learnedAt = LocalDateTime.now();
            this.status = PointStatus.in_progress;

            // 开始第一个复习阶段
            this.currentReviewStage = 1;
            this.nextReviewDate = LocalDate.now().plusDays(config.getIntervalDays(1));
        }
    }

    /**
     * 取消已学习状态
     */
    public void unmarkAsLearned() {
        this.isLearned = false;
        this.learnedAt = null;
        this.status = PointStatus.pending;
        this.currentReviewStage = 0;
        this.nextReviewDate = null;
        this.lastReviewAt = null;
        this.reviewCompleted = false;
    }

    /**
     * 完成当前复习，进入下一阶段
     */
    public void completeReview(EbbinghausConfig config) {
        if (!this.isLearned || this.reviewCompleted) {
            return;
        }

        this.lastReviewAt = LocalDateTime.now();

        // 检查是否是最后一个复习阶段
        if (this.currentReviewStage >= config.getTotalStages()) {
            // 所有复习完成
            this.reviewCompleted = true;
            this.status = PointStatus.completed;
            this.nextReviewDate = null;
        } else {
            // 进入下一阶段
            this.currentReviewStage++;
            this.nextReviewDate = LocalDate.now().plusDays(
                    config.getIntervalDays(this.currentReviewStage)
            );
        }
    }

    /**
     * 撤销本次复习（回退到上一个阶段，并标记为今日待复习）
     */
    public void revertReview() {
        if (!this.isLearned) {
            return;
        }

        // 如果已经完成所有复习，先取消完成状态
        if (this.reviewCompleted) {
            this.reviewCompleted = false;
            this.status = PointStatus.in_progress;
        }

        // 回退复习阶段
        if (this.currentReviewStage > 1) {
            this.currentReviewStage--;
        }
        
        // 无论如何，撤销意味着今天还需要复习（或者重新复习）
        // 将下次复习日期重置为今天
        this.nextReviewDate = LocalDate.now();
        
        // 清除最近一次复习时间（可选，或者保留为上次的时间，这里简化处理不回退时间字段）
    }

    /**
     * 检查是否需要复习（今天或之前）
     */
    public boolean needsReview() {
        if (!this.isLearned || this.reviewCompleted || this.nextReviewDate == null) {
            return false;
        }
        return !LocalDate.now().isBefore(this.nextReviewDate);
    }

    /**
     * 检查是否逾期
     */
    public boolean isOverdue() {
        if (!this.isLearned || this.reviewCompleted || this.nextReviewDate == null) {
            return false;
        }
        return LocalDate.now().isAfter(this.nextReviewDate);
    }

    /**
     * 获取逾期天数
     */
    public int getOverdueDays() {
        if (!isOverdue()) {
            return 0;
        }
        return (int) java.time.temporal.ChronoUnit.DAYS.between(this.nextReviewDate, LocalDate.now());
    }

    /**
     * 获取复习进度描述
     */
    public String getReviewProgressDescription() {
        if (!this.isLearned) {
            return "未学习";
        }
        if (this.reviewCompleted) {
            return "已完成所有复习";
        }
        return String.format("第 %d/8 轮复习", this.currentReviewStage);
    }
}
