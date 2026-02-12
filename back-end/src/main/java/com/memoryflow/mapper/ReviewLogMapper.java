package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.ReviewLog;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface ReviewLogMapper extends BaseMapper<ReviewLog> {

    @Select("SELECT COUNT(*) FROM review_logs WHERE user_id = #{userId} AND is_completed = 1")
    int countTotalCompletedByUserId(@Param("userId") Long userId);

    @Select("SELECT id FROM review_logs " +
            "WHERE user_id = #{userId} AND point_id = #{pointId} AND review_stage = #{reviewStage} AND is_completed = 1 " +
            "ORDER BY id DESC LIMIT 1")
    Long findLatestCompletedId(@Param("userId") Long userId, @Param("pointId") Long pointId, @Param("reviewStage") Integer reviewStage);

    @Update("UPDATE review_logs SET is_completed = #{isCompleted} WHERE id = #{id}")
    int updateIsCompletedById(@Param("id") Long id, @Param("isCompleted") Boolean isCompleted);
}

