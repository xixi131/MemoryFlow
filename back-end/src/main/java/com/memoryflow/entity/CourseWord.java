package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 课程-单词关联表
 */
@TableName("course_words")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseWord {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("course_id")
    private Long courseId;

    @TableField("word_id")
    private Long wordId;

    @TableField("sort_order")
    private Integer sortOrder;

    @TableField(exist = false)
    private EnglishCourse course;

    @TableField(exist = false)
    private EnglishWord word;
}
