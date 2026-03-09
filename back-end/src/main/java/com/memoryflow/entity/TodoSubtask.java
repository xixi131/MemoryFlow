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

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("todo_subtasks")
public class TodoSubtask {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("task_id")
    private Long taskId;

    private String title;

    @Builder.Default
    private SubtaskStatus status = SubtaskStatus.TODO;

    @TableField("sort_order")
    @Builder.Default
    private Integer sortOrder = 0;

    @TableField("completed_at")
    private LocalDateTime completedAt;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    public enum SubtaskStatus {
        TODO("todo"),
        COMPLETED("completed");

        @EnumValue
        private final String value;

        SubtaskStatus(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }
    }
}

