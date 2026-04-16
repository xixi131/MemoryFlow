package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 用户课程/词书选择
 */
@TableName("user_courses")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserCourse {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("course_id")
    private Long courseId;

    @TableField("is_active")
    @Builder.Default
    private Boolean isActive = true;

    @TableField("daily_goal")
    @Builder.Default
    private Integer dailyGoal = 20; // 每日学习目标单词数

    @TableField("learned_count")
    @Builder.Default
    private Integer learnedCount = 0;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @TableField(exist = false)
    private EnglishCourse course;
}
