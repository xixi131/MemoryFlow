package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.memoryflow.dto.ApiResponse;
import com.memoryflow.entity.AdminWhitelist;
import com.memoryflow.entity.User;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.mapper.AdminWhitelistMapper;
import com.memoryflow.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import com.memoryflow.dto.admin.AdminStats;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminService {

    private final UserMapper userMapper;
    private final AdminWhitelistMapper adminWhitelistMapper;
    private final EmailReminderService emailReminderService;

    /**
     * 获取管理后台统计数据
     */
    public AdminStats getStats() {
        // 1. 总注册用户
        long totalUsers = userMapper.selectCount(null);

        // 2. 本月新增用户
        LocalDateTime startOfMonth = LocalDate.now().withDayOfMonth(1).atStartOfDay();
        long newUsersThisMonth = userMapper.selectCount(new LambdaQueryWrapper<User>()
                .ge(User::getCreatedAt, startOfMonth));

        // 3. 白名单使用率
        long whitelistTotalCount = adminWhitelistMapper.selectCount(null);
        long whitelistActivatedCount = adminWhitelistMapper.selectCount(new LambdaQueryWrapper<AdminWhitelist>()
                .eq(AdminWhitelist::getIsRegistered, true));
        
        double whitelistUsageRate = 0.0;
        if (whitelistTotalCount > 0) {
            whitelistUsageRate = (double) whitelistActivatedCount / whitelistTotalCount * 100;
            // 保留一位小数
            whitelistUsageRate = Math.round(whitelistUsageRate * 10.0) / 10.0;
        }

        // 4. 今日活跃用户 (最后登录时间 >= 今天0点)
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        long activeUsersToday = userMapper.selectCount(new LambdaQueryWrapper<User>()
                .ge(User::getLastLoginTime, startOfDay));

        return AdminStats.builder()
                .totalUsers(totalUsers)
                .newUsersThisMonth(newUsersThisMonth)
                .whitelistUsageRate(whitelistUsageRate)
                .whitelistActivatedCount(whitelistActivatedCount)
                .whitelistTotalCount(whitelistTotalCount)
                .activeUsersToday(activeUsersToday)
                .build();
    }

    /**
     * 获取用户列表 (分页 + 搜索)
     */
    public IPage<User> getUserList(int page, int size, String emailKeyword, Boolean onlyBanned) {
        Page<User> userPage = new Page<>(page, size);
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();

        if (StringUtils.hasText(emailKeyword)) {
            wrapper.and(w -> w.like(User::getEmail, emailKeyword)
                            .or()
                            .like(User::getNickname, emailKeyword));
        }

        if (Boolean.TRUE.equals(onlyBanned)) {
            wrapper.eq(User::getStatus, 0);
        }

        // 按注册时间倒序
        wrapper.orderByDesc(User::getCreatedAt);

        return userMapper.selectPage(userPage, wrapper);
    }

    /**
     * 封禁用户
     */
    public void banUser(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND);
        }
        user.disable();
        userMapper.updateById(user);
    }

    /**
     * 解封用户
     */
    public void unbanUser(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND);
        }
        user.enable();
        userMapper.updateById(user);
    }

    /**
     * 获取白名单列表
     */
    public IPage<AdminWhitelist> getWhitelist(int page, int size) {
        Page<AdminWhitelist> whitelistPage = new Page<>(page, size);
        return adminWhitelistMapper.selectPage(whitelistPage, 
                new LambdaQueryWrapper<AdminWhitelist>().orderByDesc(AdminWhitelist::getCreatedAt));
    }

    /**
     * 批量添加白名单
     */
    @Transactional
    public void addWhitelist(List<String> emails, String adminName) {
        for (String email : emails) {
            if (!StringUtils.hasText(email)) continue;
            
            // 检查是否已存在
            Long count = adminWhitelistMapper.selectCount(
                    new LambdaQueryWrapper<AdminWhitelist>().eq(AdminWhitelist::getEmail, email));
            
            if (count == 0) {
                AdminWhitelist whitelist = AdminWhitelist.builder()
                        .email(email)
                        .createdBy(adminName)
                        .isRegistered(false)
                        .build();
                adminWhitelistMapper.insert(whitelist);
                
                // 发送邀请邮件
                emailReminderService.sendInvitationEmail(email);
            }
        }
    }

    /**
     * 移除白名单
     */
    public void removeWhitelist(Long id) {
        adminWhitelistMapper.deleteById(id);
    }
}
