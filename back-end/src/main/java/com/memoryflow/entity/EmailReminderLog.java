package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@TableName("email_reminder_logs")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmailReminderLog {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("reminder_type")
    private String reminderType; // overdue_1day, overdue_7days, overdue_30days

    private String email;

    private String subject;

    @TableField("content")
    private String content;

    @Builder.Default
    private String status = "pending"; // pending, sent, failed

    @TableField("error_message")
    private String errorMessage;

    @TableField("sent_at")
    private LocalDateTime sentAt;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    public void markAsSent() {
        this.status = "sent";
        this.sentAt = LocalDateTime.now();
    }

    public void markAsFailed(String errorMessage) {
        this.status = "failed";
        this.errorMessage = errorMessage;
    }
}
