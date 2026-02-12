package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.Point;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDate;
import java.util.List;

@Mapper
public interface PointMapper extends BaseMapper<Point> {

    @Select("SELECT COUNT(*) FROM points WHERE subject_id = #{subjectId} AND is_learned = true")
    int countLearnedBySubjectId(@Param("subjectId") Long subjectId);

    @Select("SELECT COUNT(*) FROM points WHERE chapter_id = #{chapterId}")
    int countByChapterId(@Param("chapterId") Long chapterId);

    @Select("SELECT COUNT(*) FROM points WHERE chapter_id = #{chapterId} AND is_learned = true")
    int countLearnedByChapterId(@Param("chapterId") Long chapterId);

    // ========== 复习相关查询 ==========

    /**
     * 查询用户所有待复习的要点（包括今天已复习的）
     */
    @Select("SELECT * FROM points WHERE user_id = #{userId} AND is_learned = true " +
            "AND (" +
            "   (review_completed = false AND next_review_date <= #{today}) " +
            "   OR " +
            "   (last_review_at IS NOT NULL AND DATE(last_review_at) = #{today})" +
            ") ORDER BY next_review_date ASC")
    List<Point> findPendingReviewsByUserId(@Param("userId") Long userId, @Param("today") LocalDate today);

    /**
     * 查询用户今天需要复习的要点
     */
    @Select("SELECT * FROM points WHERE user_id = #{userId} AND is_learned = true " +
            "AND review_completed = false AND next_review_date = #{today}")
    List<Point> findTodayReviewsByUserId(@Param("userId") Long userId, @Param("today") LocalDate today);

    /**
     * 查询用户逾期的复习要点
     */
    @Select("SELECT * FROM points WHERE user_id = #{userId} AND is_learned = true " +
            "AND review_completed = false AND next_review_date < #{today} ORDER BY next_review_date ASC")
    List<Point> findOverdueReviewsByUserId(@Param("userId") Long userId, @Param("today") LocalDate today);

    /**
     * 按科目查询待复习要点
     */
    @Select("SELECT * FROM points WHERE subject_id = #{subjectId} AND is_learned = true " +
            "AND review_completed = false AND next_review_date <= #{today}")
    List<Point> findPendingReviewsBySubjectId(@Param("subjectId") Long subjectId, @Param("today") LocalDate today);

    /**
     * 统计用户待复习数量
     */
    @Select("SELECT COUNT(*) FROM points WHERE user_id = #{userId} AND is_learned = true " +
            "AND review_completed = false AND next_review_date <= #{today}")
    int countPendingReviewsByUserId(@Param("userId") Long userId, @Param("today") LocalDate today);

    /**
     * 统计科目待复习数量
     */
    @Select("SELECT COUNT(*) FROM points WHERE subject_id = #{subjectId} AND is_learned = true " +
            "AND review_completed = false AND next_review_date <= #{today}")
    int countPendingReviewsBySubjectId(@Param("subjectId") Long subjectId, @Param("today") LocalDate today);

    /**
     * 查询科目下逾期的复习要点数量
     */
    @Select("SELECT COUNT(*) FROM points WHERE subject_id = #{subjectId} AND is_learned = true " +
            "AND review_completed = false AND next_review_date < #{today}")
    int countOverdueReviewsBySubjectId(@Param("subjectId") Long subjectId, @Param("today") LocalDate today);

    /**
     * 统计用户今日已复习完成的数量 (基于 last_review_at 判断)
     */
    @Select("SELECT COUNT(*) FROM points WHERE user_id = #{userId} AND is_learned = true " +
            "AND last_review_at IS NOT NULL AND DATE(last_review_at) = #{today}")
    int countCompletedReviewsByUserId(@Param("userId") Long userId, @Param("today") LocalDate today);

    @Select("SELECT COUNT(*) FROM points WHERE user_id = #{userId} AND is_learned = true AND last_review_at IS NOT NULL")
    int countCumulativeReviewedPointsByUserId(@Param("userId") Long userId);
}
