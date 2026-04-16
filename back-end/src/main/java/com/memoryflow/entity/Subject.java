package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
@TableName("subjects")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Subject {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("goal_id")
    private Long goalId;

    @TableField("user_id")
    private Long userId;

    private String title;

    @Builder.Default
    private Integer progress = 0;

    @TableField("total_points")
    @Builder.Default
    private Integer totalPoints = 0;

    @TableField("completed_points")
    @Builder.Default
    private Integer completedPoints = 0;

    @Builder.Default
    private String icon = "book";

    @TableField("color_class")
    @Builder.Default
    private String colorClass = "text-primary";

    @TableField("bg_class")
    @Builder.Default
    private String bgClass = "bg-primary";

    @Builder.Default
    private SubjectStatus status = SubjectStatus.Pending;

    @TableField("sort_order")
    @Builder.Default
    private Integer sortOrder = 0;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @TableField(exist = false)
    @Builder.Default
    private List<Chapter> chapters = new ArrayList<>();

    // ========== 枚举 ==========

    public enum SubjectStatus {
        Pending("Pending"),
        InProgress("In Progress"),
        DueToday("Due Today"),
        Completed("Completed");

        @EnumValue
        private final String value;

        SubjectStatus(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    // ========== 充血模型方法 ==========

    /**
     * 重新计算科目进度
     */
    public void recalculateProgress() {
        if (totalPoints == null || totalPoints == 0) {
            this.progress = 0;
        } else {
            this.progress = (completedPoints * 100) / totalPoints;
        }

        // 更新状态
        updateStatus();
    }

    /**
     * 更新科目状态
     */
    public void updateStatus() {
        if (this.progress >= 100) {
            this.status = SubjectStatus.Completed;
        } else if (this.progress > 0) {
            this.status = SubjectStatus.InProgress;
        } else {
            this.status = SubjectStatus.Pending;
        }
    }

    /**
     * 增加已完成要点数
     */
    public void incrementCompletedPoints() {
        this.completedPoints++;
        recalculateProgress();
    }

    /**
     * 减少已完成要点数
     */
    public void decrementCompletedPoints() {
        if (this.completedPoints > 0) {
            this.completedPoints--;
            recalculateProgress();
        }
    }

    /**
     * 设置总要点数
     */
    public void setTotalPointsCount(int count) {
        this.totalPoints = count;
        recalculateProgress();
    }
}
