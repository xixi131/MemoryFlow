package com.memoryflow.service;

import com.memoryflow.dto.dashboard.DashboardSummaryDTO;
import com.memoryflow.entity.User;
import com.memoryflow.mapper.PointMapper;
import com.memoryflow.mapper.ReviewLogMapper;
import com.memoryflow.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;

@Slf4j
@Service
@RequiredArgsConstructor
public class DashboardService {

    private final PointMapper pointMapper;
    private final ReviewLogMapper reviewLogMapper;
    private final UserMapper userMapper;

    public DashboardSummaryDTO getDashboardSummary(Long userId) {
        LocalDate today = LocalDate.now();

        // Get user info for greeting
        User user = userMapper.selectById(userId);
        String nickname = (user != null) ? user.getDisplayName() : "同学";
        String greeting = "你好，" + nickname;

        int pendingCount = pointMapper.countPendingReviewsByUserId(userId, today);
        int completedCount;
        try {
            completedCount = reviewLogMapper.countTotalCompletedByUserId(userId);
        } catch (Exception e) {
            completedCount = pointMapper.countCumulativeReviewedPointsByUserId(userId);
        }

        return DashboardSummaryDTO.builder()
                .greeting(greeting)
                .pendingReviewCount(pendingCount)
                .completedReviewCount(completedCount)
                .build();
    }
}
