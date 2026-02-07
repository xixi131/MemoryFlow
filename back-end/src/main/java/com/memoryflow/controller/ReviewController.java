package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.point.PointDTO;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.PointService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/reviews")
@RequiredArgsConstructor
public class ReviewController {

    private final PointService pointService;
    private final SecurityUtils securityUtils;

    /**
     * 获取所有待复习的要点
     */
    @GetMapping("/pending")
    public ApiResponse<List<PointDTO>> getPendingReviews() {
        Long userId = securityUtils.getCurrentUserId();
        List<PointDTO> points = pointService.getPendingReviews(userId);
        return ApiResponse.success(points);
    }

    /**
     * 获取今日待复习的要点
     */
    @GetMapping("/today")
    public ApiResponse<List<PointDTO>> getTodayReviews() {
        Long userId = securityUtils.getCurrentUserId();
        List<PointDTO> points = pointService.getTodayReviews(userId);
        return ApiResponse.success(points);
    }

    /**
     * 获取逾期的要点
     */
    @GetMapping("/overdue")
    public ApiResponse<List<PointDTO>> getOverdueReviews() {
        Long userId = securityUtils.getCurrentUserId();
        List<PointDTO> points = pointService.getOverdueReviews(userId);
        return ApiResponse.success(points);
    }

    /**
     * 获取复习统计
     */
    @GetMapping("/stats")
    public ApiResponse<Map<String, Object>> getReviewStats() {
        Long userId = securityUtils.getCurrentUserId();

        int pendingCount = pointService.countPendingReviews(userId);
        List<PointDTO> overduePoints = pointService.getOverdueReviews(userId);
        List<PointDTO> todayPoints = pointService.getTodayReviews(userId);

        Map<String, Object> stats = new HashMap<>();
        stats.put("pendingCount", pendingCount);
        stats.put("overdueCount", overduePoints.size());
        stats.put("todayCount", todayPoints.size());

        return ApiResponse.success(stats);
    }
}
