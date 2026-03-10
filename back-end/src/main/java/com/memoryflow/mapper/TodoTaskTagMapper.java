package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.TodoTaskTag;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface TodoTaskTagMapper extends BaseMapper<TodoTaskTag> {

    @Delete("DELETE FROM todo_task_tags WHERE task_id = #{taskId}")
    int deleteByTaskId(@Param("taskId") Long taskId);

    @Select("SELECT tag_id FROM todo_task_tags WHERE task_id = #{taskId}")
    List<Long> findTagIdsByTaskId(@Param("taskId") Long taskId);

    @Select("SELECT task_id FROM todo_task_tags WHERE tag_id = #{tagId}")
    List<Long> findTaskIdsByTagId(@Param("tagId") Long tagId);

    @Delete("DELETE FROM todo_task_tags WHERE tag_id = #{tagId}")
    int deleteByTagId(@Param("tagId") Long tagId);

    @Delete({
            "<script>",
            "DELETE FROM todo_task_tags WHERE task_id IN",
            "<foreach collection='taskIds' item='id' open='(' separator=',' close=')'>",
            "#{id}",
            "</foreach>",
            "</script>"
    })
    int deleteByTaskIds(@Param("taskIds") List<Long> taskIds);

    @Select({
            "<script>",
            "SELECT id, task_id, tag_id, created_at",
            "FROM todo_task_tags",
            "WHERE task_id IN",
            "<foreach collection='taskIds' item='id' open='(' separator=',' close=')'>",
            "#{id}",
            "</foreach>",
            "</script>"
    })
    List<TodoTaskTag> findByTaskIds(@Param("taskIds") List<Long> taskIds);
}

