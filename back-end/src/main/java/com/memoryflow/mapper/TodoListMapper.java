package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.TodoList;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface TodoListMapper extends BaseMapper<TodoList> {
}

