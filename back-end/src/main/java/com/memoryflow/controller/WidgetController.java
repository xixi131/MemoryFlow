package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.widget.WidgetSummaryDTO;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.WidgetService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/widget")
@RequiredArgsConstructor
public class WidgetController {

    private final WidgetService widgetService;
    private final SecurityUtils securityUtils;

    /**
     * 获取桌面小组件摘要数据
     * 这个接口用于桌面小组件轮询获取数据
     */
    @GetMapping("/summary")
    public ApiResponse<WidgetSummaryDTO> getWidgetSummary(
            @RequestHeader(value = "Authorization", required = false) String authorization) {

        Long userId = securityUtils.getCurrentUserId();
        if (userId == null) {
            // 未登录状态，返回401错误，触发前端重新登录
            return ApiResponse.error(401, "未登录");
        }

        WidgetSummaryDTO summary = widgetService.getWidgetSummary(userId);
        return ApiResponse.success(summary);
    }
}
