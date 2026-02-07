package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@TableName("goal_themes")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GoalTheme {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("theme_key")
    private String themeKey;

    private String icon;

    @TableField("color_class")
    private String colorClass;

    @TableField("icon_bg_class")
    private String iconBgClass;

    @TableField("progress_gradient")
    private String progressGradient;

    @TableField("sort_order")
    @Builder.Default
    private Integer sortOrder = 0;
}
