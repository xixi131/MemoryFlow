package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import java.util.List;

/**
 * 自定义通用 Mapper，包含批量插入方法
 * @param <T>
 */
public interface MyBaseMapper<T> extends BaseMapper<T> {

    /**
     * 批量插入（仅插入非逻辑删除字段）
     * @param entityList 实体列表
     * @return 影响行数
     */
    int insertBatchSomeColumn(List<T> entityList);
}
