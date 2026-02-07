package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.UserSettingsDTO;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.UserSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/settings")
@RequiredArgsConstructor
public class UserSettingsController {

    private final UserSettingsService userSettingsService;
    private final SecurityUtils securityUtils;

    /**
     * 获取当前用户设置
     */
    @GetMapping
    public ApiResponse<UserSettingsDTO> getSettings() {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(userSettingsService.getSettings(userId));
    }

    /**
     * 更新用户设置
     */
    @PostMapping
    public ApiResponse<UserSettingsDTO> updateSettings(@RequestBody UserSettingsDTO settingsDTO) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(userSettingsService.updateSettings(userId, settingsDTO));
    }
}
