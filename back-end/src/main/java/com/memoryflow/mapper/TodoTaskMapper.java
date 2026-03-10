package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.TodoTask;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface TodoTaskMapper extends BaseMapper<TodoTask> {
}

