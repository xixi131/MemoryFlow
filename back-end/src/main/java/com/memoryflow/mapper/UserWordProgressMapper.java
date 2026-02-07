package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.memoryflow.entity.UserWordProgress;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDate;
import java.util.List;

@Mapper
public interface UserWordProgressMapper extends BaseMapper<UserWordProgress> {

    @Select("SELECT * FROM user_word_progress WHERE user_id = #{userId} " +
            "AND status != 'new' AND status != 'mastered' " +
            "AND next_review_at <= #{date} ORDER BY next_review_at ASC")
    List<UserWordProgress> findPendingReviews(@Param("userId") Long userId, @Param("date") LocalDate date);

    @Select("SELECT * FROM user_word_progress WHERE user_id = #{userId} " +
            "AND course_id = #{courseId} " +
            "AND status != 'new' AND status != 'mastered' " +
            "AND next_review_at <= #{date} ORDER BY next_review_at ASC")
    List<UserWordProgress> findPendingReviewsByCourse(@Param("userId") Long userId,
                                                      @Param("courseId") Long courseId,
                                                      @Param("date") LocalDate date);

    @Select("SELECT COUNT(*) FROM user_word_progress WHERE user_id = #{userId} " +
            "AND course_id = #{courseId} AND status != 'new'")
    int countLearnedWordsByCourse(@Param("userId") Long userId, @Param("courseId") Long courseId);

    @Select("SELECT COUNT(*) FROM user_word_progress WHERE user_id = #{userId} " +
            "AND status != 'new' AND status != 'mastered' " +
            "AND next_review_at <= #{date}")
    int countPendingReviews(@Param("userId") Long userId, @Param("date") LocalDate date);

    @Select("SELECT word_id FROM user_word_progress WHERE user_id = #{userId} " +
            "AND course_id = #{courseId} AND status != 'new'")
    List<Long> findLearnedWordIdsByCourse(@Param("userId") Long userId, @Param("courseId") Long courseId);

    @Select("SELECT * FROM user_word_progress WHERE user_id = #{userId} " +
            "AND status != 'new' ORDER BY updated_at DESC")
    IPage<UserWordProgress> findRecentlyLearned(Page<UserWordProgress> page, @Param("userId") Long userId);

    @Select("SELECT COUNT(*) FROM user_word_progress WHERE user_id = #{userId} " +
            "AND status != 'new' AND DATE(created_at) = #{date}")
    int countLearnedToday(@Param("userId") Long userId, @Param("date") LocalDate date);

    @Select("SELECT COUNT(*) FROM user_word_progress WHERE user_id = #{userId} " +
            "AND DATE(last_review_at) = #{date}")
    int countReviewedToday(@Param("userId") Long userId, @Param("date") LocalDate date);
}
