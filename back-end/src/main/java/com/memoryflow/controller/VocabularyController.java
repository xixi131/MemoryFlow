package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.vocabulary.*;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.VocabularyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/vocabulary")
@RequiredArgsConstructor
public class VocabularyController {

    private final VocabularyService vocabularyService;
    private final SecurityUtils securityUtils;

    /**
     * 获取所有可用课程
     */
    @GetMapping("/courses")
    public ApiResponse<List<CourseDTO>> getAllCourses() {
        Long userId = securityUtils.getCurrentUserId();
        List<CourseDTO> courses = vocabularyService.getAllCourses(userId);
        return ApiResponse.success(courses);
    }

    /**
     * 获取用户已选课程
     */
    @GetMapping("/courses/my")
    public ApiResponse<List<CourseDTO>> getUserCourses() {
        Long userId = securityUtils.getCurrentUserId();
        List<CourseDTO> courses = vocabularyService.getUserCourses(userId);
        return ApiResponse.success(courses);
    }

    /**
     * 选择课程/词书
     */
    @PostMapping("/courses/select")
    public ApiResponse<CourseDTO> selectCourse(@Valid @RequestBody SelectCourseRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        CourseDTO course = vocabularyService.selectCourse(userId, request);
        return ApiResponse.success(course);
    }

    /**
     * 获取学习会话（智能组合待复习单词和今日新词）
     *
     * @param courseId 课程ID（可选，若不传则可能使用默认或所有）
     * @return 包含单词列表和统计信息的会话对象
     */
    @GetMapping("/session")
    public ApiResponse<StudySessionDTO> getStudySession(
            @RequestParam(required = false) Long courseId) {
        Long userId = securityUtils.getCurrentUserId();
        StudySessionDTO session = vocabularyService.getStudySession(userId, courseId);
        return ApiResponse.success(session);
    }

    /**
     * 获取今日学习单词
     */
    @GetMapping("/words/today")
    public ApiResponse<List<WordDTO>> getTodayLearningWords(
            @RequestParam Long courseId,
            @RequestParam(defaultValue = "20") int limit) {
        Long userId = securityUtils.getCurrentUserId();
        List<WordDTO> words = vocabularyService.getTodayLearningWords(userId, courseId, limit);
        return ApiResponse.success(words);
    }

    /**
     * 获取待复习单词
     */
    @GetMapping("/words/review")
    public ApiResponse<List<WordDTO>> getPendingReviewWords(
            @RequestParam(required = false) Long courseId) {
        Long userId = securityUtils.getCurrentUserId();
        List<WordDTO> words = vocabularyService.getPendingReviewWords(userId, courseId);
        return ApiResponse.success(words);
    }

    /**
     * 学习单词
     */
    @PostMapping("/words/learn")
    public ApiResponse<WordDTO> learnWord(@Valid @RequestBody LearnWordRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        WordDTO word = vocabularyService.learnWord(userId, request);
        return ApiResponse.success(word);
    }

    /**
     * 复习单词
     */
    @PostMapping("/words/review")
    public ApiResponse<WordDTO> reviewWord(@Valid @RequestBody ReviewWordRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        WordDTO word = vocabularyService.reviewWord(userId, request);
        return ApiResponse.success(word);
    }

    /**
     * 获取单词详情
     */
    @GetMapping("/words/{wordId}")
    public ApiResponse<WordDTO> getWordDetail(@PathVariable Long wordId) {
        Long userId = securityUtils.getCurrentUserId();
        WordDTO word = vocabularyService.getWordDetail(userId, wordId);
        return ApiResponse.success(word);
    }

    /**
     * 搜索单词
     */
    @GetMapping("/words/search")
    public ApiResponse<List<WordDTO>> searchWords(
            @RequestParam String keyword,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Long userId = securityUtils.getCurrentUserId();
        List<WordDTO> words = vocabularyService.searchWords(userId, keyword, page, size);
        return ApiResponse.success(words);
    }

    /**
     * 获取指定日期的已学单词
     */
    @GetMapping("/words/history")
    public ApiResponse<List<WordDTO>> getLearnedHistory(
            @RequestParam String date) {
        Long userId = securityUtils.getCurrentUserId();
        List<WordDTO> words = vocabularyService.getLearnedWordsByDate(userId, date);
        return ApiResponse.success(words);
    }

    /**
     * 获取学习统计
     */
    @GetMapping("/stats")
    public ApiResponse<VocabularyStatsDTO> getStats() {
        Long userId = securityUtils.getCurrentUserId();
        VocabularyStatsDTO stats = vocabularyService.getStats(userId);
        return ApiResponse.success(stats);
    }
}
