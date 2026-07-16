package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.dto.todo.TodoTrendCountDTO;
import com.memoryflow.entity.TodoTask;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface TodoTaskMapper extends BaseMapper<TodoTask> {

    @Select("SELECT DATE(created_at) AS date, COUNT(*) AS task_count " +
            "FROM todo_tasks " +
            "WHERE user_id = #{userId} AND created_at >= #{startInclusive} AND created_at < #{endExclusive} " +
            "GROUP BY DATE(created_at) ORDER BY DATE(created_at)")
    List<TodoTrendCountDTO> countCreatedTasksByDate(@Param("userId") Long userId,
                                                    @Param("startInclusive") LocalDateTime startInclusive,
                                                    @Param("endExclusive") LocalDateTime endExclusive);

    @Select("SELECT DATE(completed_at) AS date, COUNT(*) AS task_count " +
            "FROM todo_tasks " +
            "WHERE user_id = #{userId} AND completed_at >= #{startInclusive} AND completed_at < #{endExclusive} " +
            "GROUP BY DATE(completed_at) ORDER BY DATE(completed_at)")
    List<TodoTrendCountDTO> countCompletedTasksByDate(@Param("userId") Long userId,
                                                      @Param("startInclusive") LocalDateTime startInclusive,
                                                      @Param("endExclusive") LocalDateTime endExclusive);
}
