package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.memoryflow.config.EbbinghausConfig;
import com.memoryflow.dto.subject.SubjectDTO;
import com.memoryflow.entity.Article;
import com.memoryflow.entity.Chapter;
import com.memoryflow.entity.Point;
import com.memoryflow.entity.Subject;
import com.memoryflow.mapper.ArticleMapper;
import com.memoryflow.mapper.ChapterMapper;
import com.memoryflow.mapper.GoalMapper;
import com.memoryflow.mapper.PointMapper;
import com.memoryflow.mapper.SubjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SubjectServiceTest {

    @Mock private SubjectMapper subjectMapper;
    @Mock private ChapterMapper chapterMapper;
    @Mock private PointMapper pointMapper;
    @Mock private ArticleMapper articleMapper;
    @Mock private GoalMapper goalMapper;
    @Mock private EbbinghausConfig ebbinghausConfig;
    @Mock private GoalService goalService;

    @InjectMocks private SubjectService subjectService;

    @Test
    void appendingTagCreatesPendingReviewBlock() {
        Subject subject = Subject.builder()
                .id(20L)
                .goalId(40L)
                .userId(30L)
                .title("数据结构与算法")
                .build();
        Chapter chapter = Chapter.builder()
                .id(10L)
                .subjectId(20L)
                .userId(30L)
                .title("第一周")
                .build();
        AtomicReference<Point> savedPoint = new AtomicReference<>();
        AtomicReference<Article> savedArticle = new AtomicReference<>();

        when(subjectMapper.selectById(20L)).thenReturn(subject);
        when(chapterMapper.selectById(10L)).thenReturn(chapter);
        when(chapterMapper.selectList(any(Wrapper.class))).thenReturn(List.of(chapter));
        when(pointMapper.selectCount(any(Wrapper.class))).thenReturn(0L);
        when(pointMapper.countLearnedBySubjectId(20L)).thenReturn(1);
        when(pointMapper.insert(any(Point.class))).thenAnswer(invocation -> {
            Point point = invocation.getArgument(0);
            point.setId(50L);
            savedPoint.set(point);
            return 1;
        });
        when(pointMapper.selectList(any(Wrapper.class))).thenAnswer(invocation ->
                savedPoint.get() == null ? List.of() : List.of(savedPoint.get()));
        when(pointMapper.selectOne(any(Wrapper.class))).thenAnswer(invocation -> savedPoint.get());
        when(articleMapper.insert(any(Article.class))).thenAnswer(invocation -> {
            Article article = invocation.getArgument(0);
            article.setId(60L);
            savedArticle.set(article);
            return 1;
        });
        when(articleMapper.selectList(any(Wrapper.class))).thenAnswer(invocation ->
                savedArticle.get() == null ? List.of() : List.of(savedArticle.get()));

        SubjectDTO result = subjectService.appendDsl(
                20L,
                "@ 第一周\n{title: \"矩阵\", content: \"矩阵学习笔记\"}",
                30L,
                10L
        );

        Point point = savedPoint.get();
        assertThat(point).isNotNull();
        assertThat(point.getIsLearned()).isFalse();
        assertThat(point.getSourceArticleId()).isEqualTo(60L);
        assertThat(point.getCurrentReviewStage()).isZero();
        assertThat(point.getNextReviewDate()).isNull();
        assertThat(result.getChapters().get(0).getChildren()).isEmpty();
        assertThat(result.getChapters().get(0).getContents().get(0).getReviewPointId()).isEqualTo(50L);
        assertThat(result.getChapters().get(0).getContents().get(0).getIsLearned()).isFalse();

        SubjectDTO lazyResult = subjectService.getSubjectDetailLazy(20L, 30L);
        assertThat(lazyResult.getChapters().get(0).getChildren().get(0).getSourceArticleId()).isEqualTo(60L);
        assertThat(lazyResult.getChapters().get(0).getChildren().get(0).getIsLearned()).isFalse();
    }
}
