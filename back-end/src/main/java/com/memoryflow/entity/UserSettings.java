package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@TableName("user_settings")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserSettings {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @Builder.Default
    private Theme theme = Theme.light;

    @TableField("daily_new_words_goal")
    @Builder.Default
    private Integer dailyNewWordsGoal = 20;

    @TableField("reminder_enabled")
    @Builder.Default
    private Boolean reminderEnabled = true;

    @TableField("reminder_time")
    @Builder.Default
    private String reminderTime = "20:00:00";

    @TableField("email_reminder_enabled")
    @Builder.Default
    private Boolean emailReminderEnabled = true;

    @TableField("auto_play_audio")
    @Builder.Default
    private Boolean autoPlayAudio = true;

    @TableField("sound_effects_enabled")
    @Builder.Default
    private Boolean soundEffectsEnabled = true;

    @TableField("widget_auto_start")
    @Builder.Default
    private Boolean widgetAutoStart = false;

    @TableField("floating_window_enabled")
    @Builder.Default
    private Boolean floatingWindowEnabled = true;

    @TableField("last_sync_at")
    private LocalDateTime lastSyncAt;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    // ========== 枚举 ==========

    public enum Theme {
        dark, light, auto
    }

    // ========== 工厂方法 ==========

    /**
     * 创建默认用户设置
     */
    public static UserSettings createDefault(Long userId) {
        return UserSettings.builder()
                .userId(userId)
                .theme(Theme.light)
                .dailyNewWordsGoal(20)
                .reminderEnabled(true)
                .reminderTime("20:00:00")
                .emailReminderEnabled(true)
                .autoPlayAudio(true)
                .soundEffectsEnabled(true)
                .widgetAutoStart(false)
                .floatingWindowEnabled(true)
                .build();
    }
}
