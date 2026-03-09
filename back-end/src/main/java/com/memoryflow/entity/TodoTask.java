package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.EnumValue;
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
import java.time.LocalTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("todo_tasks")
public class TodoTask {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("list_id")
    private Long listId;

    private String title;

    @TableField("description_md")
    private String descriptionMd;

    @Builder.Default
    private TaskStatus status = TaskStatus.TODO;

    @Builder.Default
    private Priority priority = Priority.NONE;

    @TableField("due_date")
    private LocalDate dueDate;

    @TableField("due_time")
    private LocalTime dueTime;

    @TableField("completed_at")
    private LocalDateTime completedAt;

    @TableField("sort_order")
    @Builder.Default
    private Integer sortOrder = 0;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    public enum TaskStatus {
        TODO("todo"),
        COMPLETED("completed");

        @EnumValue
        private final String value;

        TaskStatus(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }

    public enum Priority {
        HIGH("high"),
        MEDIUM("medium"),
        LOW("low"),
        NONE("none");

        @EnumValue
        private final String value;

        Priority(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }
}

