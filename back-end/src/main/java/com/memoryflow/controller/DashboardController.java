package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.dashboard.DashboardSummaryDTO;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.DashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;
    private final SecurityUtils securityUtils;

    @GetMapping("/summary")
    public ApiResponse<DashboardSummaryDTO> getDashboardSummary() {
        Long userId = securityUtils.getCurrentUserId();
        DashboardSummaryDTO summary = dashboardService.getDashboardSummary(userId);
        return ApiResponse.success(summary);
    }
}
