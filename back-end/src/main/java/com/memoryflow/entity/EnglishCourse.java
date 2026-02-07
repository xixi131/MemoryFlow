package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 英语课程/词书
 */
@TableName("english_courses")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EnglishCourse {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String name;

    private String code;

    @TableField("description")
    private String description;

    @TableField("cover_image")
    private String coverImage;

    @TableField("word_count")
    @Builder.Default
    private Integer wordCount = 0;

    private String category; // cet4, cet6, kaoyan, toefl, gre, etc.

    private Integer difficulty; // 难度等级 1-5

    private String icon;

    @TableField("color_theme")
    private String colorTheme;

    @TableField("is_active")
    @Builder.Default
    private Boolean isActive = true;

    @TableField("sort_order")
    private Integer sortOrder;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
