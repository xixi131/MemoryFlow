package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 文章内容实体
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("articles")
public class Article {

    @TableId(type = IdType.AUTO)
    private Long id;

    /**
     * 所属章节ID（若直接属于章节）
     */
    private Long chapterId;

    /**
     * 所属要点ID（若属于二级要点）
     */
    private Long pointId;

    /**
     * 文章标题
     */
    private String title;

    /**
     * 详细内容（Markdown格式）
     */
    private String content;

    /**
     * 排序顺序
     */
    private Integer sortOrder;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
