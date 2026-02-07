package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.goal.CreateGoalRequest;
import com.memoryflow.dto.goal.GoalDTO;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.GoalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/goals")
@RequiredArgsConstructor
public class GoalController {

    private final GoalService goalService;
    private final SecurityUtils securityUtils;

    /**
     * 获取所有目标
     */
    @GetMapping
    public ApiResponse<List<GoalDTO>> getAllGoals() {
        Long userId = securityUtils.getCurrentUserId();
        List<GoalDTO> goals = goalService.getUserGoals(userId);
        return ApiResponse.success(goals);
    }

    /**
     * 获取活跃目标
     */
    @GetMapping("/active")
    public ApiResponse<List<GoalDTO>> getActiveGoals() {
        Long userId = securityUtils.getCurrentUserId();
        List<GoalDTO> goals = goalService.getActiveGoals(userId);
        return ApiResponse.success(goals);
    }

    /**
     * 获取单个目标详情
     */
    @GetMapping("/{id}")
    public ApiResponse<GoalDTO> getGoalById(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        GoalDTO goal = goalService.getGoalById(id, userId);
        return ApiResponse.success(goal);
    }

    /**
     * 创建目标
     */
    @PostMapping
    public ApiResponse<GoalDTO> createGoal(@Valid @RequestBody CreateGoalRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        GoalDTO goal = goalService.createGoal(request, userId);
        return ApiResponse.success(goal);
    }

    /**
     * 更新目标
     */
    @PutMapping("/{id}")
    public ApiResponse<GoalDTO> updateGoal(
            @PathVariable Long id,
            @Valid @RequestBody CreateGoalRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        GoalDTO goal = goalService.updateGoal(id, request, userId);
        return ApiResponse.success(goal);
    }

    /**
     * 删除目标
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteGoal(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        goalService.deleteGoal(id, userId);
        return ApiResponse.success();
    }
}
