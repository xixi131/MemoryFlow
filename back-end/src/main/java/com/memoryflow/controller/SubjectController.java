package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.subject.CreateSubjectRequest;
import com.memoryflow.dto.subject.SubjectDTO;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.SubjectService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/subjects")
@RequiredArgsConstructor
public class SubjectController {

    private final SubjectService subjectService;
    private final SecurityUtils securityUtils;

    /**
     * 获取目标下的所有科目
     */
    @GetMapping("/goal/{goalId}")
    public ApiResponse<List<SubjectDTO>> getSubjectsByGoal(@PathVariable Long goalId) {
        Long userId = securityUtils.getCurrentUserId();
        List<SubjectDTO> subjects = subjectService.getSubjectsByGoalId(goalId, userId);
        return ApiResponse.success(subjects);
    }

    /**
     * 获取科目详情（含章节和要点）
     */
    @GetMapping("/{id}")
    public ApiResponse<SubjectDTO> getSubjectDetail(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        SubjectDTO subject = subjectService.getSubjectDetailLazy(id, userId);
        return ApiResponse.success(subject);
    }

    /**
     * 获取章节详情（含知识点和文章）
     */
    @GetMapping("/chapters/{id}")
    public ApiResponse<SubjectDTO.ChapterDTO> getChapterDetail(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        SubjectDTO.ChapterDTO chapter = subjectService.getChapterDetail(id, userId);
        return ApiResponse.success(chapter);
    }

    /**
     * 创建科目（支持DSL解析）
     */
    @PostMapping
    public ApiResponse<SubjectDTO> createSubject(@Valid @RequestBody CreateSubjectRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        SubjectDTO subject = subjectService.createSubject(request, userId);
        return ApiResponse.success(subject);
    }

    /**
     * 删除科目
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteSubject(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        subjectService.deleteSubject(id, userId);
        return ApiResponse.success();
    }

    /**
     * 追加内容（支持DSL解析）
     */
    @PostMapping("/{id}/append")
    public ApiResponse<SubjectDTO> appendContent(@PathVariable Long id, @RequestBody java.util.Map<String, String> payload) {
        Long userId = securityUtils.getCurrentUserId();
        String content = payload.get("content");
        Long chapterId = null;
        if (payload.containsKey("chapterId")) {
            String rawChapterId = payload.get("chapterId");
            if (rawChapterId != null && !rawChapterId.isBlank()) {
                chapterId = Long.valueOf(rawChapterId.trim());
            }
        }
        Long pointId = null;
        if (payload.containsKey("pointId")) {
            String rawPointId = payload.get("pointId");
            if (rawPointId != null && !rawPointId.isBlank()) {
                pointId = Long.valueOf(rawPointId.trim());
            }
        }
        SubjectDTO subject = subjectService.appendDsl(id, content, userId, chapterId, pointId);
        return ApiResponse.success(subject);
    }

    /**
     * 删除章节
     */
    @DeleteMapping("/chapters/{id}")
    public ApiResponse<Void> deleteChapter(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        subjectService.deleteChapter(id, userId);
        return ApiResponse.success();
    }

    /**
     * 删除要点
     */
    @DeleteMapping("/points/{id}")
    public ApiResponse<Void> deletePoint(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        subjectService.deletePoint(id, userId);
        return ApiResponse.success();
    }

    /**
     * 删除文章
     */
    @DeleteMapping("/articles/{id}")
    public ApiResponse<Void> deleteArticle(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        subjectService.deleteArticle(id, userId);
        return ApiResponse.success();
    }

    /**
     * 更新文章
     */
    @PutMapping("/articles/{id}")
    public ApiResponse<Void> updateArticle(@PathVariable Long id, @RequestBody java.util.Map<String, String> payload) {
        Long userId = securityUtils.getCurrentUserId();
        String title = payload.get("title");
        String content = payload.get("content");
        subjectService.updateArticle(id, title, content, userId);
        return ApiResponse.success();
    }

    /**
     * 标记章节为已学习（同时标记下属所有要点）
     */
    @PostMapping("/chapters/{id}/learn")
    public ApiResponse<Void> markChapterAsLearned(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        subjectService.markChapterAsLearned(id, userId);
        return ApiResponse.success();
    }

    /**
     * 取消章节已学习状态
     */
    @DeleteMapping("/chapters/{id}/learn")
    public ApiResponse<Void> unmarkChapterAsLearned(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        subjectService.unmarkChapterAsLearned(id, userId);
        return ApiResponse.success();
    }
}
