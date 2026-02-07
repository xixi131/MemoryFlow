package com.memoryflow.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

/**
 * 简单的数据库结构迁移工具，用于修复生产环境的Schema差异
 * 注意：生产环境建议使用 Flyway 或 Liquibase
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class SchemaMigrationRunner implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) throws Exception {
        log.info("Starting schema migration check...");
        
        try {
            checkAndFixUserTable();
            checkAndFixWhitelistTable();
        } catch (Exception e) {
            log.error("Schema migration failed", e);
        }
        
        log.info("Schema migration check completed.");
    }

    private void checkAndFixUserTable() {
        // 检查 users 表是否存在 registration_ip 列
        try {
            List<Map<String, Object>> columns = jdbcTemplate.queryForList(
                "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'registration_ip'"
            );

            if (columns.isEmpty()) {
                log.info("Column 'registration_ip' missing in 'users' table. Applying patch...");
                
                String sql = "ALTER TABLE `users` " +
                             "ADD COLUMN `registration_ip` VARCHAR(50) DEFAULT NULL COMMENT '注册IP', " +
                             "ADD COLUMN `last_login_ip` VARCHAR(50) DEFAULT NULL COMMENT '最后登录IP', " +
                             "ADD COLUMN `last_login_time` DATETIME DEFAULT NULL COMMENT '最后登录时间', " +
                             "ADD COLUMN `login_count` INT DEFAULT 0 COMMENT '登录次数'";
                
                jdbcTemplate.execute(sql);
                log.info("Successfully added audit columns to 'users' table.");
            } else {
                log.info("'users' table audit columns are up to date.");
            }

            // Check role column
            List<Map<String, Object>> roleColumn = jdbcTemplate.queryForList(
                "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'role'"
            );
            if (roleColumn.isEmpty()) {
                log.info("Column 'role' missing in 'users' table. Applying patch...");
                String sql = "ALTER TABLE `users` ADD COLUMN `role` VARCHAR(20) DEFAULT 'USER' COMMENT '角色: USER, ADMIN'";
                jdbcTemplate.execute(sql);
                log.info("Successfully added 'role' column to 'users' table.");
            }

            // Check location columns
            List<Map<String, Object>> locationColumns = jdbcTemplate.queryForList(
                "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'registration_location'"
            );
            if (locationColumns.isEmpty()) {
                log.info("Column 'registration_location' missing in 'users' table. Applying patch...");
                String sql = "ALTER TABLE `users` " +
                             "ADD COLUMN `registration_location` VARCHAR(100) DEFAULT NULL COMMENT '注册归属地', " +
                             "ADD COLUMN `last_login_location` VARCHAR(100) DEFAULT NULL COMMENT '最后登录归属地'";
                jdbcTemplate.execute(sql);
                log.info("Successfully added location columns to 'users' table.");
            }

        } catch (Exception e) {
            log.error("Failed to check/update users table", e);
        }
    }

    private void checkAndFixWhitelistTable() {
        // 检查 admin_whitelist 表是否存在
        try {
            List<Map<String, Object>> tables = jdbcTemplate.queryForList(
                "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'admin_whitelist'"
            );

            if (tables.isEmpty()) {
                log.info("Table 'admin_whitelist' missing. Creating table...");
                
                String sql = "CREATE TABLE `admin_whitelist` (" +
                             "`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID', " +
                             "`email` VARCHAR(255) NOT NULL COMMENT '白名单邮箱', " +
                             "`is_registered` TINYINT(1) DEFAULT 0 COMMENT '是否已注册', " +
                             "`created_by` VARCHAR(100) DEFAULT 'System' COMMENT '创建人', " +
                             "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间', " +
                             "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间', " +
                             "PRIMARY KEY (`id`), " +
                             "UNIQUE KEY `uk_whitelist_email` (`email`) " +
                             ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='注册白名单表'";
                
                jdbcTemplate.execute(sql);
                log.info("Successfully created 'admin_whitelist' table.");
            } else {
                log.info("'admin_whitelist' table exists.");
            }
        } catch (Exception e) {
            log.error("Failed to check/create admin_whitelist table", e);
        }
    }
}
