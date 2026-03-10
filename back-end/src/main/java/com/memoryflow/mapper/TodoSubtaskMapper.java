package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.TodoSubtask;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface TodoSubtaskMapper extends BaseMapper<TodoSubtask> {

    @Select({
            "<script>",
            "SELECT id, task_id, title, status, sort_order, completed_at, created_at, updated_at",
            "FROM todo_subtasks",
            "WHERE task_id IN",
            "<foreach collection='taskIds' item='id' open='(' separator=',' close=')'>",
            "#{id}",
            "</foreach>",
            "</script>"
    })
    List<TodoSubtask> findByTaskIds(@Param("taskIds") List<Long> taskIds);
}

