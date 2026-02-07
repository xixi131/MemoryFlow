package com.memoryflow.config;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.entity.AdminWhitelist;
import com.memoryflow.entity.User;
import com.memoryflow.mapper.AdminWhitelistMapper;
import com.memoryflow.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * 初始化超级管理员账号
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class AdminUserInitializer implements CommandLineRunner {

    private final UserMapper userMapper;
    // private final AdminWhitelistMapper whitelistMapper; // 暂时注释掉，避免表未创建导致的问题
    private static final BCryptPasswordEncoder ENCODER = new BCryptPasswordEncoder();

    @Override
    public void run(String... args) throws Exception {
        // 等待 SchemaMigrationRunner 执行完毕
        // 简单延迟或依赖 Spring 的加载顺序
        // 这里假设 SchemaMigrationRunner 已经运行
        
        try {
            initAdminUser();
        } catch (Exception e) {
            log.error("Failed to init admin user: " + e.getMessage());
        }
    }

    private void initAdminUser() {
        String adminEmail = "admin@gmail.com";
        String adminPassword = "Txt2050905359";

        // 1. 确保在白名单中 (跳过白名单检查，因为表可能还没创建好，且 Admin 不需要白名单逻辑)
        /*
        try {
            AdminWhitelist whitelist = whitelistMapper.selectOne(
                new LambdaQueryWrapper<AdminWhitelist>().eq(AdminWhitelist::getEmail, adminEmail)
            );
             // ...
        } catch (Exception e) {
            log.error("Failed to check whitelist for admin", e);
        }
        */

        // 2. 检查用户是否存在
        User adminUser = null;
        try {
            adminUser = userMapper.selectOne(new LambdaQueryWrapper<User>().eq(User::getEmail, adminEmail));
        } catch (Exception e) {
            log.warn("Failed to query user, table might be updating: " + e.getMessage());
            return;
        }

        if (adminUser == null) {
            log.info("Creating super admin user...");
            adminUser = User.builder()
                    .email(adminEmail)
                    .nickname("SuperAdmin")
                    .role("ADMIN")
                    .status(1)
                    .emailVerified(true)
                    .passwordHash(ENCODER.encode(adminPassword))
                    .build();
            userMapper.insert(adminUser);
            log.info("Super admin user created successfully.");
        } else {
             // ... existing update logic ...
             boolean needUpdate = false;
             if (!"ADMIN".equals(adminUser.getRole())) {
                 adminUser.setRole("ADMIN");
                 needUpdate = true;
             }
             if (needUpdate) {
                 userMapper.updateById(adminUser);
             }
        }
    }
}
