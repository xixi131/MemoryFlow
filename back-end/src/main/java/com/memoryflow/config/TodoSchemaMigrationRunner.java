package com.memoryflow.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class TodoSchemaMigrationRunner implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        try {
            createTodoTablesIfNeeded();
            addRecurrenceColumnsIfNeeded();
        } catch (Exception e) {
            log.error("Todo schema migration failed", e);
        }
    }

    /**
     * 循环待办所需的列，历史库需要在线补齐。
     */
    private void addRecurrenceColumnsIfNeeded() {
        if (columnExists("todo_tasks", "repeat_freq")) {
            return;
        }

        log.info("Adding recurrence columns to todo_tasks...");
        jdbcTemplate.execute(
                "ALTER TABLE `todo_tasks` " +
                        "ADD COLUMN `repeat_freq` ENUM('none','daily','weekly','monthly','yearly') " +
                        "NOT NULL DEFAULT 'none' COMMENT '循环频率'," +
                        "ADD COLUMN `repeat_interval` INT NOT NULL DEFAULT 1 COMMENT '循环间隔'," +
                        "ADD COLUMN `repeat_by_weekdays` VARCHAR(32) DEFAULT NULL COMMENT '每周循环的星期(ISO,逗号分隔)'," +
                        "ADD COLUMN `repeat_until` DATE DEFAULT NULL COMMENT '循环结束日期'," +
                        "ADD COLUMN `repeat_count` INT DEFAULT NULL COMMENT '循环总次数'," +
                        "ADD COLUMN `repeat_index` INT NOT NULL DEFAULT 1 COMMENT '当前是第几次'," +
                        "ADD COLUMN `series_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '循环序列ID'," +
                        "ADD KEY `idx_todo_tasks_series` (`user_id`,`series_id`)"
        );
        log.info("Recurrence columns are ready.");
    }

    private boolean columnExists(String table, String column) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() " +
                        "AND TABLE_NAME = ? AND COLUMN_NAME = ?",
                Integer.class, table, column);
        return count != null && count > 0;
    }

    private void createTodoTablesIfNeeded() {
        log.info("Checking todo tables...");

        jdbcTemplate.execute(
                "CREATE TABLE IF NOT EXISTS `todo_lists` (" +
                        "`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '清单ID'," +
                        "`user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID'," +
                        "`name` VARCHAR(100) NOT NULL COMMENT '清单名称'," +
                        "`color` VARCHAR(20) DEFAULT '#3A7FF1' COMMENT '清单颜色'," +
                        "`icon` VARCHAR(50) DEFAULT 'checklist' COMMENT '图标名'," +
                        "`sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序'," +
                        "`is_default` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否默认清单'," +
                        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'," +
                        "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'," +
                        "PRIMARY KEY (`id`)," +
                        "UNIQUE KEY `uk_todo_lists_user_name` (`user_id`,`name`)," +
                        "KEY `idx_todo_lists_user_sort` (`user_id`,`sort_order`)," +
                        "CONSTRAINT `fk_todo_lists_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE RESTRICT" +
                        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='待办清单表'"
        );

        jdbcTemplate.execute(
                "CREATE TABLE IF NOT EXISTS `todo_tasks` (" +
                        "`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '任务ID'," +
                        "`user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID'," +
                        "`list_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '清单ID'," +
                        "`title` VARCHAR(255) NOT NULL COMMENT '任务标题'," +
                        "`description_md` MEDIUMTEXT COMMENT '任务详情(Markdown)'," +
                        "`status` ENUM('todo','completed') NOT NULL DEFAULT 'todo' COMMENT '任务状态'," +
                        "`priority` ENUM('high','medium','low','none') NOT NULL DEFAULT 'none' COMMENT '优先级'," +
                        "`due_date` DATE DEFAULT NULL COMMENT '截止日期'," +
                        "`due_time` TIME DEFAULT NULL COMMENT '截止时间'," +
                        "`completed_at` DATETIME DEFAULT NULL COMMENT '完成时间'," +
                        "`sort_order` INT NOT NULL DEFAULT 0 COMMENT '自定义排序'," +
                        "`repeat_freq` ENUM('none','daily','weekly','monthly','yearly') NOT NULL DEFAULT 'none' COMMENT '循环频率'," +
                        "`repeat_interval` INT NOT NULL DEFAULT 1 COMMENT '循环间隔'," +
                        "`repeat_by_weekdays` VARCHAR(32) DEFAULT NULL COMMENT '每周循环的星期(ISO,逗号分隔)'," +
                        "`repeat_until` DATE DEFAULT NULL COMMENT '循环结束日期'," +
                        "`repeat_count` INT DEFAULT NULL COMMENT '循环总次数'," +
                        "`repeat_index` INT NOT NULL DEFAULT 1 COMMENT '当前是第几次'," +
                        "`series_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '循环序列ID'," +
                        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'," +
                        "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'," +
                        "PRIMARY KEY (`id`)," +
                        "KEY `idx_todo_tasks_user_status` (`user_id`,`status`)," +
                        "KEY `idx_todo_tasks_series` (`user_id`,`series_id`)," +
                        "KEY `idx_todo_tasks_user_due` (`user_id`,`due_date`,`due_time`)," +
                        "KEY `idx_todo_tasks_user_priority` (`user_id`,`priority`)," +
                        "KEY `idx_todo_tasks_user_list_sort` (`user_id`,`list_id`,`sort_order`)," +
                        "KEY `idx_todo_tasks_user_created` (`user_id`,`created_at`)," +
                        "KEY `idx_todo_tasks_user_completed` (`user_id`,`completed_at`)," +
                        "CONSTRAINT `fk_todo_tasks_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE RESTRICT," +
                        "CONSTRAINT `fk_todo_tasks_list` FOREIGN KEY (`list_id`) REFERENCES `todo_lists`(`id`) ON DELETE SET NULL ON UPDATE RESTRICT" +
                        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='待办任务表'"
        );

        jdbcTemplate.execute(
                "CREATE TABLE IF NOT EXISTS `todo_subtasks` (" +
                        "`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '子任务ID'," +
                        "`task_id` BIGINT UNSIGNED NOT NULL COMMENT '主任务ID'," +
                        "`title` VARCHAR(255) NOT NULL COMMENT '子任务标题'," +
                        "`status` ENUM('todo','completed') NOT NULL DEFAULT 'todo' COMMENT '状态'," +
                        "`sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序'," +
                        "`completed_at` DATETIME DEFAULT NULL COMMENT '完成时间'," +
                        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'," +
                        "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'," +
                        "PRIMARY KEY (`id`)," +
                        "KEY `idx_todo_subtasks_task_sort` (`task_id`,`sort_order`)," +
                        "KEY `idx_todo_subtasks_task_status` (`task_id`,`status`)," +
                        "CONSTRAINT `fk_todo_subtasks_task` FOREIGN KEY (`task_id`) REFERENCES `todo_tasks`(`id`) ON DELETE CASCADE ON UPDATE RESTRICT" +
                        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='待办子任务表'"
        );

        jdbcTemplate.execute(
                "CREATE TABLE IF NOT EXISTS `todo_tags` (" +
                        "`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '标签ID'," +
                        "`user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID'," +
                        "`name` VARCHAR(50) NOT NULL COMMENT '标签名'," +
                        "`color` VARCHAR(20) DEFAULT '#94A3B8' COMMENT '标签颜色'," +
                        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'," +
                        "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'," +
                        "PRIMARY KEY (`id`)," +
                        "UNIQUE KEY `uk_todo_tags_user_name` (`user_id`,`name`)," +
                        "KEY `idx_todo_tags_user` (`user_id`)," +
                        "CONSTRAINT `fk_todo_tags_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE RESTRICT" +
                        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='待办标签表'"
        );

        jdbcTemplate.execute(
                "CREATE TABLE IF NOT EXISTS `todo_task_tags` (" +
                        "`id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID'," +
                        "`task_id` BIGINT UNSIGNED NOT NULL COMMENT '任务ID'," +
                        "`tag_id` BIGINT UNSIGNED NOT NULL COMMENT '标签ID'," +
                        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'," +
                        "PRIMARY KEY (`id`)," +
                        "UNIQUE KEY `uk_todo_task_tag` (`task_id`,`tag_id`)," +
                        "KEY `idx_todo_task_tags_tag` (`tag_id`)," +
                        "CONSTRAINT `fk_todo_task_tags_task` FOREIGN KEY (`task_id`) REFERENCES `todo_tasks`(`id`) ON DELETE CASCADE ON UPDATE RESTRICT," +
                        "CONSTRAINT `fk_todo_task_tags_tag` FOREIGN KEY (`tag_id`) REFERENCES `todo_tags`(`id`) ON DELETE CASCADE ON UPDATE RESTRICT" +
                        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任务标签关联表'"
        );

        log.info("Todo tables are ready.");
    }
}

