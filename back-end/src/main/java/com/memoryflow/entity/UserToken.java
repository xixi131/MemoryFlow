package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@TableName("user_tokens")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserToken {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("refresh_token")
    private String refreshToken;

    @TableField("device_info")
    private String deviceInfo;

    @TableField("ip_address")
    private String ipAddress;

    @TableField("expires_at")
    private LocalDateTime expiresAt;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    // ========== 充血模型方法 ==========

    /**
     * 检查Token是否过期
     */
    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }

    /**
     * 检查Token是否有效
     */
    public boolean isValid() {
        return !isExpired();
    }
}
