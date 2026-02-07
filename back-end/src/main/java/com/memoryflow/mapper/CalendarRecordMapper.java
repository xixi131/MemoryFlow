package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.memoryflow.entity.CalendarRecord;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDate;
import java.util.List;

@Mapper
public interface CalendarRecordMapper extends BaseMapper<CalendarRecord> {

    @Select("SELECT * FROM calendar_records WHERE user_id = #{userId} AND record_date BETWEEN #{startDate} AND #{endDate}")
    List<CalendarRecord> selectByMonth(@Param("userId") Long userId, @Param("startDate") LocalDate startDate, @Param("endDate") LocalDate endDate);
}
