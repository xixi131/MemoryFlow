package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.config.EbbinghausConfig;
import com.memoryflow.dto.subject.CreateSubjectRequest;
import com.memoryflow.dto.subject.SubjectDTO;
import com.memoryflow.entity.Article;
import com.memoryflow.entity.Chapter;
import com.memoryflow.entity.Goal;
import com.memoryflow.entity.Point;
import com.memoryflow.entity.Subject;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.mapper.ArticleMapper;
import com.memoryflow.mapper.ChapterMapper;
import com.memoryflow.mapper.GoalMapper;
import com.memoryflow.mapper.PointMapper;
import com.memoryflow.mapper.SubjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class SubjectService {

    private final SubjectMapper subjectMapper;
    private final ChapterMapper chapterMapper;
    private final PointMapper pointMapper;
    private final ArticleMapper articleMapper;
    private final GoalMapper goalMapper;
    private final EbbinghausConfig ebbinghausConfig;

    @Lazy
    private final GoalService goalService;

    // DSL Parsing Regex
    private static final Pattern TITLE_PATTERN = Pattern.compile("title:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"", Pattern.DOTALL);
    private static final Pattern CONTENT_PATTERN = Pattern.compile("content:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"", Pattern.DOTALL);

    /**
     * Get all subjects under a goal
     */
    public List<SubjectDTO> getSubjectsByGoalId(Long goalId, Long userId) {
        Goal goal = goalMapper.selectById(goalId);
        if (goal == null) {
            throw new BusinessException(ErrorCode.GOAL_NOT_FOUND);
        }

        if (!goal.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.GOAL_ACCESS_DENIED);
        }

        List<Subject> subjects = subjectMapper.selectList(new LambdaQueryWrapper<Subject>()
                .eq(Subject::getGoalId, goalId)
                .orderByAsc(Subject::getSortOrder));
        return subjects.stream()
                .map(SubjectDTO::fromEntity)
                .collect(Collectors.toList());
    }

    /**
     * Lazy Load Subject Details (Only Level 1 Chapters, no content)
     */
    public SubjectDTO getSubjectDetailLazy(Long subjectId, Long userId) {
        Subject subject = subjectMapper.selectById(subjectId);
        if (subject == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND);
        }

        if (!subject.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
        }

        SubjectDTO dto = SubjectDTO.fromEntity(subject);

        // Load chapters (Level 1 only, no deep content)
        List<Chapter> chapters = chapterMapper.selectList(new LambdaQueryWrapper<Chapter>()
                .eq(Chapter::getSubjectId, subjectId)
                .orderByAsc(Chapter::getSortOrder));

        dto.setChapters(chapters.stream()
                .map(chapter -> {
                    // Fetch Level 2 Points (Simplified for Review Check)
                    // Note: Ideally we should use a lighter query or just count. 
                    // But to support "which points are pending" for the frontend to calculate, we need the list.
                    // Or we can just return the children points here since getSubjectDetail is for the Detail Page.
                    // Previous implementation was Lazy (List.of()), causing the "No Prompt" issue.
                    // Now we fetch points eagerly.
                    
                    List<Point> points = pointMapper.selectList(new LambdaQueryWrapper<Point>()
                            .eq(Point::getChapterId, chapter.getId())
                            .orderByAsc(Point::getSortOrder));

                    // We still keep contents empty to avoid loading heavy text, but points are metadata-heavy so it's fine.
                    
                    return SubjectDTO.ChapterDTO.builder()
                        .id(chapter.getId())
                        .title(chapter.getTitle())
                        .totalPoints(points.size())
                        .completedPoints((int) points.stream().filter(Point::getIsLearned).count())
                        .contents(null) // Keep articles lazy (null indicates not loaded)
                        .children(points.stream()
                                .map(p -> SubjectDTO.PointSummary.builder()
                                        .id(p.getId())
                                        .title(p.getTitle())
                                        .status(p.getStatus().getValue())
                                        .isLearned(p.getIsLearned())
                                        .needsReview(p.needsReview())
                                        .nextReviewDate(p.getNextReviewDate() != null ?
                                                p.getNextReviewDate().toString() : null)
                                        .lastReviewAt(p.getLastReviewAt() != null ?
                                                p.getLastReviewAt().toString() : null)
                                        .reviewCompleted(p.getReviewCompleted())
                                        .currentReviewStage(p.getCurrentReviewStage())
                                        .contents(null) // Keep point articles lazy (null indicates not loaded)
                                        .build())
                                .collect(Collectors.toList()))
                        .build();
                })
                .collect(Collectors.toList()));

        return dto;
    }

    /**
     * Get specific chapter details (Level 2 & 3: Articles & Points)
     */
    public SubjectDTO.ChapterDTO getChapterDetail(Long chapterId, Long userId) {
        Chapter chapter = chapterMapper.selectById(chapterId);
        if (chapter == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND); // Using general error or new one
        }
        
        // Verify ownership
        Subject subject = subjectMapper.selectById(chapter.getSubjectId());
        if (subject == null || !subject.getUserId().equals(userId)) {
             throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
        }

        // Fetch Level 1 Articles (Directly under Chapter)
        List<Article> chapterArticles = articleMapper.selectList(new LambdaQueryWrapper<Article>()
                .eq(Article::getChapterId, chapter.getId())
                .isNull(Article::getPointId)
                .orderByAsc(Article::getSortOrder));

        // Fetch Level 2 Points
        List<Point> points = pointMapper.selectList(new LambdaQueryWrapper<Point>()
                .eq(Point::getChapterId, chapter.getId())
                .orderByAsc(Point::getSortOrder));

        return SubjectDTO.ChapterDTO.builder()
                .id(chapter.getId())
                .title(chapter.getTitle())
                .totalPoints(points.size())
                .completedPoints((int) points.stream().filter(Point::getIsLearned).count())
                .contents(chapterArticles.stream()
                        .map(a -> SubjectDTO.ArticleDTO.builder()
                                .id(a.getId())
                                .title(a.getTitle())
                                .body(a.getContent())
                                .build())
                        .collect(Collectors.toList()))
                .children(points.stream()
                        .map(p -> {
                            // Fetch Level 2 Articles (Under Point)
                            List<Article> pointArticles = articleMapper.selectList(new LambdaQueryWrapper<Article>()
                                    .eq(Article::getPointId, p.getId())
                                    .orderByAsc(Article::getSortOrder));

                            return SubjectDTO.PointSummary.builder()
                                    .id(p.getId())
                                    .title(p.getTitle())
                                    .status(p.getStatus().getValue())
                                    .isLearned(p.getIsLearned())
                                    .needsReview(p.needsReview())
                                    .nextReviewDate(p.getNextReviewDate() != null ?
                                            p.getNextReviewDate().toString() : null)
                                    .lastReviewAt(p.getLastReviewAt() != null ?
                                            p.getLastReviewAt().toString() : null)
                                    .reviewCompleted(p.getReviewCompleted())
                                    .currentReviewStage(p.getCurrentReviewStage())
                                    .contents(pointArticles.stream()
                                            .map(a -> SubjectDTO.ArticleDTO.builder()
                                                    .id(a.getId())
                                                    .title(a.getTitle())
                                                    .body(a.getContent())
                                                    .build())
                                            .collect(Collectors.toList()))
                                    .build();
                        })
                        .collect(Collectors.toList()))
                .build();
    }

    /**
     * Get subject details (including chapters, points, and articles)
     */
    public SubjectDTO getSubjectDetail(Long subjectId, Long userId) {
        Subject subject = subjectMapper.selectById(subjectId);
        if (subject == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND);
        }

        if (!subject.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
        }

        SubjectDTO dto = SubjectDTO.fromEntity(subject);

        // Load chapters
        List<Chapter> chapters = chapterMapper.selectList(new LambdaQueryWrapper<Chapter>()
                .eq(Chapter::getSubjectId, subjectId)
                .orderByAsc(Chapter::getSortOrder));

        dto.setChapters(chapters.stream()
                .map(chapter -> {
                    // Fetch Level 1 Articles (Directly under Chapter)
                    List<Article> chapterArticles = articleMapper.selectList(new LambdaQueryWrapper<Article>()
                            .eq(Article::getChapterId, chapter.getId())
                            .isNull(Article::getPointId)
                            .orderByAsc(Article::getSortOrder));

                    // Fetch Level 2 Points
                    List<Point> points = pointMapper.selectList(new LambdaQueryWrapper<Point>()
                            .eq(Point::getChapterId, chapter.getId())
                            .orderByAsc(Point::getSortOrder));

                    return SubjectDTO.ChapterDTO.builder()
                            .id(chapter.getId())
                            .title(chapter.getTitle())
                            .totalPoints(points.size())
                            .completedPoints((int) points.stream().filter(Point::getIsLearned).count())
                            .contents(chapterArticles.stream()
                                    .map(a -> SubjectDTO.ArticleDTO.builder()
                                            .id(a.getId())
                                            .title(a.getTitle())
                                            .body(a.getContent())
                                            .build())
                                    .collect(Collectors.toList()))
                            .children(points.stream()
                                    .map(p -> {
                                        // Fetch Level 2 Articles (Under Point)
                                        List<Article> pointArticles = articleMapper.selectList(new LambdaQueryWrapper<Article>()
                                                .eq(Article::getPointId, p.getId())
                                                .orderByAsc(Article::getSortOrder));

                                        return SubjectDTO.PointSummary.builder()
                                                .id(p.getId())
                                                .title(p.getTitle())
                                                .status(p.getStatus().getValue())
                                                .isLearned(p.getIsLearned())
                                                .needsReview(p.needsReview())
                                                .nextReviewDate(p.getNextReviewDate() != null ?
                                                        p.getNextReviewDate().toString() : null)
                                                .lastReviewAt(p.getLastReviewAt() != null ?
                                                        p.getLastReviewAt().toString() : null)
                                                .reviewCompleted(p.getReviewCompleted())
                                                .currentReviewStage(p.getCurrentReviewStage())
                                                .contents(pointArticles.stream()
                                                        .map(a -> SubjectDTO.ArticleDTO.builder()
                                                                .id(a.getId())
                                                                .title(a.getTitle())
                                                                .body(a.getContent())
                                                                .build())
                                                        .collect(Collectors.toList()))
                                                .build();
                                    })
                                    .collect(Collectors.toList()))
                            .build();
                })
                .collect(Collectors.toList()));

        return dto;
    }

    /**
     * Create Subject with DSL Parsing
     */
    @Transactional
    public SubjectDTO createSubject(CreateSubjectRequest request, Long userId) {
        Goal goal = goalMapper.selectById(request.getGoalId());
        if (goal == null) {
            throw new BusinessException(ErrorCode.GOAL_NOT_FOUND);
        }

        if (!goal.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.GOAL_ACCESS_DENIED);
        }

        Long count = subjectMapper.selectCount(new LambdaQueryWrapper<Subject>()
                .eq(Subject::getGoalId, request.getGoalId()));

        Subject subject = Subject.builder()
                .goalId(request.getGoalId())
                .userId(userId)
                .title(request.getTitle())
                .progress(0)
                .totalPoints(0)
                .completedPoints(0)
                .sortOrder(count.intValue())
                .build();

        subjectMapper.insert(subject);

        if (request.getContent() != null && !request.getContent().isBlank()) {
            parseDslContent(request.getContent(), subject, userId);
        }

        goalService.recalculateGoalProgress(request.getGoalId());

        return getSubjectDetail(subject.getId(), userId);
    }

    @Transactional
    public SubjectDTO appendDsl(Long subjectId, String content, Long userId) {
        return appendDsl(subjectId, content, userId, null, null);
    }

    @Transactional
    public SubjectDTO appendDsl(Long subjectId, String content, Long userId, Long targetChapterId) {
        return appendDsl(subjectId, content, userId, targetChapterId, null);
    }

    @Transactional
    public SubjectDTO appendDsl(Long subjectId, String content, Long userId, Long targetChapterId, Long targetPointId) {
        Subject subject = subjectMapper.selectById(subjectId);
        if (subject == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND);
        }

        if (!subject.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
        }

        if (content != null && !content.isBlank()) {
            parseDslContent(content, subject, userId, targetChapterId, targetPointId);
        }

        // Recalculate goal progress
        goalService.recalculateGoalProgress(subject.getGoalId());

        return getSubjectDetail(subjectId, userId);
    }

    private void parseDslContent(String content, Subject subject, Long userId) {
        parseDslContent(content, subject, userId, null, null);
    }

    private void parseDslContent(String content, Subject subject, Long userId, Long targetChapterId) {
        parseDslContent(content, subject, userId, targetChapterId, null);
    }

    private void parseDslContent(String content, Subject subject, Long userId, Long targetChapterId, Long targetPointId) {
        String[] lines = content.split("\n");
        Chapter currentChapter = null;
        Point currentPoint = null;
        StringBuilder detailBuilder = new StringBuilder();
        boolean inDetail = false;
        int chapterOrder = chapterMapper.selectCount(new LambdaQueryWrapper<Chapter>()
                .eq(Chapter::getSubjectId, subject.getId())).intValue();
        int pointOrder = 0;
        int articleOrder = 0;
        Chapter forcedChapter = null;
        Point forcedPoint = null;

        if (targetPointId != null) {
            Point point = pointMapper.selectById(targetPointId);
            if (point == null || !point.getSubjectId().equals(subject.getId()) || !point.getUserId().equals(userId)) {
                throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
            }
            if (targetChapterId != null && !point.getChapterId().equals(targetChapterId)) {
                throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
            }
            Chapter chapter = chapterMapper.selectById(point.getChapterId());
            if (chapter == null || !chapter.getSubjectId().equals(subject.getId()) || !chapter.getUserId().equals(userId)) {
                throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
            }
            forcedChapter = chapter;
            forcedPoint = point;
            currentChapter = forcedChapter;
            currentPoint = forcedPoint;
            pointOrder = pointMapper.selectCount(new LambdaQueryWrapper<Point>()
                    .eq(Point::getChapterId, currentChapter.getId())).intValue();
            articleOrder = articleMapper.selectCount(new LambdaQueryWrapper<Article>()
                    .eq(Article::getPointId, forcedPoint.getId())).intValue();
        }

        if (targetChapterId != null && forcedPoint == null) {
            Chapter chapter = chapterMapper.selectById(targetChapterId);
            if (chapter == null || !chapter.getSubjectId().equals(subject.getId()) || !chapter.getUserId().equals(userId)) {
                throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
            }
            forcedChapter = chapter;
        }

        for (String line : lines) {
            String trimmedLine = line.trim();

            // Check if inside detail block
            if (inDetail) {
                if (trimmedLine.contains("}")) {
                    int endIndex = trimmedLine.indexOf("}");
                    detailBuilder.append(trimmedLine.substring(0, endIndex));

                    // Process Detail Block
                    String detail = detailBuilder.toString().trim();
                    processDetailBlock(detail, currentChapter, currentPoint, articleOrder++);

                    detailBuilder = new StringBuilder();
                    inDetail = false;
                } else {
                    detailBuilder.append(line).append("\n");
                }
                continue;
            }

            // Check start of detail block
            if (trimmedLine.contains("{")) {
                inDetail = true;
                int startIndex = trimmedLine.indexOf("{");
                detailBuilder.append(trimmedLine.substring(startIndex + 1));

                if (trimmedLine.contains("}")) {
                    int endIndex = trimmedLine.lastIndexOf("}");
                    String detail = trimmedLine.substring(startIndex + 1, endIndex).trim();
                    processDetailBlock(detail, currentChapter, currentPoint, articleOrder++);
                    inDetail = false;
                    detailBuilder = new StringBuilder();
                }
                continue;
            }

            // Check Chapter (@)
            if (trimmedLine.startsWith("@") && !trimmedLine.startsWith("@@")) {
                String chapterTitle = trimmedLine.substring(1).trim();
                if (!chapterTitle.isEmpty()) {
                    if (forcedPoint != null) {
                        currentChapter = forcedChapter;
                        currentPoint = forcedPoint;
                        articleOrder = articleMapper.selectCount(new LambdaQueryWrapper<Article>()
                                .eq(Article::getPointId, forcedPoint.getId())).intValue();
                        continue;
                    }

                    if (forcedChapter != null) {
                        currentChapter = forcedChapter;
                        pointOrder = pointMapper.selectCount(new LambdaQueryWrapper<Point>()
                                .eq(Point::getChapterId, currentChapter.getId())).intValue();
                        articleOrder = articleMapper.selectCount(new LambdaQueryWrapper<Article>()
                                .eq(Article::getChapterId, currentChapter.getId())
                                .isNull(Article::getPointId)).intValue();
                        currentPoint = null;
                        continue;
                    }

                    Chapter existingChapter = chapterMapper.selectOne(new LambdaQueryWrapper<Chapter>()
                            .eq(Chapter::getSubjectId, subject.getId())
                            .eq(Chapter::getTitle, chapterTitle)
                            .orderByAsc(Chapter::getSortOrder)
                            .last("LIMIT 1"));

                    if (existingChapter != null) {
                        currentChapter = existingChapter;
                        pointOrder = pointMapper.selectCount(new LambdaQueryWrapper<Point>()
                                .eq(Point::getChapterId, currentChapter.getId())).intValue();
                        articleOrder = articleMapper.selectCount(new LambdaQueryWrapper<Article>()
                                .eq(Article::getChapterId, currentChapter.getId())
                                .isNull(Article::getPointId)).intValue();
                    } else {
                        currentChapter = Chapter.builder()
                                .subjectId(subject.getId())
                                .userId(userId)
                                .title(chapterTitle)
                                .sortOrder(chapterOrder++)
                                .build();
                        chapterMapper.insert(currentChapter);
                        pointOrder = 0;
                        articleOrder = 0;
                    }

                    currentPoint = null; // Reset current point
                }
                continue;
            }

            // Check Point (@@)
            if (trimmedLine.startsWith("@@")) {
                String pointTitle = trimmedLine.substring(2).trim();
                if (forcedPoint != null) {
                    currentChapter = forcedChapter;
                    currentPoint = forcedPoint;
                    articleOrder = articleMapper.selectCount(new LambdaQueryWrapper<Article>()
                            .eq(Article::getPointId, forcedPoint.getId())).intValue();
                    continue;
                }
                if (!pointTitle.isEmpty() && currentChapter != null) {
                    currentPoint = Point.builder()
                            .chapterId(currentChapter.getId())
                            .subjectId(subject.getId())
                            .userId(userId)
                            .title(pointTitle)
                            .status(Point.PointStatus.pending)
                            .isLearned(false)
                            .currentReviewStage(0)
                            .reviewCompleted(false)
                            .sortOrder(pointOrder++)
                            .build();
                    pointMapper.insert(currentPoint);
                    articleOrder = 0; // Reset article order for new point
                }
            }
        }

        Long totalPoints = pointMapper.selectCount(new LambdaQueryWrapper<Point>()
                .eq(Point::getSubjectId, subject.getId()));
        int completedPoints = pointMapper.countLearnedBySubjectId(subject.getId());
        subject.setTotalPoints(totalPoints.intValue());
        subject.setCompletedPoints(completedPoints);
        subject.recalculateProgress();
        subjectMapper.updateById(subject);
    }

    private void processDetailBlock(String detail, Chapter currentChapter, Point currentPoint, int order) {
        String title = "Untitled";
        String body = "";

        // Extract Title
        Matcher titleMatcher = TITLE_PATTERN.matcher(detail);
        if (titleMatcher.find()) {
            title = titleMatcher.group(1).trim();
        }

        // Extract Content
        Matcher contentMatcher = CONTENT_PATTERN.matcher(detail);
        if (contentMatcher.find()) {
            body = contentMatcher.group(1).trim();
            // Handle unescaping quotes if needed, or simple string replacement
            body = body.replace("\\\"", "\"").replace("\\n", "\n"); 
        } else {
            // Fallback: use the whole detail string if pattern doesn't match
            // or maybe the user provided just content without keys? 
            // The prompt says syntax is strict: {title:..., content:...}
            // If regex fails, maybe assume it's just content?
            // Let's stick to regex. If fail, body is empty.
        }
        
        // If body is empty but detail is not, maybe it's legacy format?
        // But we are enforcing new format.

        Article article = Article.builder()
                .title(title)
                .content(body)
                .sortOrder(order)
                .build();

        if (currentPoint != null) {
            article.setPointId(currentPoint.getId());
            articleMapper.insert(article);
        } else if (currentChapter != null) {
            article.setChapterId(currentChapter.getId());
            articleMapper.insert(article);
        }
    }

    @Transactional
    public void deleteSubject(Long subjectId, Long userId) {
        Subject subject = subjectMapper.selectById(subjectId);
        if (subject == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND);
        }

        if (!subject.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
        }

        Long goalId = subject.getGoalId();

        // Manual delete for safety, though DB cascade exists
        List<Chapter> chapters = chapterMapper.selectList(new LambdaQueryWrapper<Chapter>()
                .eq(Chapter::getSubjectId, subjectId));
        
        for (Chapter chapter : chapters) {
            deleteChapter(chapter.getId(), userId);
        }

        subjectMapper.deleteById(subjectId);

        goalService.recalculateGoalProgress(goalId);
    }

    @Transactional
    public void deleteChapter(Long chapterId, Long userId) {
        Chapter chapter = chapterMapper.selectById(chapterId);
        if (chapter != null) {
             if (!chapter.getUserId().equals(userId)) {
                 throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
             }
             // Delete Points (Cascade deletes articles of points)
             pointMapper.delete(new LambdaQueryWrapper<Point>()
                     .eq(Point::getChapterId, chapter.getId()));
             
             // Delete Articles of Chapter
             articleMapper.delete(new LambdaQueryWrapper<Article>()
                     .eq(Article::getChapterId, chapter.getId()));

             chapterMapper.deleteById(chapterId);
             
             // Update Subject Progress
             updateSubjectProgress(chapter.getSubjectId());
        }
    }

    @Transactional
    public void deletePoint(Long pointId, Long userId) {
        Point point = pointMapper.selectById(pointId);
        if (point != null) {
            if (!point.getUserId().equals(userId)) {
                throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
            }
            // Delete Articles of Point
            articleMapper.delete(new LambdaQueryWrapper<Article>()
                    .eq(Article::getPointId, pointId));
            
            pointMapper.deleteById(pointId);
            
            // Update Subject Progress
            updateSubjectProgress(point.getSubjectId());
        }
    }

    @Transactional
    public void deleteArticle(Long articleId, Long userId) {
        // Since Article doesn't have userId, we check via parent (Chapter or Point -> Subject -> User)
        // Or simpler: We trust the caller? No.
        // We need to fetch article, then check parent.
        Article article = articleMapper.selectById(articleId);
        if (article != null) {
            checkArticlePermission(article, userId);
            articleMapper.deleteById(articleId);
        }
    }

    @Transactional
    public void updateArticle(Long articleId, String title, String content, Long userId) {
        Article article = articleMapper.selectById(articleId);
        if (article == null) {
            throw new BusinessException(ErrorCode.ARTICLE_NOT_FOUND);
        }
        
        checkArticlePermission(article, userId);

        article.setTitle(title);
        article.setContent(content);
        articleMapper.updateById(article);
    }

    private void checkArticlePermission(Article article, Long userId) {
        Long subjectId = null;
        if (article.getChapterId() != null) {
            Chapter c = chapterMapper.selectById(article.getChapterId());
            if (c != null) subjectId = c.getSubjectId();
        } else if (article.getPointId() != null) {
            Point p = pointMapper.selectById(article.getPointId());
            if (p != null) subjectId = p.getSubjectId();
        }

        if (subjectId != null) {
            Subject s = subjectMapper.selectById(subjectId);
            if (s != null && !s.getUserId().equals(userId)) {
                throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
            }
        }
    }

    @Transactional
    public void updateSubjectProgress(Long subjectId) {
        Subject subject = subjectMapper.selectById(subjectId);
        if (subject == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND);
        }

        Long totalPoints = pointMapper.selectCount(new LambdaQueryWrapper<Point>()
                .eq(Point::getSubjectId, subjectId));
        int completedPoints = pointMapper.countLearnedBySubjectId(subjectId);

        subject.setTotalPoints(totalPoints.intValue());
        subject.setCompletedPoints(completedPoints);
        subject.recalculateProgress();

        subjectMapper.updateById(subject);

        goalService.recalculateGoalProgress(subject.getGoalId());
    }

    @Transactional
    public void markChapterAsLearned(Long chapterId, Long userId) {
        Chapter chapter = chapterMapper.selectById(chapterId);
        if (chapter == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND);
        }

        if (!chapter.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
        }

        List<Point> points = pointMapper.selectList(new LambdaQueryWrapper<Point>()
                .eq(Point::getChapterId, chapterId));

        for (Point point : points) {
            if (!point.getIsLearned()) {
                point.markAsLearned(ebbinghausConfig);
                pointMapper.updateById(point);
            }
        }

        updateSubjectProgress(chapter.getSubjectId());
    }

    @Transactional
    public void unmarkChapterAsLearned(Long chapterId, Long userId) {
        Chapter chapter = chapterMapper.selectById(chapterId);
        if (chapter == null) {
            throw new BusinessException(ErrorCode.SUBJECT_NOT_FOUND);
        }

        if (!chapter.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.SUBJECT_ACCESS_DENIED);
        }

        List<Point> points = pointMapper.selectList(new LambdaQueryWrapper<Point>()
                .eq(Point::getChapterId, chapterId));

        for (Point point : points) {
            if (point.getIsLearned()) {
                point.unmarkAsLearned();
                pointMapper.updateById(point);
            }
        }

        updateSubjectProgress(chapter.getSubjectId());
    }
}
