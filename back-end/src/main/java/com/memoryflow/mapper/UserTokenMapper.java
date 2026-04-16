package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.UserToken;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;

@Mapper
public interface UserTokenMapper extends BaseMapper<UserToken> {

    @Delete("DELETE FROM user_tokens WHERE expires_at < #{now}")
    void deleteExpiredTokens(@Param("now") LocalDateTime now);
}
