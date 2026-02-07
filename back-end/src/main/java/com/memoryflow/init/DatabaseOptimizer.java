package com.memoryflow.init;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * 数据库索引优化初始化器
 * 用于在应用启动时自动检测并添加必要的性能优化索引
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class DatabaseOptimizer implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) throws Exception {
        log.info("Checking database indexes for optimization...");
        
        // 1. 优化词频查询性能 (bnc, frq)
        addIndexIfNotExists("english_words", "idx_bnc", "bnc");
        addIndexIfNotExists("english_words", "idx_frq", "frq");
        
        // 2. 优化标签模糊搜索性能 (tag) - 使用全文索引
        // 注意：FULLTEXT 索引在 MySQL 5.6+ InnoDB 中支持
        addFullTextIndexIfNotExists("english_words", "ft_tag", "tag");
        
        // 3. 优化牛津核心词汇查询 (oxford)
        addIndexIfNotExists("english_words", "idx_oxford", "oxford");

        // 4. 检查并添加 english_courses 缺失列 (icon, color_theme, cover_image, sort_order)
        addColumnIfNotExists("english_courses", "icon", "VARCHAR(50)");
        addColumnIfNotExists("english_courses", "color_theme", "VARCHAR(50)");
        addColumnIfNotExists("english_courses", "cover_image", "VARCHAR(255)");
        addColumnIfNotExists("english_courses", "sort_order", "INT DEFAULT 0");
        
        // 5. 更新课程元数据 (图标和颜色)
        updateCourseMetadata();

        log.info("Database optimization check completed.");
    }

    private void addColumnIfNotExists(String tableName, String columnName, String columnType) {
        try {
            Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.columns " +
                "WHERE table_schema = DATABASE() " +
                "AND table_name = ? AND column_name = ?",
                Integer.class, tableName, columnName
            );

            if (count == null || count == 0) {
                log.info("Adding column {} to table {}...", columnName, tableName);
                jdbcTemplate.execute(String.format("ALTER TABLE %s ADD COLUMN %s %s", tableName, columnName, columnType));
                log.info("Column {} added successfully.", columnName);
            }
        } catch (Exception e) {
            log.error("Failed to add column " + columnName, e);
        }
    }

    private void updateCourseMetadata() {
        updateCourseData("IELTS", "school", "purple");
        updateCourseData("TOEFL", "public", "blue");
        updateCourseData("GRE", "menu_book", "rose");
        updateCourseData("CET4", "workspace_premium", "green");
        updateCourseData("CET6", "workspace_premium", "green");
        updateCourseData("KAOYAN", "school", "teal");
    }

    private void updateCourseData(String code, String icon, String colorTheme) {
        try {
            jdbcTemplate.update(
                "UPDATE english_courses SET icon = ?, color_theme = ? WHERE code = ? AND (icon IS NULL OR color_theme IS NULL)",
                icon, colorTheme, code
            );
        } catch (Exception e) {
            log.error("Failed to update metadata for course " + code, e);
        }
    }

    private void addIndexIfNotExists(String tableName, String indexName, String columnName) {
        try {
            Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.statistics " +
                "WHERE table_schema = DATABASE() " +
                "AND table_name = ? AND index_name = ?",
                Integer.class, tableName, indexName
            );

            if (count == null || count == 0) {
                log.info("Creating index {} on {}({})...", indexName, tableName, columnName);
                jdbcTemplate.execute(String.format("CREATE INDEX %s ON %s(%s)", indexName, tableName, columnName));
                log.info("Index {} created successfully.", indexName);
            }
        } catch (Exception e) {
            log.error("Failed to create index " + indexName, e);
        }
    }

    private void addFullTextIndexIfNotExists(String tableName, String indexName, String columnName) {
        try {
            Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.statistics " +
                "WHERE table_schema = DATABASE() " +
                "AND table_name = ? AND index_name = ?",
                Integer.class, tableName, indexName
            );

            if (count == null || count == 0) {
                log.info("Creating FULLTEXT index {} on {}({})...", indexName, tableName, columnName);
                // 使用 ngram parser 支持中文分词（虽然 tag 主要是英文，但为了统一性）
                jdbcTemplate.execute(String.format("CREATE FULLTEXT INDEX %s ON %s(%s) WITH PARSER ngram", indexName, tableName, columnName));
                log.info("FULLTEXT Index {} created successfully.", indexName);
            }
        } catch (Exception e) {
            log.error("Failed to create FULLTEXT index " + indexName, e);
        }
    }
}
