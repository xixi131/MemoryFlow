package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 注册白名单实体
 */
@Data
@TableName("admin_whitelist")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AdminWhitelist {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("email")
    private String email;

    @TableField("created_by")
    private String createdBy;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField("is_registered")
    @Builder.Default
    private Boolean isRegistered = false;
}
