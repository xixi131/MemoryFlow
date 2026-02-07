package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.dto.widget.WidgetSummaryDTO;
import com.memoryflow.entity.Subject;
import com.memoryflow.entity.UserSettings;
import com.memoryflow.mapper.PointMapper;
import com.memoryflow.mapper.SubjectMapper;
import com.memoryflow.mapper.UserSettingsMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class WidgetService {

    private final SubjectMapper subjectMapper;
    private final PointMapper pointMapper;
    private final UserSettingsMapper userSettingsMapper;

    /**
     * 获取桌面小组件摘要数据
     */
    public WidgetSummaryDTO getWidgetSummary(Long userId) {
        LocalDate today = LocalDate.now();

        // 获取用户设置
        UserSettings settings = userSettingsMapper.selectOne(new LambdaQueryWrapper<UserSettings>()
                .eq(UserSettings::getUserId, userId));
        String reminderTime = settings != null ? settings.getReminderTime() : "20:00";

        // 获取用户所有科目
        List<Subject> subjects = subjectMapper.selectList(new LambdaQueryWrapper<Subject>()
                .eq(Subject::getUserId, userId)
                .orderByAsc(Subject::getSortOrder));

        // 统计总待复习数
        int totalPending = pointMapper.countPendingReviewsByUserId(userId, today);

        // 构建科目灯状态列表
        List<WidgetSummaryDTO.SubjectLight> subjectLights = subjects.stream()
                .map(subject -> {
                    int pendingCount = pointMapper.countPendingReviewsBySubjectId(subject.getId(), today);
                    int overdueCount = pointMapper.countOverdueReviewsBySubjectId(subject.getId(), today);

                    // 计算灯状态
                    String lightStatus;
                    if (overdueCount > 0) {
                        lightStatus = "red";
                    } else if (pendingCount > 0) {
                        lightStatus = "yellow";
                    } else {
                        lightStatus = "green";
                    }

                    return WidgetSummaryDTO.SubjectLight.builder()
                            .id(subject.getId())
                            .title(subject.getTitle())
                            .icon(subject.getIcon())
                            .colorClass(subject.getColorClass())
                            .progress(subject.getProgress())
                            .pendingReviewCount(pendingCount)
                            .lightStatus(lightStatus)
                            .build();
                })
                .collect(Collectors.toList());

        return WidgetSummaryDTO.builder()
                .totalPendingReviews(totalPending)
                .totalCompletedToday(0) // 可以后续添加统计
                .reminderTime(reminderTime)
                .subjects(subjectLights)
                .build();
    }
}
