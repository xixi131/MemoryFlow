package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.time.LocalDateTime;

@Data
@TableName("users")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    // 忽略这个字段，不参与数据库映射
    @TableField(exist = false)
    private static final BCryptPasswordEncoder PASSWORD_ENCODER = new BCryptPasswordEncoder();

    @TableId(type = IdType.AUTO)
    private Long id;

    private String email;

    @TableField("password_hash")
    private String passwordHash;

    private String nickname;

    @TableField("avatar_url")
    private String avatarUrl;

    @TableField("major")
    private String profession;

    @TableField("grade")
    private String age;

    @TableField("email_verified")
    @Builder.Default
    private Boolean emailVerified = false;

    @Builder.Default
    private Integer status = 1; // 0-禁用, 1-正常

    @TableField("registration_ip")
    private String registrationIp;

    @TableField("registration_location")
    private String registrationLocation;

    @TableField("last_login_ip")
    private String lastLoginIp;

    @TableField("last_login_location")
    private String lastLoginLocation;

    @TableField("last_login_time")
    private LocalDateTime lastLoginTime;

    @TableField("login_count")
    @Builder.Default
    private Integer loginCount = 0;

    @TableField("role")
    @Builder.Default
    private String role = "USER"; // USER, ADMIN

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    // ========== 充血模型方法 ==========

    /**
     * 设置密码（自动加密）
     */
    public void setPassword(String rawPassword) {
        this.passwordHash = PASSWORD_ENCODER.encode(rawPassword);
    }

    /**
     * 验证密码
     */
    public boolean verifyPassword(String rawPassword) {
        return PASSWORD_ENCODER.matches(rawPassword, this.passwordHash);
    }

    /**
     * 检查用户是否可用
     */
    public boolean isActive() {
        return this.status != null && this.status == 1;
    }

    /**
     * 禁用用户
     */
    public void disable() {
        this.status = 0;
    }

    /**
     * 启用用户
     */
    public void enable() {
        this.status = 1;
    }

    /**
     * 获取显示名称
     */
    public String getDisplayName() {
        if (nickname != null && !nickname.isBlank()) {
            return nickname;
        }
        // 使用邮箱前缀作为默认昵称
        if (email != null) {
            int atIndex = email.indexOf('@');
            return atIndex > 0 ? email.substring(0, atIndex) : email;
        }
        return "User";
    }
}
