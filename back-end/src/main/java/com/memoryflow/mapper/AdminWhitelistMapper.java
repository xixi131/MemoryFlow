package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.AdminWhitelist;
import org.apache.ibatis.annotations.Mapper;

/**
 * 注册白名单 Mapper 接口
 */
@Mapper
public interface AdminWhitelistMapper extends BaseMapper<AdminWhitelist> {
}
