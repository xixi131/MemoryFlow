package com.memoryflow.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.memoryflow.dto.ApiResponse;
import com.memoryflow.entity.AdminWhitelist;
import com.memoryflow.entity.User;
import com.memoryflow.service.AdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

import com.memoryflow.dto.admin.AdminStats;

/**
 * 超级管理员后台控制器
 */
@RestController
@RequestMapping("/admin")
@RequiredArgsConstructor
public class AdminUserController {

    private final AdminService adminService;

    /**
     * 获取统计数据
     */
    @GetMapping("/stats")
    public ApiResponse<AdminStats> getStats(@AuthenticationPrincipal User user) {
        checkAdminAuth(user);
        return ApiResponse.success(adminService.getStats());
    }

    /**
     * 检查管理员权限
     */
    private void checkAdminAuth(User user) {
        if (user == null || !"ADMIN".equals(user.getRole())) {
            throw new RuntimeException("无权访问：需要管理员权限");
        }
    }

    /**
     * 获取用户列表
     */
    @GetMapping("/users")
    public ApiResponse<IPage<User>> getUserList(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(required = false) String email,
            @RequestParam(required = false) Boolean onlyBanned) {
        
        checkAdminAuth(user);
        return ApiResponse.success(adminService.getUserList(page, size, email, onlyBanned));
    }

    /**
     * 封禁用户
     */
    @PostMapping("/user/ban/{userId}")
    public ApiResponse<Void> banUser(
            @AuthenticationPrincipal User user,
            @PathVariable Long userId) {
        checkAdminAuth(user);
        adminService.banUser(userId);
        return ApiResponse.success();
    }

    /**
     * 解封用户
     */
    @PostMapping("/user/unban/{userId}")
    public ApiResponse<Void> unbanUser(
            @AuthenticationPrincipal User user,
            @PathVariable Long userId) {
        checkAdminAuth(user);
        adminService.unbanUser(userId);
        return ApiResponse.success();
    }

    /**
     * 获取白名单列表
     */
    @GetMapping("/whitelist")
    public ApiResponse<IPage<AdminWhitelist>> getWhitelist(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        checkAdminAuth(user);
        return ApiResponse.success(adminService.getWhitelist(page, size));
    }

    /**
     * 批量添加白名单
     */
    @PostMapping("/whitelist")
    public ApiResponse<Void> addWhitelist(
            @AuthenticationPrincipal User user,
            @RequestBody List<String> emails) {
        checkAdminAuth(user);
        adminService.addWhitelist(emails, user.getDisplayName());
        return ApiResponse.success();
    }

    /**
     * 移除白名单
     */
    @DeleteMapping("/whitelist/{id}")
    public ApiResponse<Void> removeWhitelist(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        checkAdminAuth(user);
        adminService.removeWhitelist(id);
        return ApiResponse.success();
    }
}
