package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.dto.goal.CreateGoalRequest;
import com.memoryflow.dto.goal.GoalDTO;
import com.memoryflow.entity.Goal;
import com.memoryflow.entity.GoalTheme;
import com.memoryflow.entity.Subject;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.mapper.GoalMapper;
import com.memoryflow.mapper.GoalThemeMapper;
import com.memoryflow.mapper.SubjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Random;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class GoalService {

    private final GoalMapper goalMapper;
    private final SubjectMapper subjectMapper;
    private final GoalThemeMapper goalThemeMapper;

    private final Random random = new Random();

    /**
     * 获取用户所有目标
     */
    public List<GoalDTO> getUserGoals(Long userId) {
        List<Goal> goals = goalMapper.selectList(new LambdaQueryWrapper<Goal>()
                .eq(Goal::getUserId, userId)
                .orderByAsc(Goal::getSortOrder));

        return goals.stream()
                .map(goal -> {
                    GoalDTO dto = GoalDTO.fromEntity(goal);
                    // 加载科目摘要
                    List<Subject> subjects = subjectMapper.selectList(new LambdaQueryWrapper<Subject>()
                            .eq(Subject::getGoalId, goal.getId())
                            .orderByAsc(Subject::getSortOrder));

                    dto.setSubjects(subjects.stream()
                            .map(s -> GoalDTO.SubjectSummary.builder()
                                    .id(s.getId())
                                    .title(s.getTitle())
                                    .progress(s.getProgress())
                                    .icon(s.getIcon())
                                    .colorClass(s.getColorClass())
                                    .build())
                            .collect(Collectors.toList()));
                    return dto;
                })
                .collect(Collectors.toList());
    }

    /**
     * 获取活跃目标
     */
    public List<GoalDTO> getActiveGoals(Long userId) {
        List<Goal> goals = goalMapper.selectList(new LambdaQueryWrapper<Goal>()
                .eq(Goal::getUserId, userId)
                .eq(Goal::getStatus, Goal.GoalStatus.active)
                .orderByAsc(Goal::getSortOrder));

        return goals.stream()
                .map(GoalDTO::fromEntity)
                .collect(Collectors.toList());
    }

    /**
     * 获取单个目标详情
     */
    public GoalDTO getGoalById(Long goalId, Long userId) {
        Goal goal = goalMapper.selectById(goalId);
        if (goal == null) {
            throw new BusinessException(ErrorCode.GOAL_NOT_FOUND);
        }

        if (!goal.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.GOAL_ACCESS_DENIED);
        }

        GoalDTO dto = GoalDTO.fromEntity(goal);

        // 加载科目
        List<Subject> subjects = subjectMapper.selectList(new LambdaQueryWrapper<Subject>()
                .eq(Subject::getGoalId, goalId)
                .orderByAsc(Subject::getSortOrder));

        dto.setSubjects(subjects.stream()
                .map(s -> GoalDTO.SubjectSummary.builder()
                        .id(s.getId())
                        .title(s.getTitle())
                        .progress(s.getProgress())
                        .icon(s.getIcon())
                        .colorClass(s.getColorClass())
                        .build())
                .collect(Collectors.toList()));

        return dto;
    }

    /**
     * 创建目标
     */
    @Transactional
    public GoalDTO createGoal(CreateGoalRequest request, Long userId) {
        // 随机选择一个主题
        List<GoalTheme> themes = goalThemeMapper.selectList(new LambdaQueryWrapper<GoalTheme>()
                .orderByAsc(GoalTheme::getSortOrder));
        GoalTheme theme = themes.isEmpty() ? null : themes.get(random.nextInt(themes.size()));

        Long count = goalMapper.selectCount(new LambdaQueryWrapper<Goal>()
                .eq(Goal::getUserId, userId));

        Goal goal = Goal.builder()
                .userId(userId)
                .title(request.getTitle())
                .labelType(parseLabel(request.getLabelType()))
                .progress(0)
                .status(Goal.GoalStatus.active)
                .sortOrder(count.intValue())
                .build();

        // 应用主题
        if (theme != null) {
            goal.applyTheme(theme);
        }

        // 设置截止日期
        if (request.getDueDate() != null && !request.getDueDate().isBlank()) {
            goal.setDueDate(LocalDate.parse(request.getDueDate()));
        } else {
            // 默认一个月后
            goal.setDueDate(LocalDate.now().plusMonths(1));
        }

        goalMapper.insert(goal);
        return GoalDTO.fromEntity(goal);
    }

    /**
     * 更新目标
     */
    @Transactional
    public GoalDTO updateGoal(Long goalId, CreateGoalRequest request, Long userId) {
        Goal goal = goalMapper.selectById(goalId);
        if (goal == null) {
            throw new BusinessException(ErrorCode.GOAL_NOT_FOUND);
        }

        if (!goal.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.GOAL_ACCESS_DENIED);
        }

        if (request.getTitle() != null) {
            goal.setTitle(request.getTitle());
        }
        if (request.getLabelType() != null) {
            goal.setLabelType(parseLabel(request.getLabelType()));
        }
        if (request.getDueDate() != null) {
            goal.setDueDate(LocalDate.parse(request.getDueDate()));
        }

        goalMapper.updateById(goal);
        return GoalDTO.fromEntity(goal);
    }

    /**
     * 删除目标
     */
    @Transactional
    public void deleteGoal(Long goalId, Long userId) {
        Goal goal = goalMapper.selectById(goalId);
        if (goal == null) {
            throw new BusinessException(ErrorCode.GOAL_NOT_FOUND);
        }

        if (!goal.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.GOAL_ACCESS_DENIED);
        }

        goalMapper.deleteById(goalId);
    }

    /**
     * 重新计算目标进度
     */
    @Transactional
    public void recalculateGoalProgress(Long goalId) {
        Goal goal = goalMapper.selectById(goalId);
        if (goal == null) {
            throw new BusinessException(ErrorCode.GOAL_NOT_FOUND);
        }

        List<Subject> subjects = subjectMapper.selectList(new LambdaQueryWrapper<Subject>()
                .eq(Subject::getGoalId, goalId)
                .orderByAsc(Subject::getSortOrder));

        goal.recalculateProgress(subjects);
        goalMapper.updateById(goal);
    }

    private Goal.LabelType parseLabel(String labelType) {
        if (labelType == null) {
            return Goal.LabelType.priority;
        }
        try {
            return Goal.LabelType.valueOf(labelType.toLowerCase());
        } catch (IllegalArgumentException e) {
            return Goal.LabelType.priority;
        }
    }
}
