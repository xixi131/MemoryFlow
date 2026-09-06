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

    /**
     * 循环频率，NONE 表示普通一次性任务
     */
    @TableField("repeat_freq")
    @Builder.Default
    private RepeatFreq repeatFreq = RepeatFreq.NONE;

    /**
     * 循环间隔，例如每 2 周一次则为 2
     */
    @TableField("repeat_interval")
    @Builder.Default
    private Integer repeatInterval = 1;

    /**
     * 每周循环时指定的星期，ISO 编号逗号分隔（1=周一 ... 7=周日），为空表示沿用截止日期所在星期
     */
    @TableField("repeat_by_weekdays")
    private String repeatByWeekdays;

    /**
     * 循环截止日期，超过该日期不再生成下一次
     */
    @TableField("repeat_until")
    private LocalDate repeatUntil;

    /**
     * 循环总次数，null 表示不限次数
     */
    @TableField("repeat_count")
    private Integer repeatCount;

    /**
     * 当前是该循环序列的第几次（从 1 开始）
     */
    @TableField("repeat_index")
    @Builder.Default
    private Integer repeatIndex = 1;

    /**
     * 循环序列 ID，指向该序列首个任务的 id
     */
    @TableField("series_id")
    private Long seriesId;

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

    public enum RepeatFreq {
        NONE("none"),
        DAILY("daily"),
        WEEKLY("weekly"),
        MONTHLY("monthly"),
        YEARLY("yearly");

        @EnumValue
        private final String value;

        RepeatFreq(String value) {
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

