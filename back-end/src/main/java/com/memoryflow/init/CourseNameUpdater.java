package com.memoryflow.init;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * 更新课程名称为英文
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class CourseNameUpdater implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) throws Exception {
        log.info("Checking and localizing course names to English...");
        
        updateCourseName("IELTS", "IELTS Core Vocabulary");
        updateCourseName("TOEFL", "TOEFL iBT Vocabulary");
        updateCourseName("GRE", "GRE High-Frequency Vocabulary");
        updateCourseName("CET4", "CET-4 Vocabulary");
        updateCourseName("CET6", "CET-6 Vocabulary");
        updateCourseName("KAOYAN", "Postgraduate English Vocabulary");

        log.info("Course name localization completed.");
    }

    private void updateCourseName(String code, String englishName) {
        try {
            int updated = jdbcTemplate.update(
                "UPDATE english_courses SET name = ? WHERE code = ? AND name != ?",
                englishName, code, englishName
            );
            if (updated > 0) {
                log.info("Updated course {} name to: {}", code, englishName);
            }
        } catch (Exception e) {
            log.error("Failed to update course name for " + code, e);
        }
    }
}
