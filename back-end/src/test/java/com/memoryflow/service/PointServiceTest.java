package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.memoryflow.config.EbbinghausConfig;
import com.memoryflow.dto.point.CreatePointRequest;
import com.memoryflow.dto.point.PointDTO;
import com.memoryflow.entity.Chapter;
import com.memoryflow.entity.Point;
import com.memoryflow.entity.Subject;
import com.memoryflow.mapper.ChapterMapper;
import com.memoryflow.mapper.GoalMapper;
import com.memoryflow.mapper.PointMapper;
import com.memoryflow.mapper.ReviewLogMapper;
import com.memoryflow.mapper.SubjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PointServiceTest {

    @Mock private PointMapper pointMapper;
    @Mock private ChapterMapper chapterMapper;
    @Mock private SubjectMapper subjectMapper;
    @Mock private GoalMapper goalMapper;
    @Mock private SubjectService subjectService;
    @Mock private UserSettingsService userSettingsService;
    @Mock private EbbinghausConfig ebbinghausConfig;
    @Mock private ReviewLogMapper reviewLogMapper;

    @InjectMocks private PointService pointService;

    @Test
    void creatingPointStartsAsPendingIndependentReviewBlock() {
        Chapter chapter = Chapter.builder().id(10L).subjectId(20L).userId(30L).title("第一周").build();
        Subject subject = Subject.builder().id(20L).userId(30L).goalId(40L).title("数据结构与算法").build();
        CreatePointRequest request = new CreatePointRequest();
        request.setChapterId(10L);
        request.setTitle("哈希");

        when(chapterMapper.selectById(10L)).thenReturn(chapter);
        when(subjectMapper.selectById(20L)).thenReturn(subject);
        when(pointMapper.selectCount(any(Wrapper.class))).thenReturn(0L);
        when(pointMapper.insert(any(Point.class))).thenAnswer(invocation -> {
            invocation.<Point>getArgument(0).setId(50L);
            return 1;
        });

        PointDTO result = pointService.createPoint(request, 30L);

        ArgumentCaptor<Point> pointCaptor = ArgumentCaptor.forClass(Point.class);
        verify(pointMapper).insert(pointCaptor.capture());
        Point saved = pointCaptor.getValue();
        assertThat(saved.getIsLearned()).isFalse();
        assertThat(saved.getLearnedAt()).isNull();
        assertThat(saved.getCurrentReviewStage()).isZero();
        assertThat(saved.getNextReviewDate()).isNull();
        assertThat(result.getIsLearned()).isFalse();
        assertThat(result.getNextReviewDate()).isNull();
    }

    @Test
    void pendingReviewsKeepSameTitlePointsIndependent() {
        Point first = reviewPoint(1L, 11L, "数组");
        Point second = reviewPoint(2L, 12L, "数组");
        when(pointMapper.findPendingReviewsByUserId(30L, LocalDate.now())).thenReturn(List.of(first, second));
        when(chapterMapper.selectById(anyLong())).thenReturn(null);
        when(subjectMapper.selectById(anyLong())).thenReturn(null);

        List<PointDTO> result = pointService.getPendingReviews(30L);

        assertThat(result).extracting(PointDTO::getId).containsExactly(1L, 2L);
    }

    private Point reviewPoint(Long id, Long chapterId, String title) {
        return Point.builder()
                .id(id)
                .chapterId(chapterId)
                .subjectId(20L)
                .userId(30L)
                .title(title)
                .status(Point.PointStatus.in_progress)
                .isLearned(true)
                .currentReviewStage(1)
                .nextReviewDate(LocalDate.now())
                .reviewCompleted(false)
                .build();
    }
}
