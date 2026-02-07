package com.memoryflow.controller;

import com.memoryflow.annotation.RequiresCaptcha;
import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.auth.*;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.AuthService;
import com.memoryflow.utils.IpUtils;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final SecurityUtils securityUtils;
    private final IpUtils ipUtils;

    /**
     * 用户注册
     */
    @RequiresCaptcha
    @PostMapping("/register")
    public ApiResponse<AuthResponse> register(
            @Valid @RequestBody RegisterRequest request,
            HttpServletRequest httpRequest) {

        String ipAddress = ipUtils.getClientIp(httpRequest);
        AuthResponse response = authService.register(request, ipAddress);
        return ApiResponse.success(response);
    }

    /**
     * 用户登录
     */
    @RequiresCaptcha
    @PostMapping("/login")
    public ApiResponse<AuthResponse> login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest) {

        String ipAddress = ipUtils.getClientIp(httpRequest);
        AuthResponse response = authService.login(request, ipAddress);
        return ApiResponse.success(response);
    }

    /**
     * 刷新Token
     */
    @PostMapping("/refresh")
    public ApiResponse<AuthResponse> refreshToken(
            @Valid @RequestBody RefreshTokenRequest request,
            HttpServletRequest httpRequest) {

        String ipAddress = ipUtils.getClientIp(httpRequest);
        AuthResponse response = authService.refreshToken(request.getRefreshToken(), ipAddress);
        return ApiResponse.success(response);
    }

    /**
     * 发送验证码
     */
    @RequiresCaptcha
    @PostMapping("/send-code")
    public ApiResponse<Void> sendCode(@Valid @RequestBody SendCodeRequest request) {
        authService.sendVerificationCode(request.getEmail());
        return ApiResponse.success();
    }

    /**
     * 重置密码
     */
    @RequiresCaptcha
    @PostMapping("/reset-password")
    public ApiResponse<Void> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request.getEmail(), request.getCode(), request.getNewPassword());
        return ApiResponse.success();
    }

    /**
     * 更换邮箱
     */
    @RequiresCaptcha
    @PostMapping("/change-email")
    public ApiResponse<Void> changeEmail(@Valid @RequestBody ChangeEmailRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        authService.changeEmail(userId, request.getCode(), request.getNewEmail());
        return ApiResponse.success();
    }

    /**
     * 退出登录
     */
    @PostMapping("/logout")
    public ApiResponse<Void> logout() {
        Long userId = securityUtils.getCurrentUserId();
        if (userId != null) {
            authService.logout(userId);
        }
        return ApiResponse.success();
    }

    /**
     * 更新个人资料
     */
    @PostMapping("/profile")
    public ApiResponse<AuthResponse.UserInfo> updateProfile(@Valid @RequestBody UpdateProfileRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        AuthResponse.UserInfo updatedProfile = authService.updateProfile(userId, request);
        return ApiResponse.success(updatedProfile);
    }

    /**
     * 获取当前用户信息
     */
    @GetMapping("/me")
    public ApiResponse<AuthResponse.UserInfo> getCurrentUser() {
        var user = securityUtils.getCurrentUser();
        if (user == null) {
            return ApiResponse.error(401, "未登录");
        }

        return ApiResponse.success(AuthResponse.UserInfo.builder()
                .id(user.getId())
                .email(user.getEmail())
                .nickname(user.getDisplayName())
                .avatarUrl(user.getAvatarUrl())
                .profession(user.getProfession())
                .age(user.getAge())
                .build());
    }
}
