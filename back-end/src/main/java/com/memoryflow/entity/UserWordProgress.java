package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 用户单词学习进度
 */
@TableName("user_word_progress")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserWordProgress {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("word_id")
    private Long wordId;

    @TableField("course_id")
    private Long courseId;

    @TableField("status")
    @Builder.Default
    private String status = "new"; // new, learning, mastered

    @TableField(exist = false)
    private LocalDateTime learnedAt;

    @TableField("review_count")
    @Builder.Default
    private Integer reviewCount = 0;

    @TableField("next_review_at")
    private LocalDateTime nextReviewAt;

    @TableField("last_review_at")
    private LocalDateTime lastReviewAt;

    @TableField("correct_count")
    @Builder.Default
    private Integer correctCount = 0;

    @TableField("wrong_count")
    @Builder.Default
    private Integer wrongCount = 0;

    @TableField("familiarity")
    @Builder.Default
    private Integer familiarity = 0;

    @TableField(exist = false)
    private boolean isLearned; // Helper for logic, mapped from status

    public boolean getIsLearned() {
        return !"new".equals(this.status);
    }

    public void setIsLearned(boolean learned) {
        // No-op or update status
    }

    // ... methods need update ...


    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @TableField(exist = false)
    private EnglishWord word;

    /**
     * 标记为已学习
     */
    public void markAsLearned(int firstIntervalDays) {
        if ("new".equals(this.status)) {
            this.status = "learning";
            this.learnedAt = LocalDateTime.now();
            this.reviewCount = 1; // First review (learning)
            // Use LocalDateTime for nextReviewAt
            this.nextReviewAt = LocalDateTime.now().plusDays(firstIntervalDays);
        }
    }

    /**
     * 完成复习 - 答对
     */
    public void completeReviewCorrect(int[] ebbinghausCycles) {
        this.correctCount++;
        this.lastReviewAt = LocalDateTime.now();
        this.familiarity = Math.min(100, this.familiarity + 10);
        this.reviewCount++;

        // Determine next interval based on reviewCount or cycle logic
        // Assuming reviewCount maps to stage index (1-based)
        if (this.reviewCount >= ebbinghausCycles.length) {
            this.status = "mastered";
            this.nextReviewAt = null;
        } else {
            // Safe check for index
            int index = Math.min(this.reviewCount, ebbinghausCycles.length - 1); 
            int nextInterval = ebbinghausCycles[index];
            this.nextReviewAt = LocalDateTime.now().plusDays(nextInterval);
        }
    }

    /**
     * 完成复习 - 答错
     */
    public void completeReviewWrong(int[] ebbinghausCycles) {
        this.wrongCount++;
        this.lastReviewAt = LocalDateTime.now();
        this.familiarity = Math.max(0, this.familiarity - 15);
        
        // Reset or step back
        // Strategy: Step back one stage or reset to 1?
        // Let's step back 1
        if (this.reviewCount > 1) {
            this.reviewCount--;
        }
        
        // Ensure status is learning
        if ("mastered".equals(this.status)) {
             this.status = "learning";
        }

        int index = Math.max(0, this.reviewCount - 1);
        int nextInterval = ebbinghausCycles[index];
        this.nextReviewAt = LocalDateTime.now().plusDays(nextInterval);
    }

    /**
     * 判断是否需要复习
     */
    public boolean needsReview() {
        if ("new".equals(this.status) || "mastered".equals(this.status)) {
            return false;
        }
        return this.nextReviewAt != null && !this.nextReviewAt.isAfter(LocalDateTime.now());
    }
}
