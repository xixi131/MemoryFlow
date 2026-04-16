package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.memoryflow.entity.CourseWord;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface CourseWordMapper extends BaseMapper<CourseWord> {

    @Select("SELECT * FROM course_words WHERE course_id = #{courseId} ORDER BY sort_order ASC")
    IPage<CourseWord> findWordsByCourse(Page<CourseWord> page, @Param("courseId") Long courseId);

    @Select("SELECT word_id FROM course_words WHERE course_id = #{courseId}")
    List<Long> findWordIdsByCourseId(@Param("courseId") Long courseId);
}
