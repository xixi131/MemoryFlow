package com.memoryflow.dto;

import com.memoryflow.entity.UserSettings;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserSettingsDTO {

    private Long id;
    private UserSettings.Theme theme;
    private Integer dailyNewWordsGoal;
    private Boolean reminderEnabled;
    private String reminderTime;
    private Boolean emailReminderEnabled;
    private Boolean autoPlayAudio;
    private Boolean soundEffectsEnabled;
    private Boolean widgetAutoStart;
    private Boolean floatingWindowEnabled;
    private String lastSyncAt;

    /**
     * 从实体转换为DTO
     */
    public static UserSettingsDTO fromEntity(UserSettings entity) {
        return UserSettingsDTO.builder()
                .id(entity.getId())
                .theme(entity.getTheme())
                .dailyNewWordsGoal(entity.getDailyNewWordsGoal())
                .reminderEnabled(entity.getReminderEnabled())
                .reminderTime(entity.getReminderTime())
                .emailReminderEnabled(entity.getEmailReminderEnabled())
                .autoPlayAudio(entity.getAutoPlayAudio())
                .soundEffectsEnabled(entity.getSoundEffectsEnabled())
                .widgetAutoStart(entity.getWidgetAutoStart())
                .floatingWindowEnabled(entity.getFloatingWindowEnabled())
                .lastSyncAt(entity.getLastSyncAt() != null ? entity.getLastSyncAt().toString() : null)
                .build();
    }
}
