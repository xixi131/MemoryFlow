package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@TableName("review_logs")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReviewLog {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("point_id")
    private Long pointId;

    @TableField("user_id")
    private Long userId;

    @TableField("review_stage")
    private Integer reviewStage;

    @TableField("scheduled_date")
    private LocalDate scheduledDate;

    @TableField("actual_review_at")
    private LocalDateTime actualReviewAt;

    @TableField("is_completed")
    private Boolean isCompleted;

    @TableField("is_overdue")
    private Boolean isOverdue;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}

