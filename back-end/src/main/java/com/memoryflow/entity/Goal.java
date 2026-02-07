package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
@TableName("goals")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Goal {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    private String title;

    private String subtitle;

    @TableField("label_type")
    @Builder.Default
    private LabelType labelType = LabelType.priority;

    @Builder.Default
    private Integer progress = 0;

    @Builder.Default
    private String icon = "target";

    @TableField("color_class")
    @Builder.Default
    private String colorClass = "text-primary";

    @TableField("icon_bg_class")
    private String iconBgClass;

    @TableField("progress_gradient")
    private String progressGradient;

    @Builder.Default
    private GoalStatus status = GoalStatus.active;

    @TableField("due_date")
    private LocalDate dueDate;

    @TableField("sort_order")
    @Builder.Default
    private Integer sortOrder = 0;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    // MyBatis-Plus 不支持直接的一对多关联查询，需要手动处理
    // 标记为 exist = false，表明不是数据库字段
    @TableField(exist = false)
    @Builder.Default
    private List<Subject> subjects = new ArrayList<>();

    // ========== 枚举 ==========

    public enum LabelType {
        priority, daily, longterm
    }

    public enum GoalStatus {
        active, completed, archived
    }

    // ========== 充血模型方法 ==========

    /**
     * 重新计算目标进度（基于所有科目的加权平均）
     */
    public void recalculateProgress(List<Subject> subjects) {
        if (subjects == null || subjects.isEmpty()) {
            this.progress = 0;
            return;
        }

        int totalProgress = subjects.stream()
                .mapToInt(Subject::getProgress)
                .sum();

        this.progress = totalProgress / subjects.size();

        // 如果进度达到100%，自动标记为完成
        if (this.progress >= 100) {
            this.status = GoalStatus.completed;
        }
    }

    /**
     * 标记目标为完成
     */
    public void complete() {
        this.status = GoalStatus.completed;
        this.progress = 100;
    }

    /**
     * 归档目标
     */
    public void archive() {
        this.status = GoalStatus.archived;
    }

    /**
     * 检查目标是否活跃
     */
    public boolean isActive() {
        return this.status == GoalStatus.active;
    }

    /**
     * 应用主题样式
     */
    public void applyTheme(GoalTheme theme) {
        this.icon = theme.getIcon();
        this.colorClass = theme.getColorClass();
        this.iconBgClass = theme.getIconBgClass();
        this.progressGradient = theme.getProgressGradient();
    }
}
