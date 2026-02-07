-- ============================================================
-- MemoryFlow 数据库初始化脚本
-- 基于艾宾浩斯遗忘曲线的学习计划管理系统
-- Database: MySQL 8.0+
-- Charset: utf8mb4
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 按依赖顺序删除表
-- ============================================================
DROP TABLE IF EXISTS `email_reminder_logs`;
DROP TABLE IF EXISTS `review_logs`;
DROP TABLE IF EXISTS `calendar_records`;
DROP TABLE IF EXISTS `user_word_progress`;
DROP TABLE IF EXISTS `user_courses`;
DROP TABLE IF EXISTS `course_words`;
DROP TABLE IF EXISTS `user_settings`;
DROP TABLE IF EXISTS `tasks`;
DROP TABLE IF EXISTS `articles`;
DROP TABLE IF EXISTS `points`;
DROP TABLE IF EXISTS `chapters`;
DROP TABLE IF EXISTS `subjects`;
DROP TABLE IF EXISTS `goals`;
DROP TABLE IF EXISTS `english_words`;
DROP TABLE IF EXISTS `english_courses`;
DROP TABLE IF EXISTS `goal_themes`;
DROP TABLE IF EXISTS `ebbinghaus_cycles`;
DROP TABLE IF EXISTS `user_tokens`;
DROP TABLE IF EXISTS `users`;

DROP VIEW IF EXISTS `v_pending_reviews`;
DROP VIEW IF EXISTS `v_user_stats`;
DROP VIEW IF EXISTS `v_widget_summary`;

