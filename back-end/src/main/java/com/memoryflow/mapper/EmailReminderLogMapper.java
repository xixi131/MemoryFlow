package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.EmailReminderLog;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDateTime;

@Mapper
public interface EmailReminderLogMapper extends BaseMapper<EmailReminderLog> {

    @Select("SELECT COUNT(*) > 0 FROM email_reminder_logs " +
            "WHERE user_id = #{userId} " +
            "AND reminder_type = #{reminderType} " +
            "AND status = 'sent' " +
            "AND created_at > #{since}")
    boolean hasRecentReminder(@Param("userId") Long userId,
                              @Param("reminderType") String reminderType,
                              @Param("since") LocalDateTime since);
}
