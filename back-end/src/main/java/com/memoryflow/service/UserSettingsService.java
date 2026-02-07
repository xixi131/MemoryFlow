package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.dto.UserSettingsDTO;
import com.memoryflow.entity.UserSettings;
import com.memoryflow.mapper.UserSettingsMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class UserSettingsService {

    private final UserSettingsMapper userSettingsMapper;

    /**
     * 更新同步时间
     */
    @Transactional
    public void updateSyncTime(Long userId) {
        UserSettings settings = userSettingsMapper.selectOne(
                new LambdaQueryWrapper<UserSettings>().eq(UserSettings::getUserId, userId)
        );

        if (settings == null) {
            settings = UserSettings.createDefault(userId);
            settings.setLastSyncAt(LocalDateTime.now());
            userSettingsMapper.insert(settings);
        } else {
            settings.setLastSyncAt(LocalDateTime.now());
            userSettingsMapper.updateById(settings);
        }
    }

    /**
     * 获取用户设置，如果不存在则创建默认设置
     */
    public UserSettingsDTO getSettings(Long userId) {
        UserSettings settings = userSettingsMapper.selectOne(
                new LambdaQueryWrapper<UserSettings>().eq(UserSettings::getUserId, userId)
        );

        if (settings == null) {
            settings = UserSettings.createDefault(userId);
            userSettingsMapper.insert(settings);
        }

        return UserSettingsDTO.fromEntity(settings);
    }

    /**
     * 更新用户设置
     */
    @Transactional
    public UserSettingsDTO updateSettings(Long userId, UserSettingsDTO dto) {
        UserSettings settings = userSettingsMapper.selectOne(
                new LambdaQueryWrapper<UserSettings>().eq(UserSettings::getUserId, userId)
        );

        if (settings == null) {
            settings = UserSettings.createDefault(userId);
        }

        // Update fields
        if (dto.getTheme() != null) settings.setTheme(dto.getTheme());
        if (dto.getDailyNewWordsGoal() != null) settings.setDailyNewWordsGoal(dto.getDailyNewWordsGoal());
        if (dto.getReminderEnabled() != null) settings.setReminderEnabled(dto.getReminderEnabled());
        if (dto.getReminderTime() != null) settings.setReminderTime(dto.getReminderTime());
        if (dto.getEmailReminderEnabled() != null) settings.setEmailReminderEnabled(dto.getEmailReminderEnabled());
        if (dto.getAutoPlayAudio() != null) settings.setAutoPlayAudio(dto.getAutoPlayAudio());
        if (dto.getSoundEffectsEnabled() != null) settings.setSoundEffectsEnabled(dto.getSoundEffectsEnabled());
        if (dto.getWidgetAutoStart() != null) settings.setWidgetAutoStart(dto.getWidgetAutoStart());
        if (dto.getFloatingWindowEnabled() != null) settings.setFloatingWindowEnabled(dto.getFloatingWindowEnabled());

        settings.setLastSyncAt(LocalDateTime.now());

        if (settings.getId() == null) {
            userSettingsMapper.insert(settings);
        } else {
            userSettingsMapper.updateById(settings);
        }

        return UserSettingsDTO.fromEntity(settings);
    }
}