-- ============================================================
-- 1. 用户表 (users)
-- ============================================================
CREATE TABLE `users` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    `email` VARCHAR(255) NOT NULL COMMENT '邮箱（用于登录）',
    `password_hash` VARCHAR(255) NOT NULL COMMENT '密码哈希值',
    `nickname` VARCHAR(100) DEFAULT NULL COMMENT '昵称',
    `avatar_url` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
    `major` VARCHAR(100) DEFAULT NULL COMMENT '专业',
    `grade` VARCHAR(50) DEFAULT NULL COMMENT '年级/职级',
    `email_verified` TINYINT(1) DEFAULT 0 COMMENT '邮箱是否已验证',
    `status` TINYINT DEFAULT 1 COMMENT '状态: 0-禁用, 1-正常',
    `registration_ip` VARCHAR(50) DEFAULT NULL COMMENT '注册IP',
    `last_login_ip` VARCHAR(50) DEFAULT NULL COMMENT '最后登录IP',
    `last_login_time` DATETIME DEFAULT NULL COMMENT '最后登录时间',
    `login_count` INT DEFAULT 0 COMMENT '登录次数',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_email` (`email`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- ============================================================
-- 1.1 注册白名单表 (admin_whitelist)
-- ============================================================
CREATE TABLE `admin_whitelist` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `email` VARCHAR(255) NOT NULL COMMENT '白名单邮箱',
    `is_registered` TINYINT(1) DEFAULT 0 COMMENT '是否已注册',
    `created_by` VARCHAR(100) DEFAULT 'System' COMMENT '创建人',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_whitelist_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='注册白名单表';

-- ============================================================
-- 2. 用户Token表 (user_tokens) - 用于刷新Token管理
-- ============================================================
CREATE TABLE `user_tokens` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `refresh_token` VARCHAR(500) NOT NULL COMMENT '刷新Token',
    `device_info` VARCHAR(255) DEFAULT NULL COMMENT '设备信息',
    `ip_address` VARCHAR(50) DEFAULT NULL COMMENT 'IP地址',
    `expires_at` DATETIME NOT NULL COMMENT '过期时间',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_refresh_token` (`refresh_token`(191)),
    KEY `idx_expires_at` (`expires_at`),
    CONSTRAINT `fk_user_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户Token表';

-- ============================================================
-- 3. 学习目标表 (goals)
-- ============================================================
CREATE TABLE `goals` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '目标ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `title` VARCHAR(255) NOT NULL COMMENT '目标标题',
    `subtitle` VARCHAR(500) DEFAULT NULL COMMENT '副标题/下一步任务',
    `label_type` ENUM('priority', 'daily', 'longterm') DEFAULT 'priority' COMMENT '标签类型: priority-高优先, daily-每日打卡, longterm-长期计划',
    `progress` TINYINT UNSIGNED DEFAULT 0 COMMENT '进度百分比 (0-100)',
    `icon` VARCHAR(50) DEFAULT 'target' COMMENT 'Material Icons图标名',
    `color_class` VARCHAR(100) DEFAULT 'text-primary' COMMENT '颜色CSS类名',
    `icon_bg_class` VARCHAR(200) DEFAULT NULL COMMENT '图标背景CSS类名',
    `progress_gradient` VARCHAR(300) DEFAULT NULL COMMENT '进度条渐变色',
    `status` ENUM('active', 'completed', 'archived') DEFAULT 'active' COMMENT '状态: active-进行中, completed-已完成, archived-已归档',
    `due_date` DATE DEFAULT NULL COMMENT '截止日期',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_user_status` (`user_id`, `status`),
    KEY `idx_due_date` (`due_date`),
    CONSTRAINT `fk_goals_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='学习目标表';

-- ============================================================
-- 4. 科目表 (subjects)
-- ============================================================
CREATE TABLE `subjects` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '科目ID',
    `goal_id` BIGINT UNSIGNED NOT NULL COMMENT '所属目标ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID（冗余字段，便于查询）',
    `title` VARCHAR(255) NOT NULL COMMENT '科目名称',
    `progress` TINYINT UNSIGNED DEFAULT 0 COMMENT '进度百分比 (0-100)',
    `total_points` INT UNSIGNED DEFAULT 0 COMMENT '总要点数',
    `completed_points` INT UNSIGNED DEFAULT 0 COMMENT '已完成要点数',
    `icon` VARCHAR(50) DEFAULT 'book' COMMENT 'Material Icons图标名',
    `color_class` VARCHAR(100) DEFAULT 'text-primary' COMMENT '文字颜色类',
    `bg_class` VARCHAR(100) DEFAULT 'bg-primary' COMMENT '背景颜色类',
    `status` ENUM('Pending', 'In Progress', 'Due Today', 'Completed') DEFAULT 'Pending' COMMENT '状态',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_goal_id` (`goal_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_user_status` (`user_id`, `status`),
    CONSTRAINT `fk_subjects_goal` FOREIGN KEY (`goal_id`) REFERENCES `goals` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_subjects_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='科目表';

-- ============================================================
-- 5. 章节表 (chapters) - 通过 @ 语法定义的一级章节
-- ============================================================
CREATE TABLE `chapters` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '章节ID',
    `subject_id` BIGINT UNSIGNED NOT NULL COMMENT '所属科目ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID（冗余字段）',
    `title` VARCHAR(255) NOT NULL COMMENT '章节标题',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_subject_id` (`subject_id`),
    KEY `idx_user_id` (`user_id`),
    CONSTRAINT `fk_chapters_subject` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_chapters_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='章节表（一级）';

-- ============================================================
-- 6. 知识点/要点表 (points) - 通过 @@ 语法定义的二级要点
-- ============================================================
CREATE TABLE `points` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '要点ID',
    `chapter_id` BIGINT UNSIGNED NOT NULL COMMENT '所属章节ID',
    `subject_id` BIGINT UNSIGNED NOT NULL COMMENT '所属科目ID（冗余字段）',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID（冗余字段）',
    `title` VARCHAR(255) NOT NULL COMMENT '要点标题',
    `status` ENUM('pending', 'in-progress', 'completed') DEFAULT 'pending' COMMENT '学习状态',
    `is_learned` TINYINT(1) DEFAULT 0 COMMENT '是否已学习（首次勾选）',
    `learned_at` DATETIME DEFAULT NULL COMMENT '首次学习时间（触发复习计划的时间）',
    `current_review_stage` TINYINT DEFAULT 0 COMMENT '当前复习阶段 (0=未开始, 1-8对应8个复习周期)',
    `next_review_date` DATE DEFAULT NULL COMMENT '下次复习日期',
    `last_review_at` DATETIME DEFAULT NULL COMMENT '最近一次复习时间',
    `review_completed` TINYINT(1) DEFAULT 0 COMMENT '是否完成所有复习周期',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_chapter_id` (`chapter_id`),
    KEY `idx_subject_id` (`subject_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_user_status` (`user_id`, `status`),
    KEY `idx_next_review_date` (`next_review_date`) COMMENT '复习日期索引，用于查询待复习内容',
    KEY `idx_user_next_review` (`user_id`, `next_review_date`) COMMENT '用户待复习内容索引',
    KEY `idx_review_stage` (`current_review_stage`),
    CONSTRAINT `fk_points_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapters` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_points_subject` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_points_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='知识点/要点表';

-- ============================================================
-- 7. 文章内容表 (articles) - 存储Markdown文章，可关联章节或知识点
-- ============================================================
CREATE TABLE `articles` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '文章ID',
    `chapter_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '所属章节ID（若直接属于章节）',
    `point_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '所属要点ID（若属于二级要点）',
    `title` VARCHAR(255) NOT NULL COMMENT '文章标题',
    `content` MEDIUMTEXT DEFAULT NULL COMMENT '详细内容（Markdown格式）',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_chapter_id` (`chapter_id`),
    KEY `idx_point_id` (`point_id`),
    CONSTRAINT `fk_articles_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapters` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_articles_point` FOREIGN KEY (`point_id`) REFERENCES `points` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文章内容表';

-- ============================================================
-- 8. 复习记录表 (review_logs) - 记录每次复习的详细信息
-- ============================================================
CREATE TABLE `review_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '记录ID',
    `point_id` BIGINT UNSIGNED NOT NULL COMMENT '要点ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `review_stage` TINYINT NOT NULL COMMENT '复习阶段 (1-8)',
    `scheduled_date` DATE NOT NULL COMMENT '计划复习日期',
    `actual_review_at` DATETIME DEFAULT NULL COMMENT '实际复习时间',
    `is_completed` TINYINT(1) DEFAULT 0 COMMENT '是否已完成',
    `is_overdue` TINYINT(1) DEFAULT 0 COMMENT '是否逾期',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    KEY `idx_point_id` (`point_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_user_scheduled` (`user_id`, `scheduled_date`),
    KEY `idx_user_completed` (`user_id`, `is_completed`),
    CONSTRAINT `fk_review_logs_point` FOREIGN KEY (`point_id`) REFERENCES `points` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_review_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='复习记录表';

-- ============================================================
-- 9. 每日任务表 (tasks)
-- ============================================================
CREATE TABLE `tasks` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '任务ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `title` VARCHAR(255) NOT NULL COMMENT '任务标题',
    `scheduled_time` VARCHAR(100) DEFAULT NULL COMMENT '计划时间描述（如 20:00 - 21:00）',
    `completed` TINYINT(1) DEFAULT 0 COMMENT '是否完成',
    `completed_at` DATETIME DEFAULT NULL COMMENT '完成时间',
    `tag` VARCHAR(50) DEFAULT NULL COMMENT '标签类型',
    `tag_color` VARCHAR(50) DEFAULT NULL COMMENT '标签颜色',
    `task_date` DATE NOT NULL COMMENT '任务日期',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_user_date` (`user_id`, `task_date`),
    KEY `idx_task_date` (`task_date`),
    CONSTRAINT `fk_tasks_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='每日任务表';

-- ============================================================
-- 10. 用户设置表 (user_settings)
-- ============================================================
CREATE TABLE `user_settings` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `theme` ENUM('dark', 'light', 'auto') DEFAULT 'dark' COMMENT '主题模式',
    `daily_new_words_goal` INT DEFAULT 20 COMMENT '每日新词目标',
    `reminder_enabled` TINYINT(1) DEFAULT 1 COMMENT '是否启用提醒',
    `reminder_time` TIME DEFAULT '20:00:00' COMMENT '提醒时间',
    `email_reminder_enabled` TINYINT(1) DEFAULT 1 COMMENT '是否启用邮件提醒',
    `auto_play_audio` TINYINT(1) DEFAULT 1 COMMENT '自动播放音频',
    `sound_effects_enabled` TINYINT(1) DEFAULT 1 COMMENT '启用音效',
    `widget_auto_start` TINYINT(1) DEFAULT 0 COMMENT '桌面小组件是否开机自启',
    `floating_window_enabled` TINYINT(1) DEFAULT 1 COMMENT '是否启用悬浮窗',
    `last_sync_at` DATETIME DEFAULT NULL COMMENT '最后同步时间',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id` (`user_id`),
    CONSTRAINT `fk_user_settings_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户设置表';

-- ============================================================
-- 11. 邮件提醒记录表 (email_reminder_logs)
-- ============================================================
CREATE TABLE `email_reminder_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '记录ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `reminder_type` ENUM('daily', 'week', 'month') NOT NULL COMMENT '提醒类型: daily-超过1天, week-超过7天, month-超过1个月',
    `overdue_days` INT NOT NULL COMMENT '逾期天数',
    `pending_reviews` INT NOT NULL COMMENT '待复习要点数量',
    `email_subject` VARCHAR(255) NOT NULL COMMENT '邮件主题',
    `email_content` TEXT NOT NULL COMMENT '邮件内容',
    `sent_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发送时间',
    `is_sent` TINYINT(1) DEFAULT 1 COMMENT '是否发送成功',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_user_type` (`user_id`, `reminder_type`),
    KEY `idx_sent_at` (`sent_at`),
    CONSTRAINT `fk_email_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='邮件提醒记录表';

-- ============================================================
-- 12. 英语词库表 (english_words) - ECDICT格式
-- ============================================================
CREATE TABLE `english_words` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '单词ID',
    `word` VARCHAR(100) NOT NULL COMMENT '单词',
    `phonetic` VARCHAR(200) DEFAULT NULL COMMENT '音标',
    `definition` TEXT DEFAULT NULL COMMENT '中文释义',
    `translation` TEXT DEFAULT NULL COMMENT '英文翻译',
    `pos` VARCHAR(50) DEFAULT NULL COMMENT '词性',
    `collins` TINYINT DEFAULT NULL COMMENT '柯林斯星级 (1-5)',
    `oxford` TINYINT DEFAULT NULL COMMENT '是否牛津核心词汇',
    `tag` VARCHAR(100) DEFAULT NULL COMMENT '标签（如 cet4, cet6, ielts, toefl, gre）',
    `bnc` INT DEFAULT NULL COMMENT 'BNC词频顺序',
    `frq` INT DEFAULT NULL COMMENT '当代语料库词频顺序',
    `exchange` VARCHAR(500) DEFAULT NULL COMMENT '时态复数等变换',
    `detail` TEXT DEFAULT NULL COMMENT '详细释义（JSON格式）',
    `audio_url` VARCHAR(500) DEFAULT NULL COMMENT '发音音频URL',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_word` (`word`),
    KEY `idx_tag` (`tag`),
    KEY `idx_collins` (`collins`),
    KEY `idx_bnc` (`bnc`),
    KEY `idx_frq` (`frq`),
    KEY `idx_oxford` (`oxford`),
    FULLTEXT KEY `ft_word` (`word`) WITH PARSER ngram,
    FULLTEXT KEY `ft_tag` (`tag`) WITH PARSER ngram
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='英语词库表';

-- ============================================================
-- 13. 英语课程表 (english_courses)
-- ============================================================
CREATE TABLE `english_courses` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '课程ID',
    `name` VARCHAR(100) NOT NULL COMMENT '课程名称',
    `code` VARCHAR(50) NOT NULL COMMENT '课程代码（如 IELTS, TOEFL, CET4）',
    `description` VARCHAR(500) DEFAULT NULL COMMENT '课程描述',
    `word_count` INT UNSIGNED DEFAULT 0 COMMENT '总单词数',
    `difficulty` INT DEFAULT 1 COMMENT '难度 1-5',
    `category` VARCHAR(50) DEFAULT NULL COMMENT '分类',
    `cover_image` VARCHAR(255) DEFAULT NULL COMMENT '封面图片',
    `icon` VARCHAR(50) DEFAULT 'school' COMMENT '图标',
    `color_theme` VARCHAR(50) DEFAULT 'primary' COMMENT '主题色',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    `is_active` TINYINT(1) DEFAULT 1 COMMENT '是否启用',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='英语课程表';

-- ============================================================
-- 14. 课程单词关联表 (course_words)
-- ============================================================
CREATE TABLE `course_words` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '关联ID',
    `course_id` BIGINT UNSIGNED NOT NULL COMMENT '课程ID',
    `word_id` BIGINT UNSIGNED NOT NULL COMMENT '单词ID',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_course_word` (`course_id`, `word_id`),
    KEY `idx_word_id` (`word_id`),
    CONSTRAINT `fk_course_words_course` FOREIGN KEY (`course_id`) REFERENCES `english_courses` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_course_words_word` FOREIGN KEY (`word_id`) REFERENCES `english_words` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课程单词关联表';

-- ============================================================
-- 15. 用户英语学习进度表 (user_word_progress)
-- ============================================================
CREATE TABLE `user_word_progress` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '进度ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `word_id` BIGINT UNSIGNED NOT NULL COMMENT '单词ID',
    `course_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '课程ID',
    `status` ENUM('new', 'learning', 'mastered') DEFAULT 'new' COMMENT '状态: new-新词, learning-学习中, mastered-已掌握',
    `familiarity` TINYINT DEFAULT 0 COMMENT '熟悉度 (0-5)',
    `review_count` INT DEFAULT 0 COMMENT '复习次数',
    `correct_count` INT DEFAULT 0 COMMENT '正确次数',
    `wrong_count` INT DEFAULT 0 COMMENT '错误次数',
    `next_review_at` DATETIME DEFAULT NULL COMMENT '下次复习时间',
    `last_review_at` DATETIME DEFAULT NULL COMMENT '最后复习时间',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_word` (`user_id`, `word_id`),
    KEY `idx_user_status` (`user_id`, `status`),
    KEY `idx_user_next_review` (`user_id`, `next_review_at`),
    KEY `idx_course_id` (`course_id`),
    CONSTRAINT `fk_user_word_progress_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_user_word_progress_word` FOREIGN KEY (`word_id`) REFERENCES `english_words` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_user_word_progress_course` FOREIGN KEY (`course_id`) REFERENCES `english_courses` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户英语学习进度表';

-- ============================================================
-- 16. 用户课程报名表 (user_courses)
-- ============================================================
CREATE TABLE `user_courses` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '报名ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `course_id` BIGINT UNSIGNED NOT NULL COMMENT '课程ID',
    `daily_goal` INT DEFAULT 20 COMMENT '每日学习目标单词数',
    `learned_count` INT DEFAULT 0 COMMENT '已学习单词数',
    `is_active` TINYINT(1) DEFAULT 1 COMMENT '是否激活',
    `intensity` ENUM('Standard', 'Cram') DEFAULT 'Standard' COMMENT '学习强度',
    `words_mastered` INT DEFAULT 0 COMMENT '已掌握单词数',
    `mastery_percent` DECIMAL(5, 2) DEFAULT 0.00 COMMENT '掌握百分比',
    `status` ENUM('active', 'paused', 'completed') DEFAULT 'active' COMMENT '状态(保留兼容)',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `completed_at` DATETIME DEFAULT NULL COMMENT '完成时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_course` (`user_id`, `course_id`),
    KEY `idx_course_id` (`course_id`),
    CONSTRAINT `fk_user_courses_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_user_courses_course` FOREIGN KEY (`course_id`) REFERENCES `english_courses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户课程报名表';

-- ============================================================
-- 17. 日历打卡记录表 (calendar_records)
-- ============================================================
CREATE TABLE `calendar_records` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '记录ID',
    `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    `record_date` DATE NOT NULL COMMENT '打卡日期',
    `status` ENUM('completed', 'partial', 'missed') DEFAULT 'partial' COMMENT '状态: completed-完成, partial-部分完成, missed-未完成',
    `study_minutes` INT DEFAULT 0 COMMENT '学习时长（分钟）',
    `points_completed` INT DEFAULT 0 COMMENT '完成的要点数',
    `words_learned` INT DEFAULT 0 COMMENT '学习的单词数',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_date` (`user_id`, `record_date`),
    KEY `idx_record_date` (`record_date`),
    CONSTRAINT `fk_calendar_records_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='日历打卡记录表';

-- ============================================================
-- 18. 目标主题配置表 (goal_themes) - 预设主题配置
-- ============================================================
CREATE TABLE `goal_themes` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主题ID',
    `theme_key` VARCHAR(50) NOT NULL COMMENT '主题标识',
    `icon` VARCHAR(50) NOT NULL COMMENT '图标名称',
    `color_class` VARCHAR(100) NOT NULL COMMENT '颜色类',
    `icon_bg_class` VARCHAR(200) NOT NULL COMMENT '图标背景类',
    `progress_gradient` VARCHAR(300) NOT NULL COMMENT '进度条渐变',
    `sort_order` INT DEFAULT 0 COMMENT '排序顺序',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_theme_key` (`theme_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='目标主题配置表';

-- ============================================================
-- 19. 艾宾浩斯复习周期配置表 (ebbinghaus_cycles)
-- ============================================================
CREATE TABLE `ebbinghaus_cycles` (
    `id` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '周期ID (1-8)',
    `stage` TINYINT NOT NULL COMMENT '复习阶段',
    `interval_days` INT NOT NULL COMMENT '间隔天数',
    `description` VARCHAR(100) DEFAULT NULL COMMENT '描述',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='艾宾浩斯复习周期配置表';

-- ============================================================
-- 插入预设主题数据
-- ============================================================
INSERT INTO `goal_themes` (`theme_key`, `icon`, `color_class`, `icon_bg_class`, `progress_gradient`, `sort_order`) VALUES
('byte', 'corporate_fare', 'text-primary', 'bg-white text-black', 'linear-gradient(to right, #3B82F6, #60A5FA)', 1),
('study', 'school', 'text-purple-400', 'bg-gradient-to-br from-purple-500 to-indigo-600 text-white', 'linear-gradient(to right, #A855F7, #6366F1)', 2),
('code', 'code', 'text-cyan-500', 'bg-gradient-to-br from-blue-500 to-cyan-500 text-white', 'linear-gradient(to right, #0EA5E9, #22D3EE)', 3),
('psychology', 'psychology', 'text-emerald-500', 'bg-gradient-to-br from-emerald-500 to-teal-500 text-white', 'linear-gradient(to right, #10B981, #14B8A6)', 4),
('group', 'group', 'text-rose-500', 'bg-gradient-to-br from-rose-500 to-pink-500 text-white', 'linear-gradient(to right, #F43F5E, #EC4899)', 5),
('star', 'star', 'text-amber-500', 'bg-gradient-to-br from-amber-400 to-orange-500 text-white', 'linear-gradient(to right, #F59E0B, #F97316)', 6),
('premium', 'workspace_premium', 'text-indigo-500', 'bg-gradient-to-br from-indigo-500 to-blue-600 text-white', 'linear-gradient(to right, #6366F1, #2563EB)', 7),
('science', 'science', 'text-lime-500', 'bg-gradient-to-br from-lime-500 to-green-500 text-white', 'linear-gradient(to right, #84CC16, #22C55E)', 8),
('language', 'language', 'text-fuchsia-500', 'bg-gradient-to-br from-fuchsia-500 to-violet-500 text-white', 'linear-gradient(to right, #D946EF, #8B5CF6)', 9),
('computer', 'computer', 'text-teal-500', 'bg-gradient-to-br from-teal-500 to-cyan-500 text-white', 'linear-gradient(to right, #14B8A6, #06B6D4)', 10),
('global', 'public', 'text-sky-500', 'bg-gradient-to-br from-sky-500 to-blue-500 text-white', 'linear-gradient(to right, #0EA5E9, #2563EB)', 11),
('terminal', 'terminal', 'text-slate-400', 'bg-gradient-to-br from-slate-500 to-slate-700 text-white', 'linear-gradient(to right, #64748B, #334155)', 12),
('light', 'emoji_objects', 'text-yellow-500', 'bg-gradient-to-br from-yellow-400 to-amber-500 text-white', 'linear-gradient(to right, #F59E0B, #FB923C)', 13),
('rocket', 'rocket_launch', 'text-orange-500', 'bg-gradient-to-br from-orange-500 to-red-500 text-white', 'linear-gradient(to right, #F97316, #EF4444)', 14);

-- ============================================================
-- 插入默认英语课程数据
-- ============================================================
INSERT INTO `english_courses` (`name`, `code`, `description`, `total_words`, `difficulty`, `icon`, `color_theme`, `sort_order`) VALUES
('雅思核心词汇', 'IELTS', 'IELTS Core Vocabulary - Academic English for global education', 3500, 'Hard', 'school', 'purple', 1),
('托福iBT词汇', 'TOEFL', 'TOEFL iBT Vocabulary - Academic English for US universities', 4000, 'Hard', 'flight', 'blue', 2),
('GRE高频词汇', 'GRE', 'GRE High-Frequency Words - Advanced vocabulary for graduate studies', 5000, 'Expert', 'psychology', 'rose', 3),
('大学英语四级', 'CET4', 'CET-4 Vocabulary - College English Test Band 4', 4500, 'Medium', 'book', 'green', 4),
('大学英语六级', 'CET6', 'CET-6 Vocabulary - College English Test Band 6', 5500, 'Medium', 'book', 'teal', 5),
('考研英语词汇', 'KAOYAN', 'Graduate Entrance Exam English Vocabulary', 5500, 'Hard', 'school', 'indigo', 6);

-- ============================================================
-- 插入修正版艾宾浩斯复习周期（舍弃前三个短周期）
-- ============================================================
INSERT INTO `ebbinghaus_cycles` (`stage`, `interval_days`, `description`) VALUES
(1, 1, 'T + 1天'),
(2, 2, 'T + 2天'),
(3, 4, 'T + 4天'),
(4, 7, 'T + 7天'),
(5, 15, 'T + 15天'),
(6, 30, 'T + 30天 (1个月)'),
(7, 90, 'T + 90天 (3个月)'),
(8, 180, 'T + 180天 (6个月)');

-- ============================================================
-- 创建视图：待复习要点视图
-- ============================================================
CREATE VIEW `v_pending_reviews` AS
SELECT
    p.id AS point_id,
    p.user_id,
    p.title AS point_title,
    p.current_review_stage,
    p.next_review_date,
    p.learned_at,
    c.id AS chapter_id,
    c.title AS chapter_title,
    s.id AS subject_id,
    s.title AS subject_title,
    s.icon AS subject_icon,
    s.color_class AS subject_color,
    g.id AS goal_id,
    g.title AS goal_title,
    DATEDIFF(CURDATE(), p.next_review_date) AS overdue_days
FROM `points` p
JOIN `chapters` c ON p.chapter_id = c.id
JOIN `subjects` s ON p.subject_id = s.id
JOIN `goals` g ON s.goal_id = g.id
WHERE p.is_learned = 1
  AND p.review_completed = 0
  AND p.next_review_date IS NOT NULL
  AND p.next_review_date <= CURDATE();

-- ============================================================
-- 创建视图：用户学习统计视图
-- ============================================================
CREATE VIEW `v_user_stats` AS
SELECT
    u.id AS user_id,
    COUNT(DISTINCT g.id) AS total_goals,
    COUNT(DISTINCT s.id) AS total_subjects,
    COUNT(DISTINCT p.id) AS total_points,
    SUM(CASE WHEN p.status = 'completed' THEN 1 ELSE 0 END) AS completed_points,
    SUM(CASE WHEN p.next_review_date <= CURDATE() AND p.review_completed = 0 THEN 1 ELSE 0 END) AS pending_reviews
FROM `users` u
LEFT JOIN `goals` g ON u.id = g.user_id AND g.status = 'active'
LEFT JOIN `subjects` s ON g.id = s.goal_id
LEFT JOIN `points` p ON s.id = p.subject_id
GROUP BY u.id;

-- ============================================================
-- 创建视图：桌面小组件数据视图
-- ============================================================
CREATE VIEW `v_widget_summary` AS
SELECT
    s.id AS subject_id,
    s.user_id,
    s.title AS subject_title,
    s.icon,
    s.color_class,
    s.progress,
    g.title AS goal_title,
    COUNT(CASE WHEN p.next_review_date <= CURDATE() AND p.review_completed = 0 THEN 1 END) AS pending_review_count,
    CASE
        WHEN COUNT(CASE WHEN p.next_review_date < CURDATE() AND p.review_completed = 0 THEN 1 END) > 0 THEN 'red'
        WHEN COUNT(CASE WHEN p.next_review_date = CURDATE() AND p.review_completed = 0 THEN 1 END) > 0 THEN 'yellow'
        ELSE 'green'
    END AS light_status
FROM `subjects` s
JOIN `goals` g ON s.goal_id = g.id AND g.status = 'active'
LEFT JOIN `points` p ON s.id = p.subject_id AND p.is_learned = 1
GROUP BY s.id, s.user_id, s.title, s.icon, s.color_class, s.progress, g.title;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- 数据库初始化完成！
-- ============================================================
