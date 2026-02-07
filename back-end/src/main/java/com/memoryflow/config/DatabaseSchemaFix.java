package com.memoryflow.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

@Component
@Slf4j
public class DatabaseSchemaFix implements CommandLineRunner {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) throws Exception {
        log.info("Checking database schema for EnglishCourse...");
        fixEnglishCoursesTable();
        log.info("Checking database schema for UserCourse...");
        fixUserCoursesTable();
    }

    private void fixUserCoursesTable() {
        try {
            List<Map<String, Object>> columns = jdbcTemplate.queryForList("SHOW COLUMNS FROM user_courses");

            boolean hasIsActive = columns.stream().anyMatch(c -> "is_active".equals(c.get("Field")));
            boolean hasStatus = columns.stream().anyMatch(c -> "status".equals(c.get("Field")));
            
            boolean hasDailyGoal = columns.stream().anyMatch(c -> "daily_goal".equals(c.get("Field")));
            boolean hasDailyPace = columns.stream().anyMatch(c -> "daily_pace".equals(c.get("Field")));
            
            boolean hasLearnedCount = columns.stream().anyMatch(c -> "learned_count".equals(c.get("Field")));
            boolean hasWordsLearned = columns.stream().anyMatch(c -> "words_learned".equals(c.get("Field")));
            
            boolean hasCreatedAt = columns.stream().anyMatch(c -> "created_at".equals(c.get("Field")));
            boolean hasStartedAt = columns.stream().anyMatch(c -> "started_at".equals(c.get("Field")));

            // 1. Fix is_active
            if (!hasIsActive) {
                log.info("Adding is_active column...");
                jdbcTemplate.execute("ALTER TABLE user_courses ADD COLUMN is_active TINYINT(1) DEFAULT 1");
                if (hasStatus) {
                    log.info("Migrating status to is_active...");
                    jdbcTemplate.execute("UPDATE user_courses SET is_active = 0 WHERE status = 'paused' OR status = 'completed'");
                    // Optional: Drop status column if no longer needed, or keep it. Keeping it for now to avoid data loss.
                }
            }

            // 2. Fix daily_goal
            if (!hasDailyGoal) {
                if (hasDailyPace) {
                    log.info("Renaming daily_pace to daily_goal...");
                    jdbcTemplate.execute("ALTER TABLE user_courses CHANGE daily_pace daily_goal INT DEFAULT 20");
                } else {
                    jdbcTemplate.execute("ALTER TABLE user_courses ADD COLUMN daily_goal INT DEFAULT 20");
                }
            }

            // 3. Fix learned_count
            if (!hasLearnedCount) {
                if (hasWordsLearned) {
                    log.info("Renaming words_learned to learned_count...");
                    jdbcTemplate.execute("ALTER TABLE user_courses CHANGE words_learned learned_count INT DEFAULT 0");
                } else {
                    jdbcTemplate.execute("ALTER TABLE user_courses ADD COLUMN learned_count INT DEFAULT 0");
                }
            }

            // 4. Fix created_at
            if (!hasCreatedAt) {
                if (hasStartedAt) {
                    log.info("Renaming started_at to created_at...");
                    jdbcTemplate.execute("ALTER TABLE user_courses CHANGE started_at created_at DATETIME DEFAULT CURRENT_TIMESTAMP");
                } else {
                    jdbcTemplate.execute("ALTER TABLE user_courses ADD COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP");
                }
            }
            
            log.info("UserCourse schema fix completed.");
        } catch (Exception e) {
            log.error("Error fixing UserCourse schema", e);
        }
    }

    private void fixEnglishCoursesTable() {
        try {
            // Check columns
            List<Map<String, Object>> columns = jdbcTemplate.queryForList("SHOW COLUMNS FROM english_courses");
            
            boolean hasWordCount = columns.stream().anyMatch(c -> "word_count".equals(c.get("Field")));
            boolean hasTotalWords = columns.stream().anyMatch(c -> "total_words".equals(c.get("Field")));
            boolean hasCoverImage = columns.stream().anyMatch(c -> "cover_image".equals(c.get("Field")));
            boolean hasCategory = columns.stream().anyMatch(c -> "category".equals(c.get("Field")));
            boolean difficultyIsInt = columns.stream().anyMatch(c -> "difficulty".equals(c.get("Field")) && c.get("Type").toString().toLowerCase().contains("int"));

            // 1. Fix word_count
            if (!hasWordCount) {
                if (hasTotalWords) {
                    log.info("Renaming total_words to word_count...");
                    jdbcTemplate.execute("ALTER TABLE english_courses CHANGE total_words word_count INT DEFAULT 0");
                } else {
                    log.info("Adding word_count column...");
                    jdbcTemplate.execute("ALTER TABLE english_courses ADD COLUMN word_count INT DEFAULT 0");
                }
            }

            // 2. Fix cover_image
            if (!hasCoverImage) {
                log.info("Adding cover_image column...");
                jdbcTemplate.execute("ALTER TABLE english_courses ADD COLUMN cover_image VARCHAR(255) DEFAULT NULL");
            }

            // 3. Fix category
            if (!hasCategory) {
                log.info("Adding category column...");
                jdbcTemplate.execute("ALTER TABLE english_courses ADD COLUMN category VARCHAR(50) DEFAULT NULL");
            }
            
            // 4. Fix difficulty type (ENUM to INT)
            if (!difficultyIsInt) {
                 log.info("Migrating difficulty from ENUM to INT...");
                 try {
                     // Add temporary column
                     jdbcTemplate.execute("ALTER TABLE english_courses ADD COLUMN difficulty_new INT DEFAULT 1");
                     
                     // Migrate data
                     jdbcTemplate.execute("UPDATE english_courses SET difficulty_new = 1 WHERE difficulty = 'Easy'");
                     jdbcTemplate.execute("UPDATE english_courses SET difficulty_new = 2 WHERE difficulty = 'Medium'");
                     jdbcTemplate.execute("UPDATE english_courses SET difficulty_new = 3 WHERE difficulty = 'Hard'");
                     jdbcTemplate.execute("UPDATE english_courses SET difficulty_new = 4 WHERE difficulty = 'Expert'");
                     
                     // Drop old column
                     jdbcTemplate.execute("ALTER TABLE english_courses DROP COLUMN difficulty");
                     
                     // Rename new column
                     jdbcTemplate.execute("ALTER TABLE english_courses CHANGE difficulty_new difficulty INT DEFAULT 1");
                     
                     log.info("Difficulty column migration completed.");
                 } catch (Exception e) {
                     log.error("Failed to migrate difficulty column", e);
                 }
            }

            log.info("Database schema fix completed.");

        } catch (Exception e) {
            log.error("Error fixing database schema", e);
        }
    }
}
