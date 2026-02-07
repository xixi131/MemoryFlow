package com.memoryflow.config;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.entity.CourseWord;
import com.memoryflow.entity.EnglishCourse;
import com.memoryflow.entity.EnglishWord;
import com.memoryflow.mapper.CourseWordMapper;
import com.memoryflow.mapper.EnglishCourseMapper;
import com.memoryflow.mapper.EnglishWordMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Component
@Order(2)
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final EnglishWordMapper wordMapper;
    private final EnglishCourseMapper courseMapper;
    private final CourseWordMapper courseWordMapper;

    @Override
    // @Transactional // Removed to avoid long-running transaction rollback issues
    public void run(String... args) throws Exception {
        // initializeWords(); // No longer needed as we import full dictionary from EcdictDataLoader
        initializeCourseWords();
    }

    private void initializeCourseWords() {
        log.info("Checking course words mapping...");

        List<EnglishCourse> courses = courseMapper.selectList(null);
        if (courses.isEmpty()) {
            log.warn("No courses available.");
            return;
        }

        // Link words to courses based on tags
        for (EnglishCourse course : courses) {
            // Check if course already has words
            Long count = courseWordMapper.selectCount(new LambdaQueryWrapper<CourseWord>()
                    .eq(CourseWord::getCourseId, course.getId()));
            
            if (count > 0) {
                continue; // Skip if already populated
            }

            String courseCode = course.getCode(); // e.g., CET4, IELTS
            if (courseCode == null) continue;

            log.info("Initializing words for course: {} (Tag: {})", course.getName(), courseCode);
            
            // Find words with matching tag
            // tag column format is space separated, e.g. "zk gk cet4"
            // We use LIKE %code% to match
            List<EnglishWord> words = wordMapper.selectList(new LambdaQueryWrapper<EnglishWord>()
                    .like(EnglishWord::getTag, courseCode.toLowerCase())
                    // Limit to avoid excessive memory usage during startup, 
                    // though for production complete mapping is desired.
                    // Given the clean dataset, 10000 is a safe upper bound for most categories.
                    .last("LIMIT 10000")); 
            
            if (words.isEmpty()) {
                log.warn("No words found for tag: {}", courseCode);
                continue;
            }

            int sortOrder = 1;
            for (EnglishWord word : words) {
                CourseWord courseWord = CourseWord.builder()
                        .courseId(course.getId())
                        .wordId(word.getId())
                        .sortOrder(sortOrder++)
                        .build();
                try {
                    courseWordMapper.insert(courseWord);
                } catch (Exception e) {
                    // ignore duplicates
                }
            }
            
            // Update course word count
            course.setWordCount(words.size());
            courseMapper.updateById(course);
            log.info("Linked {} words to course {}", words.size(), course.getName());
        }
    }
}
