package com.memoryflow.dto.todo;

import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class UpdateTodoTaskRequest {

    @Size(max = 255, message = "任务标题长度不能超过255")
    private String title;

    private String descriptionMd;

    private Long listId;

    /**
     * todo / completed
     */
    private String status;

    /**
     * high / medium / low / none
     */
    private String priority;

    /**
     * YYYY-MM-DD，传空字符串可清空
     */
    private String dueDate;

    /**
     * HH:mm 或 HH:mm:ss，传空字符串可清空
     */
    private String dueTime;

    private Integer sortOrder;

    /**
     * 传 null 表示不变，传空数组表示清空标签
     */
    private List<Long> tagIds;

    /**
     * none / daily / weekly / monthly / yearly，传 none 可取消循环
     */
    private String repeatFreq;

    private Integer repeatInterval;

    /**
     * 传 null 表示不变，传空数组表示清空指定星期
     */
    private List<Integer> repeatByWeekdays;

    /**
     * YYYY-MM-DD，传空字符串可清空
     */
    private String repeatUntil;

    /**
     * 传 0 或负数可清空次数限制
     */
    private Integer repeatCount;
}

