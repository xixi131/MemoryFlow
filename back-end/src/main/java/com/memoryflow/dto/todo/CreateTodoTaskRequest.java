package com.memoryflow.dto.todo;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class CreateTodoTaskRequest {

    @NotBlank(message = "任务标题不能为空")
    @Size(max = 255, message = "任务标题长度不能超过255")
    private String title;

    private String descriptionMd;

    private Long listId;

    /**
     * high / medium / low / none
     */
    private String priority;

    /**
     * YYYY-MM-DD
     */
    private String dueDate;

    /**
     * HH:mm 或 HH:mm:ss
     */
    private String dueTime;

    private Integer sortOrder;

    private List<Long> tagIds;

    /**
     * none / daily / weekly / monthly / yearly
     */
    private String repeatFreq;

    /**
     * 循环间隔，默认 1
     */
    private Integer repeatInterval;

    /**
     * 每周循环指定星期，ISO 编号（1=周一 ... 7=周日）
     */
    private List<Integer> repeatByWeekdays;

    /**
     * 循环结束日期，YYYY-MM-DD
     */
    private String repeatUntil;

    /**
     * 循环总次数，null 表示不限
     */
    private Integer repeatCount;
}

