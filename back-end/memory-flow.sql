/*
 Navicat Premium Data Transfer

 Source Server         : 记忆流-阿里
 Source Server Type    : MySQL
 Source Server Version : 80035
 Source Host           : 8.138.16.119:3306
 Source Schema         : memory-flow

 Target Server Type    : MySQL
 Target Server Version : 80035
 File Encoding         : 65001

 Date: 01/03/2026 13:08:58
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for admin_whitelist
-- ----------------------------
DROP TABLE IF EXISTS `admin_whitelist`;
CREATE TABLE `admin_whitelist`  (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '许可邮箱',
  `created_by` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '添加人',
  `created_at` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `is_registered` tinyint(1) NULL DEFAULT 0 COMMENT '是否已注册',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_email`(`email` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 15 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '注册白名单表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for articles
-- ----------------------------
DROP TABLE IF EXISTS `articles`;
CREATE TABLE `articles`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '文章ID',
  `chapter_id` bigint UNSIGNED NULL DEFAULT NULL COMMENT '所属章节ID（若直接属于章节）',
  `point_id` bigint UNSIGNED NULL DEFAULT NULL COMMENT '所属要点ID（若属于二级要点）',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '文章标题',
  `content` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '详细内容（Markdown格式）',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_chapter_id`(`chapter_id` ASC) USING BTREE,
  INDEX `idx_point_id`(`point_id` ASC) USING BTREE,
  CONSTRAINT `fk_articles_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapters` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_articles_point` FOREIGN KEY (`point_id`) REFERENCES `points` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 136 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '文章内容表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for calendar_records
-- ----------------------------
DROP TABLE IF EXISTS `calendar_records`;
CREATE TABLE `calendar_records`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '记录ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `record_date` date NOT NULL COMMENT '打卡日期',
  `status` enum('completed','partial','missed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'partial' COMMENT '状态: completed-完成, partial-部分完成, missed-未完成',
  `study_minutes` int NULL DEFAULT 0 COMMENT '学习时长（分钟）',
  `points_completed` int NULL DEFAULT 0 COMMENT '完成的要点数',
  `words_learned` int NULL DEFAULT 0 COMMENT '学习的单词数',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_date`(`user_id` ASC, `record_date` ASC) USING BTREE,
  INDEX `idx_record_date`(`record_date` ASC) USING BTREE,
  CONSTRAINT `fk_calendar_records_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '日历打卡记录表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for chapters
-- ----------------------------
DROP TABLE IF EXISTS `chapters`;
CREATE TABLE `chapters`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '章节ID',
  `subject_id` bigint UNSIGNED NOT NULL COMMENT '所属科目ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID（冗余字段）',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '章节标题',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_subject_id`(`subject_id` ASC) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  CONSTRAINT `fk_chapters_subject` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_chapters_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 44 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '章节表（一级）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for course_words
-- ----------------------------
DROP TABLE IF EXISTS `course_words`;
CREATE TABLE `course_words`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '关联ID',
  `course_id` bigint UNSIGNED NOT NULL COMMENT '课程ID',
  `word_id` bigint UNSIGNED NOT NULL COMMENT '单词ID',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_course_word`(`course_id` ASC, `word_id` ASC) USING BTREE,
  INDEX `idx_word_id`(`word_id` ASC) USING BTREE,
  CONSTRAINT `fk_course_words_course` FOREIGN KEY (`course_id`) REFERENCES `english_courses` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_course_words_word` FOREIGN KEY (`word_id`) REFERENCES `english_words` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 23451 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '课程单词关联表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ebbinghaus_cycles
-- ----------------------------
DROP TABLE IF EXISTS `ebbinghaus_cycles`;
CREATE TABLE `ebbinghaus_cycles`  (
  `id` tinyint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '周期ID (1-8)',
  `stage` tinyint NOT NULL COMMENT '复习阶段',
  `interval_days` int NOT NULL COMMENT '间隔天数',
  `description` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '描述',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 8 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '艾宾浩斯复习周期配置表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for email_reminder_logs
-- ----------------------------
DROP TABLE IF EXISTS `email_reminder_logs`;
CREATE TABLE `email_reminder_logs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '记录ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `reminder_type` enum('daily','week','month') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '提醒类型: daily-超过1天, week-超过7天, month-超过1个月',
  `overdue_days` int NOT NULL COMMENT '逾期天数',
  `pending_reviews` int NOT NULL COMMENT '待复习要点数量',
  `email_subject` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '邮件主题',
  `email_content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '邮件内容',
  `sent_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发送时间',
  `is_sent` tinyint(1) NULL DEFAULT 1 COMMENT '是否发送成功',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_user_type`(`user_id` ASC, `reminder_type` ASC) USING BTREE,
  INDEX `idx_sent_at`(`sent_at` ASC) USING BTREE,
  CONSTRAINT `fk_email_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '邮件提醒记录表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for english_courses
-- ----------------------------
DROP TABLE IF EXISTS `english_courses`;
CREATE TABLE `english_courses`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '课程ID',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '课程名称',
  `code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '课程代码（如 IELTS, TOEFL, CET4）',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '课程描述',
  `word_count` int NULL DEFAULT 0,
  `icon` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'school' COMMENT '图标',
  `color_theme` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'primary' COMMENT '主题色',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  `is_active` tinyint(1) NULL DEFAULT 1 COMMENT '是否启用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `cover_image` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `category` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `difficulty` int NULL DEFAULT 1,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_code`(`code` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 7 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '英语课程表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for english_words
-- ----------------------------
DROP TABLE IF EXISTS `english_words`;
CREATE TABLE `english_words`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '单词ID',
  `word` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '单词',
  `phonetic` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '音标',
  `definition` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '中文释义',
  `translation` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '英文翻译',
  `pos` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '词性',
  `collins` tinyint NULL DEFAULT NULL COMMENT '柯林斯星级 (1-5)',
  `oxford` tinyint NULL DEFAULT NULL COMMENT '是否牛津核心词汇',
  `tag` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '标签（如 cet4, cet6, ielts, toefl, gre）',
  `bnc` int NULL DEFAULT NULL COMMENT 'BNC词频顺序',
  `frq` int NULL DEFAULT NULL COMMENT '当代语料库词频顺序',
  `exchange` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '时态复数等变换',
  `detail` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '详细释义（JSON格式）',
  `audio_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '发音音频URL',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_word`(`word` ASC) USING BTREE,
  INDEX `idx_tag`(`tag` ASC) USING BTREE,
  INDEX `idx_collins`(`collins` ASC) USING BTREE,
  INDEX `idx_bnc`(`bnc` ASC) USING BTREE,
  INDEX `idx_frq`(`frq` ASC) USING BTREE,
  INDEX `idx_oxford`(`oxford` ASC) USING BTREE,
  FULLTEXT INDEX `ft_word`(`word`) WITH PARSER `ngram`,
  FULLTEXT INDEX `ft_tag`(`tag`) WITH PARSER `ngram`
) ENGINE = InnoDB AUTO_INCREMENT = 14937 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '英语词库表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for goal_themes
-- ----------------------------
DROP TABLE IF EXISTS `goal_themes`;
CREATE TABLE `goal_themes`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主题ID',
  `theme_key` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '主题标识',
  `icon` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '图标名称',
  `color_class` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '颜色类',
  `icon_bg_class` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '图标背景类',
  `progress_gradient` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '进度条渐变',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_theme_key`(`theme_key` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 15 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '目标主题配置表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for goals
-- ----------------------------
DROP TABLE IF EXISTS `goals`;
CREATE TABLE `goals`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '目标ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '目标标题',
  `subtitle` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '副标题/下一步任务',
  `label_type` enum('priority','daily','longterm') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'priority' COMMENT '标签类型: priority-高优先, daily-每日打卡, longterm-长期计划',
  `progress` tinyint UNSIGNED NULL DEFAULT 0 COMMENT '进度百分比 (0-100)',
  `icon` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'target' COMMENT 'Material Icons图标名',
  `color_class` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'text-primary' COMMENT '颜色CSS类名',
  `icon_bg_class` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '图标背景CSS类名',
  `progress_gradient` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '进度条渐变色',
  `status` enum('active','completed','archived') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'active' COMMENT '状态: active-进行中, completed-已完成, archived-已归档',
  `due_date` date NULL DEFAULT NULL COMMENT '截止日期',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_user_status`(`user_id` ASC, `status` ASC) USING BTREE,
  INDEX `idx_due_date`(`due_date` ASC) USING BTREE,
  CONSTRAINT `fk_goals_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 15 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '学习目标表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for points
-- ----------------------------
DROP TABLE IF EXISTS `points`;
CREATE TABLE `points`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '要点ID',
  `chapter_id` bigint UNSIGNED NOT NULL COMMENT '所属章节ID',
  `subject_id` bigint UNSIGNED NOT NULL COMMENT '所属科目ID（冗余字段）',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID（冗余字段）',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '要点标题',
  `content` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '详细内容（Markdown格式）',
  `status` enum('pending','in-progress','completed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'pending' COMMENT '学习状态',
  `is_learned` tinyint(1) NULL DEFAULT 0 COMMENT '是否已学习（首次勾选）',
  `learned_at` datetime NULL DEFAULT NULL COMMENT '首次学习时间（触发复习计划的时间）',
  `current_review_stage` tinyint NULL DEFAULT 0 COMMENT '当前复习阶段 (0=未开始, 1-8对应8个复习周期)',
  `next_review_date` date NULL DEFAULT NULL COMMENT '下次复习日期',
  `last_review_at` datetime NULL DEFAULT NULL COMMENT '最近一次复习时间',
  `review_completed` tinyint(1) NULL DEFAULT 0 COMMENT '是否完成所有复习周期',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_chapter_id`(`chapter_id` ASC) USING BTREE,
  INDEX `idx_subject_id`(`subject_id` ASC) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_user_status`(`user_id` ASC, `status` ASC) USING BTREE,
  INDEX `idx_next_review_date`(`next_review_date` ASC) USING BTREE COMMENT '复习日期索引，用于查询待复习内容',
  INDEX `idx_user_next_review`(`user_id` ASC, `next_review_date` ASC) USING BTREE COMMENT '用户待复习内容索引',
  INDEX `idx_review_stage`(`current_review_stage` ASC) USING BTREE,
  CONSTRAINT `fk_points_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapters` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_points_subject` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_points_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 86 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '知识点/要点表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for review_logs
-- ----------------------------
DROP TABLE IF EXISTS `review_logs`;
CREATE TABLE `review_logs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '记录ID',
  `point_id` bigint UNSIGNED NOT NULL COMMENT '要点ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `review_stage` tinyint NOT NULL COMMENT '复习阶段 (1-8)',
  `scheduled_date` date NOT NULL COMMENT '计划复习日期',
  `actual_review_at` datetime NULL DEFAULT NULL COMMENT '实际复习时间',
  `is_completed` tinyint(1) NULL DEFAULT 0 COMMENT '是否已完成',
  `is_overdue` tinyint(1) NULL DEFAULT 0 COMMENT '是否逾期',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_point_id`(`point_id` ASC) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_user_scheduled`(`user_id` ASC, `scheduled_date` ASC) USING BTREE,
  INDEX `idx_user_completed`(`user_id` ASC, `is_completed` ASC) USING BTREE,
  CONSTRAINT `fk_review_logs_point` FOREIGN KEY (`point_id`) REFERENCES `points` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_review_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '复习记录表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for subjects
-- ----------------------------
DROP TABLE IF EXISTS `subjects`;
CREATE TABLE `subjects`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '科目ID',
  `goal_id` bigint UNSIGNED NOT NULL COMMENT '所属目标ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID（冗余字段，便于查询）',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '科目名称',
  `progress` tinyint UNSIGNED NULL DEFAULT 0 COMMENT '进度百分比 (0-100)',
  `total_points` int UNSIGNED NULL DEFAULT 0 COMMENT '总要点数',
  `completed_points` int UNSIGNED NULL DEFAULT 0 COMMENT '已完成要点数',
  `icon` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'book' COMMENT 'Material Icons图标名',
  `color_class` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'text-primary' COMMENT '文字颜色类',
  `bg_class` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'bg-primary' COMMENT '背景颜色类',
  `status` enum('Pending','In Progress','Due Today','Completed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'Pending' COMMENT '状态',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_goal_id`(`goal_id` ASC) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_user_status`(`user_id` ASC, `status` ASC) USING BTREE,
  CONSTRAINT `fk_subjects_goal` FOREIGN KEY (`goal_id`) REFERENCES `goals` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_subjects_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 23 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '科目表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for tasks
-- ----------------------------
DROP TABLE IF EXISTS `tasks`;
CREATE TABLE `tasks`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '任务ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '任务标题',
  `scheduled_time` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '计划时间描述（如 20:00 - 21:00）',
  `completed` tinyint(1) NULL DEFAULT 0 COMMENT '是否完成',
  `completed_at` datetime NULL DEFAULT NULL COMMENT '完成时间',
  `tag` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '标签类型',
  `tag_color` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '标签颜色',
  `task_date` date NOT NULL COMMENT '任务日期',
  `sort_order` int NULL DEFAULT 0 COMMENT '排序顺序',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_user_date`(`user_id` ASC, `task_date` ASC) USING BTREE,
  INDEX `idx_task_date`(`task_date` ASC) USING BTREE,
  CONSTRAINT `fk_tasks_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '每日任务表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_courses
-- ----------------------------
DROP TABLE IF EXISTS `user_courses`;
CREATE TABLE `user_courses`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '报名ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `course_id` bigint UNSIGNED NOT NULL COMMENT '课程ID',
  `daily_goal` int NULL DEFAULT 20,
  `intensity` enum('Standard','Cram') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'Standard' COMMENT '学习强度',
  `learned_count` int NULL DEFAULT 0,
  `words_mastered` int NULL DEFAULT 0 COMMENT '已掌握单词数',
  `mastery_percent` decimal(5, 2) NULL DEFAULT 0.00 COMMENT '掌握百分比',
  `status` enum('active','paused','completed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'active' COMMENT '状态',
  `created_at` datetime NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` datetime NULL DEFAULT NULL COMMENT '完成时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_active` tinyint(1) NULL DEFAULT 1,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_course`(`user_id` ASC, `course_id` ASC) USING BTREE,
  INDEX `idx_course_id`(`course_id` ASC) USING BTREE,
  CONSTRAINT `fk_user_courses_course` FOREIGN KEY (`course_id`) REFERENCES `english_courses` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_user_courses_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 13 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '用户课程报名表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_settings
-- ----------------------------
DROP TABLE IF EXISTS `user_settings`;
CREATE TABLE `user_settings`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `theme` enum('dark','light','auto') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'dark' COMMENT '主题模式',
  `reminder_enabled` tinyint(1) NULL DEFAULT 1 COMMENT '是否启用提醒',
  `reminder_time` time NULL DEFAULT '20:00:00' COMMENT '提醒时间',
  `email_reminder_enabled` tinyint(1) NULL DEFAULT 1 COMMENT '是否启用邮件提醒',
  `widget_auto_start` tinyint(1) NULL DEFAULT 0 COMMENT '桌面小组件是否开机自启',
  `floating_window_enabled` tinyint(1) NULL DEFAULT 1 COMMENT '是否启用悬浮窗',
  `last_sync_at` datetime NULL DEFAULT NULL COMMENT '最后同步时间',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `daily_new_words_goal` int NULL DEFAULT 20 COMMENT '每日新词目标',
  `auto_play_audio` tinyint(1) NULL DEFAULT 1 COMMENT '自动播放音频',
  `sound_effects_enabled` tinyint(1) NULL DEFAULT 1 COMMENT '启用音效',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_id`(`user_id` ASC) USING BTREE,
  CONSTRAINT `fk_user_settings_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 18 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '用户设置表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_tokens
-- ----------------------------
DROP TABLE IF EXISTS `user_tokens`;
CREATE TABLE `user_tokens`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `refresh_token` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '刷新Token',
  `device_info` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '设备信息',
  `ip_address` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT 'IP地址',
  `expires_at` datetime NOT NULL COMMENT '过期时间',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_refresh_token`(`refresh_token`(191) ASC) USING BTREE,
  INDEX `idx_expires_at`(`expires_at` ASC) USING BTREE,
  CONSTRAINT `fk_user_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 497 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '用户Token表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_word_progress
-- ----------------------------
DROP TABLE IF EXISTS `user_word_progress`;
CREATE TABLE `user_word_progress`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '进度ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '用户ID',
  `word_id` bigint UNSIGNED NOT NULL COMMENT '单词ID',
  `course_id` bigint UNSIGNED NULL DEFAULT NULL COMMENT '课程ID',
  `status` enum('new','learning','mastered') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'new' COMMENT '状态: new-新词, learning-学习中, mastered-已掌握',
  `familiarity` tinyint NULL DEFAULT 0 COMMENT '熟悉度 (0-5)',
  `review_count` int NULL DEFAULT 0 COMMENT '复习次数',
  `correct_count` int NULL DEFAULT 0 COMMENT '正确次数',
  `wrong_count` int NULL DEFAULT 0 COMMENT '错误次数',
  `next_review_at` datetime NULL DEFAULT NULL COMMENT '下次复习时间',
  `last_review_at` datetime NULL DEFAULT NULL COMMENT '最后复习时间',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_word`(`user_id` ASC, `word_id` ASC) USING BTREE,
  INDEX `idx_user_status`(`user_id` ASC, `status` ASC) USING BTREE,
  INDEX `idx_user_next_review`(`user_id` ASC, `next_review_at` ASC) USING BTREE,
  INDEX `idx_course_id`(`course_id` ASC) USING BTREE,
  INDEX `fk_user_word_progress_word`(`word_id` ASC) USING BTREE,
  CONSTRAINT `fk_user_word_progress_course` FOREIGN KEY (`course_id`) REFERENCES `english_courses` (`id`) ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT `fk_user_word_progress_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_user_word_progress_word` FOREIGN KEY (`word_id`) REFERENCES `english_words` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 56 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '用户英语学习进度表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '邮箱（用于登录）',
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '密码哈希值',
  `nickname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '昵称',
  `avatar_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '头像URL',
  `major` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '专业',
  `grade` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '年级/职级',
  `email_verified` tinyint(1) NULL DEFAULT 0 COMMENT '邮箱是否已验证',
  `status` tinyint NULL DEFAULT 1 COMMENT '状态: 0-禁用, 1-正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `registration_ip` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '注册IP',
  `last_login_ip` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '最后登录IP',
  `last_login_time` datetime NULL DEFAULT NULL COMMENT '最后登录时间',
  `login_count` int NULL DEFAULT 0 COMMENT '登录次数',
  `role` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT 'USER' COMMENT '角色: USER, ADMIN',
  `registration_location` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '注册归属地',
  `last_login_location` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '最后登录归属地',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_email`(`email` ASC) USING BTREE,
  INDEX `idx_status`(`status` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 18 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '用户表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- View structure for v_pending_reviews
-- ----------------------------
DROP VIEW IF EXISTS `v_pending_reviews`;
CREATE ALGORITHM = UNDEFINED SQL SECURITY DEFINER VIEW `v_pending_reviews` AS select `p`.`id` AS `point_id`,`p`.`user_id` AS `user_id`,`p`.`title` AS `point_title`,`p`.`current_review_stage` AS `current_review_stage`,`p`.`next_review_date` AS `next_review_date`,`p`.`learned_at` AS `learned_at`,`c`.`id` AS `chapter_id`,`c`.`title` AS `chapter_title`,`s`.`id` AS `subject_id`,`s`.`title` AS `subject_title`,`s`.`icon` AS `subject_icon`,`s`.`color_class` AS `subject_color`,`g`.`id` AS `goal_id`,`g`.`title` AS `goal_title`,(to_days(curdate()) - to_days(`p`.`next_review_date`)) AS `overdue_days` from (((`points` `p` join `chapters` `c` on((`p`.`chapter_id` = `c`.`id`))) join `subjects` `s` on((`p`.`subject_id` = `s`.`id`))) join `goals` `g` on((`s`.`goal_id` = `g`.`id`))) where ((`p`.`is_learned` = 1) and (`p`.`review_completed` = 0) and (`p`.`next_review_date` is not null) and (`p`.`next_review_date` <= curdate()));

-- ----------------------------
-- View structure for v_user_stats
-- ----------------------------
DROP VIEW IF EXISTS `v_user_stats`;
CREATE ALGORITHM = UNDEFINED SQL SECURITY DEFINER VIEW `v_user_stats` AS select `u`.`id` AS `user_id`,count(distinct `g`.`id`) AS `total_goals`,count(distinct `s`.`id`) AS `total_subjects`,count(distinct `p`.`id`) AS `total_points`,sum((case when (`p`.`status` = 'completed') then 1 else 0 end)) AS `completed_points`,sum((case when ((`p`.`next_review_date` <= curdate()) and (`p`.`review_completed` = 0)) then 1 else 0 end)) AS `pending_reviews` from (((`users` `u` left join `goals` `g` on(((`u`.`id` = `g`.`user_id`) and (`g`.`status` = 'active')))) left join `subjects` `s` on((`g`.`id` = `s`.`goal_id`))) left join `points` `p` on((`s`.`id` = `p`.`subject_id`))) group by `u`.`id`;

-- ----------------------------
-- View structure for v_widget_summary
-- ----------------------------
DROP VIEW IF EXISTS `v_widget_summary`;
CREATE ALGORITHM = UNDEFINED SQL SECURITY DEFINER VIEW `v_widget_summary` AS select `s`.`id` AS `subject_id`,`s`.`user_id` AS `user_id`,`s`.`title` AS `subject_title`,`s`.`icon` AS `icon`,`s`.`color_class` AS `color_class`,`s`.`progress` AS `progress`,`g`.`title` AS `goal_title`,count((case when ((`p`.`next_review_date` <= curdate()) and (`p`.`review_completed` = 0)) then 1 end)) AS `pending_review_count`,(case when (count((case when ((`p`.`next_review_date` < curdate()) and (`p`.`review_completed` = 0)) then 1 end)) > 0) then 'red' when (count((case when ((`p`.`next_review_date` = curdate()) and (`p`.`review_completed` = 0)) then 1 end)) > 0) then 'yellow' else 'green' end) AS `light_status` from ((`subjects` `s` join `goals` `g` on(((`s`.`goal_id` = `g`.`id`) and (`g`.`status` = 'active')))) left join `points` `p` on(((`s`.`id` = `p`.`subject_id`) and (`p`.`is_learned` = 1)))) group by `s`.`id`,`s`.`user_id`,`s`.`title`,`s`.`icon`,`s`.`color_class`,`s`.`progress`,`g`.`title`;

SET FOREIGN_KEY_CHECKS = 1;
