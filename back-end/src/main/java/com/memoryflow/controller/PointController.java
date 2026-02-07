package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.point.CreatePointRequest;
import com.memoryflow.dto.point.PointDTO;
import com.memoryflow.dto.point.UpdatePointRequest;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.PointService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/points")
@RequiredArgsConstructor
public class PointController {

    private final PointService pointService;
    private final SecurityUtils securityUtils;

    /**
     * 获取要点详情
     */
    @GetMapping("/{id}")
    public ApiResponse<PointDTO> getPointById(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        PointDTO point = pointService.getPointById(id, userId);
        return ApiResponse.success(point);
    }

    /**
     * 创建要点
     */
    @PostMapping
    public ApiResponse<PointDTO> createPoint(@Valid @RequestBody CreatePointRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        PointDTO point = pointService.createPoint(request, userId);
        return ApiResponse.success(point);
    }

    /**
     * 更新要点
     */
    @PutMapping("/{id}")
    public ApiResponse<PointDTO> updatePoint(
            @PathVariable Long id,
            @RequestBody UpdatePointRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        PointDTO point = pointService.updatePoint(id, request, userId);
        return ApiResponse.success(point);
    }

    /**
     * 删除要点
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deletePoint(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        pointService.deletePoint(id, userId);
        return ApiResponse.success();
    }

    /**
     * 标记要点为已学习（触发艾宾浩斯复习计划）
     */
    @PostMapping("/{id}/learn")
    public ApiResponse<PointDTO> markAsLearned(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        PointDTO point = pointService.markAsLearned(id, userId);
        return ApiResponse.success(point);
    }

    /**
     * 取消已学习状态
     */
    @DeleteMapping("/{id}/learn")
    public ApiResponse<PointDTO> unmarkAsLearned(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        PointDTO point = pointService.unmarkAsLearned(id, userId);
        return ApiResponse.success(point);
    }

    /**
     * 完成复习（进入下一个复习阶段）
     */
    @PostMapping("/{id}/review")
    public ApiResponse<PointDTO> completeReview(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        PointDTO point = pointService.completeReview(id, userId);
        return ApiResponse.success(point);
    }

    /**
     * 撤销复习（回退到上一个复习阶段，并标记为今日待复习）
     */
    @PostMapping("/{id}/review/revert")
    public ApiResponse<PointDTO> revertReview(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        PointDTO point = pointService.revertReview(id, userId);
        return ApiResponse.success(point);
    }
}
