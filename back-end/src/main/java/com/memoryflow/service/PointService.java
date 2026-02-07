package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.config.EbbinghausConfig;
import com.memoryflow.dto.point.CreatePointRequest;
import com.memoryflow.dto.point.PointDTO;
import com.memoryflow.dto.point.UpdatePointRequest;
import com.memoryflow.entity.Chapter;
import com.memoryflow.entity.Goal;
import com.memoryflow.entity.Point;
import com.memoryflow.entity.Subject;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.mapper.ChapterMapper;
import com.memoryflow.mapper.GoalMapper;
import com.memoryflow.mapper.PointMapper;
import com.memoryflow.mapper.SubjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class PointService {

    private final PointMapper pointMapper;
    private final ChapterMapper chapterMapper;
    private final SubjectMapper subjectMapper;
    private final GoalMapper goalMapper;
    private final SubjectService subjectService;
    private final UserSettingsService userSettingsService;
    private final EbbinghausConfig ebbinghausConfig;

    /**
     * 获取要点详情
     */
    public PointDTO getPointById(Long pointId, Long userId) {
        Point point = pointMapper.selectById(pointId);
        if (point == null) {
            throw new BusinessException(ErrorCode.POINT_NOT_FOUND);
        }

        if (!point.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.POINT_ACCESS_DENIED);
        }

        return convertToDTO(point);
    }

    /**
     * 创建要点
     */
    @Transactional
    public PointDTO createPoint(CreatePointRequest request, Long userId) {
        Chapter chapter = chapterMapper.selectById(request.getChapterId());
        if (chapter == null) {
            throw new BusinessException(ErrorCode.CHAPTER_NOT_FOUND);
        }

        Subject subject = subjectMapper.selectById(chapter.getSubjectId());
        if (subject == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND);
        }

        if (!subject.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
        }

        Long pointCount = pointMapper.selectCount(new LambdaQueryWrapper<Point>()
                .eq(Point::getSubjectId, subject.getId()));

        Point point = Point.builder()
                .chapterId(chapter.getId())
                .subjectId(subject.getId())
                .userId(userId)
                .title(request.getTitle())
                .content(request.getContent())
                .status(Point.PointStatus.pending)
                .isLearned(false)
                .currentReviewStage(0)
                .reviewCompleted(false)
                .sortOrder(pointCount.intValue())
                .build();

        pointMapper.insert(point);

        // 更新科目进度
        subjectService.updateSubjectProgress(subject.getId());
        userSettingsService.updateSyncTime(userId);

        return convertToDTO(point);
    }

    /**
     * 更新要点
     */
    @Transactional
    public PointDTO updatePoint(Long pointId, UpdatePointRequest request, Long userId) {
        Point point = pointMapper.selectById(pointId);
        if (point == null) {
            throw new BusinessException(ErrorCode.POINT_NOT_FOUND);
        }

        if (!point.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.POINT_ACCESS_DENIED);
        }

        if (request.getTitle() != null) {
            point.setTitle(request.getTitle());
        }
        if (request.getContent() != null) {
            point.setContent(request.getContent());
        }

        pointMapper.updateById(point);
        userSettingsService.updateSyncTime(userId);
        return convertToDTO(point);
    }

    /**
     * 删除要点
     */
    @Transactional
    public void deletePoint(Long pointId, Long userId) {
        Point point = pointMapper.selectById(pointId);
        if (point == null) {
            throw new BusinessException(ErrorCode.POINT_NOT_FOUND);
        }

        if (!point.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.POINT_ACCESS_DENIED);
        }

        Long subjectId = point.getSubjectId();
        pointMapper.deleteById(pointId);

        // 更新科目进度
        subjectService.updateSubjectProgress(subjectId);
        userSettingsService.updateSyncTime(userId);
    }

    /**
     * 标记要点为已学习（触发艾宾浩斯复习计划）
     */
    @Transactional
    public PointDTO markAsLearned(Long pointId, Long userId) {
        Point point = pointMapper.selectById(pointId);
        if (point == null) {
            throw new BusinessException(ErrorCode.POINT_NOT_FOUND);
        }

        if (!point.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.POINT_ACCESS_DENIED);
        }

        // 使用充血模型方法
        point.markAsLearned(ebbinghausConfig);
        pointMapper.updateById(point);

        // 更新科目进度
        subjectService.updateSubjectProgress(point.getSubjectId());
        userSettingsService.updateSyncTime(userId);

        log.info("Point {} marked as learned, next review date: {}", pointId, point.getNextReviewDate());

        return convertToDTO(point);
    }

    /**
     * 取消已学习状态
     */
    @Transactional
    public PointDTO unmarkAsLearned(Long pointId, Long userId) {
        Point point = pointMapper.selectById(pointId);
        if (point == null) {
            throw new BusinessException(ErrorCode.POINT_NOT_FOUND);
        }

        if (!point.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.POINT_ACCESS_DENIED);
        }

        point.unmarkAsLearned();
        pointMapper.updateById(point);

        // 更新科目进度
        subjectService.updateSubjectProgress(point.getSubjectId());
        userSettingsService.updateSyncTime(userId);

        return convertToDTO(point);
    }

    /**
     * 完成复习（进入下一个复习阶段）
     */
    @Transactional
    public PointDTO completeReview(Long pointId, Long userId) {
        Point point = pointMapper.selectById(pointId);
        if (point == null) {
            throw new BusinessException(ErrorCode.POINT_NOT_FOUND);
        }

        if (!point.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.POINT_ACCESS_DENIED);
        }

        if (!point.getIsLearned()) {
            throw new BusinessException(ErrorCode.REVIEW_NOT_READY);
        }

        if (point.getReviewCompleted()) {
            throw new BusinessException(ErrorCode.REVIEW_ALREADY_COMPLETED);
        }

        // 使用充血模型方法完成复习
        point.completeReview(ebbinghausConfig);
        pointMapper.updateById(point);

        log.info("Point {} review completed, stage: {}, next review: {}",
                pointId, point.getCurrentReviewStage(), point.getNextReviewDate());

        // 更新科目进度
        subjectService.updateSubjectProgress(point.getSubjectId());
        userSettingsService.updateSyncTime(userId);

        return convertToDTO(point);
    }

    /**
     * 撤销复习（回退复习进度）
     */
    @Transactional
    public PointDTO revertReview(Long pointId, Long userId) {
        Point point = pointMapper.selectById(pointId);
        if (point == null) {
            throw new BusinessException(ErrorCode.POINT_NOT_FOUND);
        }

        if (!point.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.POINT_ACCESS_DENIED);
        }

        if (!point.getIsLearned()) {
            throw new BusinessException(ErrorCode.REVIEW_NOT_READY);
        }

        // 使用充血模型方法撤销复习
        point.revertReview();
        pointMapper.updateById(point);

        log.info("Point {} review reverted, stage: {}, next review: {}",
                pointId, point.getCurrentReviewStage(), point.getNextReviewDate());

        // 更新科目进度
        subjectService.updateSubjectProgress(point.getSubjectId());
        userSettingsService.updateSyncTime(userId);

        return convertToDTO(point);
    }

    /**
     * 获取用户所有待复习的要点（去重：同一章节下相同标题的要点只显示一个，取下次复习时间最早的）
     */
    public List<PointDTO> getPendingReviews(Long userId) {
        List<Point> points = pointMapper.findPendingReviewsByUserId(userId, LocalDate.now());
        
        // 去重逻辑：Map Key = title
        return points.stream()
                .collect(Collectors.toMap(
                        Point::getTitle,
                        p -> p,
                        (existing, replacement) -> existing.getNextReviewDate().isBefore(replacement.getNextReviewDate()) ? existing : replacement
                ))
                .values().stream()
                .sorted((p1, p2) -> p1.getNextReviewDate().compareTo(p2.getNextReviewDate()))
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    /**
     * 获取今日待复习的要点
     */
    public List<PointDTO> getTodayReviews(Long userId) {
        List<Point> points = pointMapper.findTodayReviewsByUserId(userId, LocalDate.now());
        return points.stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    /**
     * 获取逾期的要点
     */
    public List<PointDTO> getOverdueReviews(Long userId) {
        List<Point> points = pointMapper.findOverdueReviewsByUserId(userId, LocalDate.now());
        return points.stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    /**
     * 统计待复习数量
     */
    public int countPendingReviews(Long userId) {
        return pointMapper.countPendingReviewsByUserId(userId, LocalDate.now());
    }

    private PointDTO convertToDTO(Point point) {
        PointDTO dto = PointDTO.builder()
                .id(point.getId())
                .chapterId(point.getChapterId())
                .subjectId(point.getSubjectId())
                .title(point.getTitle())
                .content(point.getContent())
                .status(point.getStatus().getValue())
                .isLearned(point.getIsLearned())
                .learnedAt(point.getLearnedAt() != null ? point.getLearnedAt().toString() : null)
                .currentReviewStage(point.getCurrentReviewStage())
                .nextReviewDate(point.getNextReviewDate())
                .lastReviewAt(point.getLastReviewAt() != null ? point.getLastReviewAt().toString() : null)
                .reviewCompleted(point.getReviewCompleted())
                .needsReview(point.needsReview())
                .overdueDays(point.getOverdueDays())
                .reviewProgressDescription(point.getReviewProgressDescription())
                .build();

        // 加载关联信息
        Chapter chapter = chapterMapper.selectById(point.getChapterId());
        if (chapter != null) {
            dto.setChapterTitle(chapter.getTitle());
        }

        Subject subject = subjectMapper.selectById(point.getSubjectId());
        if (subject != null) {
            dto.setSubjectTitle(subject.getTitle());
            Goal goal = goalMapper.selectById(subject.getGoalId());
            if (goal != null) {
                dto.setGoalTitle(goal.getTitle());
            }
        }

        return dto;
    }
}
