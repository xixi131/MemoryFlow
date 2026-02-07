package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.memoryflow.config.EbbinghausConfig;
import com.memoryflow.dto.vocabulary.*;
import com.memoryflow.entity.*;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.mapper.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class VocabularyService {

    private final EnglishWordMapper wordMapper;
    private final EnglishCourseMapper courseMapper;
    private final CourseWordMapper courseWordMapper;
    private final UserWordProgressMapper progressMapper;
    private final UserCourseMapper userCourseMapper;
    private final UserSettingsMapper userSettingsMapper;
    private final UserSettingsService userSettingsService;
    private final EbbinghausConfig ebbinghausConfig;

    /**
     * 获取所有可用课程
     */
    public List<CourseDTO> getAllCourses(Long userId) {
        List<EnglishCourse> courses = courseMapper.selectList(new LambdaQueryWrapper<EnglishCourse>()
                .eq(EnglishCourse::getIsActive, true)
                .orderByAsc(EnglishCourse::getSortOrder));

        // Get global settings
        UserSettings settings = userSettingsMapper.selectOne(new LambdaQueryWrapper<UserSettings>()
                .eq(UserSettings::getUserId, userId));
        Integer globalDailyGoal = settings != null ? settings.getDailyNewWordsGoal() : 20;

        return courses.stream().map(course -> {
            CourseDTO dto = convertToCourseDTO(course);

            // 获取用户学习进度
            UserCourse userCourse = userCourseMapper.selectOne(new LambdaQueryWrapper<UserCourse>()
                    .eq(UserCourse::getUserId, userId)
                    .eq(UserCourse::getCourseId, course.getId()));

            if (userCourse != null) {
                // Only mark as user course if it is currently ACTIVE
                boolean isActive = Boolean.TRUE.equals(userCourse.getIsActive());
                dto.setIsUserCourse(isActive);
                dto.setLearnedCount(userCourse.getLearnedCount());
                dto.setDailyGoal(globalDailyGoal); // Use global goal
                dto.setProgress(course.getWordCount() > 0
                        ? (double) userCourse.getLearnedCount() / course.getWordCount() * 100
                        : 0.0);
                
                log.info("Course {} (ID={}) for User {}: isActive={}, isUserCourse={}", 
                        course.getName(), course.getId(), userId, userCourse.getIsActive(), dto.getIsUserCourse());
            } else {
                dto.setIsUserCourse(false);
                dto.setLearnedCount(0);
                dto.setDailyGoal(globalDailyGoal); // Use global goal as default
                dto.setProgress(0.0);
            }

            return dto;
        }).collect(Collectors.toList());
    }

    /**
     * 获取用户已选课程
     */
    public List<CourseDTO> getUserCourses(Long userId) {
        List<UserCourse> userCourses = userCourseMapper.selectList(new LambdaQueryWrapper<UserCourse>()
                .eq(UserCourse::getUserId, userId)
                .eq(UserCourse::getIsActive, true));

        return userCourses.stream().map(uc -> {
            EnglishCourse course = courseMapper.selectById(uc.getCourseId());
            if (course == null) {
                throw new BusinessException(ErrorCode.COURSE_NOT_FOUND);
            }

            CourseDTO dto = convertToCourseDTO(course);
            dto.setIsUserCourse(true);
            dto.setLearnedCount(uc.getLearnedCount());
            dto.setDailyGoal(uc.getDailyGoal());
            dto.setProgress(course.getWordCount() > 0
                    ? (double) uc.getLearnedCount() / course.getWordCount() * 100
                    : 0.0);

            return dto;
        }).collect(Collectors.toList());
    }

    /**
     * 选择课程/词书
     */
    @Transactional
    public CourseDTO selectCourse(Long userId, SelectCourseRequest request) {
        EnglishCourse course = courseMapper.selectById(request.getCourseId());
        if (course == null) {
            throw new BusinessException(ErrorCode.COURSE_NOT_FOUND);
        }

        // 先取消该用户所有其他课程的激活状态
        List<UserCourse> activeCourses = userCourseMapper.selectList(new LambdaQueryWrapper<UserCourse>()
                .eq(UserCourse::getUserId, userId)
                .eq(UserCourse::getIsActive, true));
        
        for (UserCourse activeCourse : activeCourses) {
            if (!activeCourse.getCourseId().equals(request.getCourseId())) {
                activeCourse.setIsActive(false);
                userCourseMapper.updateById(activeCourse);
            }
        }

        List<UserCourse> userCourses = userCourseMapper.selectList(new LambdaQueryWrapper<UserCourse>()
                .eq(UserCourse::getUserId, userId)
                .eq(UserCourse::getCourseId, request.getCourseId()));

        UserCourse userCourse;
        if (!userCourses.isEmpty()) {
            // 如果存在重复记录，取第一个，删除其他的
            userCourse = userCourses.get(0);
            if (userCourses.size() > 1) {
                log.warn("Found duplicate UserCourse records for userId={} courseId={}, cleaning up...", userId, request.getCourseId());
                for (int i = 1; i < userCourses.size(); i++) {
                    userCourseMapper.deleteById(userCourses.get(i).getId());
                }
            }
            
            userCourse.setIsActive(true);
            userCourse.setDailyGoal(request.getDailyGoal());
            userCourseMapper.updateById(userCourse);
        } else {
            userCourse = UserCourse.builder()
                    .userId(userId)
                    .courseId(request.getCourseId())
                    .isActive(true)
                    .dailyGoal(request.getDailyGoal())
                    .learnedCount(0)
                    .build();
            userCourseMapper.insert(userCourse);
        }

        // Update global settings
        UserSettings settings = userSettingsMapper.selectOne(new LambdaQueryWrapper<UserSettings>()
                .eq(UserSettings::getUserId, userId));
        if (settings == null) {
            settings = UserSettings.createDefault(userId);
        }
        settings.setDailyNewWordsGoal(request.getDailyGoal());
        if (settings.getId() == null) {
            userSettingsMapper.insert(settings);
        } else {
            userSettingsMapper.updateById(settings);
        }
        userSettingsService.updateSyncTime(userId);

        CourseDTO dto = convertToCourseDTO(course);
        dto.setIsUserCourse(true);
        dto.setLearnedCount(userCourse.getLearnedCount());
        dto.setDailyGoal(userCourse.getDailyGoal());
        // 计算真实的进度百分比
        dto.setProgress(course.getWordCount() > 0
                ? (double) userCourse.getLearnedCount() / course.getWordCount() * 100
                : 0.0);

        return dto;
    }

    /**
     * 获取学习会话
     * 策略：优先获取所有待复习单词，然后根据每日目标填充新词
     */
    public StudySessionDTO getStudySession(Long userId, Long courseId) {
        // 1. 获取所有待复习单词
        List<WordDTO> reviewWords = getPendingReviewWords(userId, courseId);

        // 2. 计算还需要多少新词
        // 策略：新词数量直接等于每日目标 (dailyGoal)，复习词数量不占用新词配额
        // 这意味着每日总任务量 = 每日新词目标 + 当日需复习单词数
        int newWordsLimit = 20;

        // 如果未指定课程ID，尝试查找用户最近激活的课程
        if (courseId == null) {
            UserCourse activeCourse = userCourseMapper.selectOne(new LambdaQueryWrapper<UserCourse>()
                    .eq(UserCourse::getUserId, userId)
                    .eq(UserCourse::getIsActive, true)
                    .orderByDesc(UserCourse::getUpdatedAt)
                    .last("LIMIT 1"));
            if (activeCourse != null) {
                courseId = activeCourse.getCourseId();
            } else {
                // 如果没有激活课程，尝试查找第一个可用课程
                EnglishCourse firstCourse = courseMapper.selectOne(new LambdaQueryWrapper<EnglishCourse>()
                        .orderByAsc(EnglishCourse::getSortOrder)
                        .last("LIMIT 1"));
                if (firstCourse != null) {
                    courseId = firstCourse.getId();
                }
            }
        }
        
        if (courseId != null) {
            UserCourse userCourse = userCourseMapper.selectOne(new LambdaQueryWrapper<UserCourse>()
                    .eq(UserCourse::getUserId, userId)
                    .eq(UserCourse::getCourseId, courseId));
            if (userCourse != null && userCourse.getDailyGoal() != null) {
                newWordsLimit = userCourse.getDailyGoal();
            }
        }

        // 填充新词
        List<WordDTO> newWords = new ArrayList<>();
        if (courseId != null) {
            newWords = getTodayLearningWords(userId, courseId, newWordsLimit);
        }

        // 3. 组合列表
        List<WordDTO> allWords = new ArrayList<>();
        allWords.addAll(reviewWords);
        allWords.addAll(newWords);

        return StudySessionDTO.builder()
                .words(allWords)
                .newCount(newWords.size())
                .reviewCount(reviewWords.size())
                .totalCount(allWords.size())
                .build();
    }

    /**
     * 获取今日学习单词列表
     */
    public List<WordDTO> getTodayLearningWords(Long userId, Long courseId, int limit) {
        // 获取课程中的所有单词ID
        List<Long> courseWordIds = courseWordMapper.findWordIdsByCourseId(courseId);

        // 获取用户已学习的单词ID
        Set<Long> learnedWordIds = progressMapper.findLearnedWordIdsByCourse(userId, courseId)
                .stream().collect(Collectors.toSet());

        // 筛选未学习的单词
        List<Long> unlearnedWordIds = courseWordIds.stream()
                .filter(id -> !learnedWordIds.contains(id))
                .collect(Collectors.toList());

        if (unlearnedWordIds.isEmpty()) {
            return new ArrayList<>();
        }

        // 随机打乱顺序，避免出现字母序堆积 (a... b... c...)
        java.util.Collections.shuffle(unlearnedWordIds);

        // 取出限制数量的单词ID
        List<Long> selectedIds = unlearnedWordIds.stream()
                .limit(limit)
                .collect(Collectors.toList());

        // 获取单词详情
        // 注意：selectBatchIds 返回的顺序可能不一致，所以如果需要保持随机性，可能需要重新排序
        // 但这里我们主要目的是为了"不要全是a开头"，只要选出来的ID是散乱的，最后怎么排都行。
        // 不过为了体验更好，我们还是在内存里再shuffle一次结果
        List<WordDTO> result = wordMapper.selectBatchIds(selectedIds).stream()
                .map(word -> convertToWordDTO(word, null))
                .collect(Collectors.toList());
        
        java.util.Collections.shuffle(result);
        return result;
    }

    /**
     * 获取待复习单词
     */
    public List<WordDTO> getPendingReviewWords(Long userId, Long courseId) {
        List<UserWordProgress> pendingList;

        if (courseId != null) {
            pendingList = progressMapper.findPendingReviewsByCourse(userId, courseId, LocalDate.now());
        } else {
            pendingList = progressMapper.findPendingReviews(userId, LocalDate.now());
        }

        return pendingList.stream().map(progress -> {
            EnglishWord word = wordMapper.selectById(progress.getWordId());
            if (word == null) return null;
            return convertToWordDTO(word, progress);
        }).filter(dto -> dto != null).collect(Collectors.toList());
    }

    /**
     * 学习单词
     */
    @Transactional
    public WordDTO learnWord(Long userId, LearnWordRequest request) {
        EnglishWord word = wordMapper.selectById(request.getWordId());
        if (word == null) {
            throw new BusinessException(ErrorCode.WORD_NOT_FOUND);
        }

        UserWordProgress progress = progressMapper.selectOne(new LambdaQueryWrapper<UserWordProgress>()
                .eq(UserWordProgress::getUserId, userId)
                .eq(UserWordProgress::getWordId, request.getWordId()));

        if (progress != null) {
            progress.setIsLearned(false); // dummy call or remove it
            // Logic change: Entity uses status string now.
            // isLearned was boolean.
            // Check status instead
            if ("mastered".equals(progress.getStatus()) || "learning".equals(progress.getStatus())) {
                 throw new BusinessException(ErrorCode.WORD_ALREADY_LEARNED);
            }
        } else {
            progress = UserWordProgress.builder()
                    .userId(userId)
                    .wordId(request.getWordId())
                    .courseId(request.getCourseId())
                    .status("new")
                    .reviewCount(0)
                    .correctCount(0)
                    .wrongCount(0)
                    .familiarity(0)
                    .build();
            progressMapper.insert(progress);
        }

        // 标记为已学习
        progress.markAsLearned(ebbinghausConfig.getIntervalDays(1));
        progressMapper.updateById(progress);

        // 更新用户课程学习进度
        if (request.getCourseId() != null) {
            UserCourse userCourse = userCourseMapper.selectOne(new LambdaQueryWrapper<UserCourse>()
                    .eq(UserCourse::getUserId, userId)
                    .eq(UserCourse::getCourseId, request.getCourseId()));

            if (userCourse != null) {
                userCourse.setLearnedCount(userCourse.getLearnedCount() + 1);
                userCourseMapper.updateById(userCourse);
            }
        }

        return convertToWordDTO(word, progress);
    }

    /**
     * 复习单词
     */
    @Transactional
    public WordDTO reviewWord(Long userId, ReviewWordRequest request) {
        EnglishWord word = wordMapper.selectById(request.getWordId());
        if (word == null) {
            throw new BusinessException(ErrorCode.WORD_NOT_FOUND);
        }

        UserWordProgress progress = progressMapper.selectOne(new LambdaQueryWrapper<UserWordProgress>()
                .eq(UserWordProgress::getUserId, userId)
                .eq(UserWordProgress::getWordId, request.getWordId()));

        if (progress == null || "new".equals(progress.getStatus())) {
            throw new BusinessException(ErrorCode.WORD_NOT_LEARNED);
        }

        int[] cycles = ebbinghausConfig.getCycles().stream().mapToInt(Integer::intValue).toArray();

        if (request.getCorrect()) {
            progress.completeReviewCorrect(cycles);
        } else {
            progress.completeReviewWrong(cycles);
        }

        progressMapper.updateById(progress);

        return convertToWordDTO(word, progress);
    }

    /**
     * 获取单词详情
     */
    public WordDTO getWordDetail(Long userId, Long wordId) {
        EnglishWord word = wordMapper.selectById(wordId);
        if (word == null) {
            throw new BusinessException(ErrorCode.WORD_NOT_FOUND);
        }

        UserWordProgress progress = progressMapper.selectOne(new LambdaQueryWrapper<UserWordProgress>()
                .eq(UserWordProgress::getUserId, userId)
                .eq(UserWordProgress::getWordId, wordId));

        return convertToWordDTO(word, progress);
    }

    /**
     * 获取指定日期的已学单词
     */
    public List<WordDTO> getLearnedWordsByDate(Long userId, String dateStr) {
        LocalDate date = LocalDate.parse(dateStr);
        java.time.LocalDateTime startOfDay = date.atStartOfDay();
        java.time.LocalDateTime endOfDay = date.plusDays(1).atStartOfDay();

        List<UserWordProgress> progressList = progressMapper.selectList(new LambdaQueryWrapper<UserWordProgress>()
                .eq(UserWordProgress::getUserId, userId)
                .ge(UserWordProgress::getCreatedAt, startOfDay)
                .lt(UserWordProgress::getCreatedAt, endOfDay)
                .ne(UserWordProgress::getStatus, "new"));

        return progressList.stream()
                .map(progress -> {
                    EnglishWord word = wordMapper.selectById(progress.getWordId());
                    return convertToWordDTO(word, progress);
                })
                .collect(Collectors.toList());
    }

    /**
     * 搜索单词
     */
    public List<WordDTO> searchWords(Long userId, String keyword, int page, int size) {
        IPage<EnglishWord> wordPage = wordMapper.searchWords(new Page<>(page, size), keyword);

        return wordPage.getRecords().stream()
                .map(word -> {
                    UserWordProgress progress = progressMapper.selectOne(new LambdaQueryWrapper<UserWordProgress>()
                            .eq(UserWordProgress::getUserId, userId)
                            .eq(UserWordProgress::getWordId, word.getId()));
                    return convertToWordDTO(word, progress);
                })
                .collect(Collectors.toList());
    }

    /**
     * 获取学习统计
     */
    public VocabularyStatsDTO getStats(Long userId) {
        LocalDate today = LocalDate.now();

        int todayLearned = progressMapper.countLearnedToday(userId, today);
        int todayReviewed = progressMapper.countReviewedToday(userId, today);
        int pendingReviewCount = progressMapper.countPendingReviews(userId, today);

        List<UserCourse> userCourses = userCourseMapper.selectList(new LambdaQueryWrapper<UserCourse>()
                .eq(UserCourse::getUserId, userId)
                .eq(UserCourse::getIsActive, true));

        int totalLearned = userCourses.stream().mapToInt(UserCourse::getLearnedCount).sum();

        return VocabularyStatsDTO.builder()
                .totalLearned(totalLearned)
                .todayLearned(todayLearned)
                .todayReviewed(todayReviewed)
                .pendingReviewCount(pendingReviewCount)
                .totalCourses(userCourses.size())
                .streak(0) // TODO: 实现连续学习天数计算
                .build();
    }

    private CourseDTO convertToCourseDTO(EnglishCourse course) {
        return CourseDTO.builder()
                .id(course.getId())
                .name(course.getName())
                .code(course.getCode())
                .description(course.getDescription())
                .coverImage(course.getCoverImage())
                .wordCount(course.getWordCount())
                .category(course.getCategory())
                .difficulty(course.getDifficulty())
                .icon(course.getIcon())
                .colorTheme(course.getColorTheme())
                .build();
    }

    private WordDTO convertToWordDTO(EnglishWord word, UserWordProgress progress) {
        String audioUrl = word.getAudioUrl();
        // 如果数据库没有音频链接，动态生成有道词典的在线发音链接 (美式发音 type=2)
        if (audioUrl == null || audioUrl.trim().isEmpty()) {
            audioUrl = "https://dict.youdao.com/dictvoice?audio=" + word.getWord() + "&type=2";
        }

        WordDTO dto = WordDTO.builder()
                .id(word.getId())
                .word(word.getWord())
                .phonetic(word.getPhonetic())
                .definition(word.getDefinition())
                .translation(word.getTranslation())
                .tag(word.getTag())
                .collins(word.getCollins())
                .oxford(word.getOxford())
                .bnc(word.getBnc())
                .frq(word.getFrq())
                .pos(word.getPos())
                .audioUrl(audioUrl)
                .exchange(word.getExchange())
                .detail(word.getDetail())
                .build();

        if (progress != null) {
            dto.setIsLearned(!"new".equals(progress.getStatus()));
            dto.setCurrentReviewStage(progress.getReviewCount());
            dto.setNextReviewDate(progress.getNextReviewAt() != null
                    ? progress.getNextReviewAt().toLocalDate().toString() : null);
            dto.setFamiliarity(progress.getFamiliarity());
            dto.setCorrectCount(progress.getCorrectCount());
            dto.setWrongCount(progress.getWrongCount());
        } else {
            dto.setIsLearned(false);
            dto.setCurrentReviewStage(0);
            dto.setFamiliarity(0);
            dto.setCorrectCount(0);
            dto.setWrongCount(0);
        }

        return dto;
    }
}
