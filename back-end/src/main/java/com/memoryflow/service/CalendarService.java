package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.dto.calendar.CalendarRecordDTO;
import com.memoryflow.entity.CalendarRecord;
import com.memoryflow.entity.Point;
import com.memoryflow.mapper.CalendarRecordMapper;
import com.memoryflow.mapper.PointMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CalendarService {

    private final CalendarRecordMapper calendarRecordMapper;
    private final PointMapper pointMapper;

    public List<CalendarRecordDTO> getMonthlyRecords(Long userId, int year, int month) {
        LocalDate start = LocalDate.of(year, month, 1);
        LocalDate end = start.plusMonths(1).minusDays(1);
        LocalDate today = LocalDate.now();

        // 1. 获取数据库中的日历记录
        List<CalendarRecord> records = calendarRecordMapper.selectByMonth(userId, start, end);
        Map<LocalDate, CalendarRecord> recordMap = records.stream()
                .collect(Collectors.toMap(CalendarRecord::getRecordDate, r -> r));

        // 2. 准备结果列表
        List<CalendarRecordDTO> result = new ArrayList<>();
        
        // 3. 获取活动数据（作为补充，如果日历记录不存在）
        // 注意：由于无法获取完整的历史记录（只有最后一次复习时间），这里只能作为一种近似补充
        List<Point> learnedPoints = pointMapper.selectList(new LambdaQueryWrapper<Point>()
                .eq(Point::getUserId, userId)
                .ge(Point::getLearnedAt, start.atStartOfDay())
                .le(Point::getLearnedAt, end.plusDays(1).atStartOfDay()));
        
        List<Point> reviewedPoints = pointMapper.selectList(new LambdaQueryWrapper<Point>()
                .eq(Point::getUserId, userId)
                .ge(Point::getLastReviewAt, start.atStartOfDay())
                .le(Point::getLastReviewAt, end.plusDays(1).atStartOfDay()));
                
        List<Point> duePoints = pointMapper.selectList(new LambdaQueryWrapper<Point>()
                .eq(Point::getUserId, userId)
                .ge(Point::getNextReviewDate, start)
                .le(Point::getNextReviewDate, end));

        // 按日期分组
        Map<LocalDate, List<Point>> learnedMap = learnedPoints.stream()
                .collect(Collectors.groupingBy(p -> p.getLearnedAt().toLocalDate()));
                
        Map<LocalDate, List<Point>> reviewedMap = reviewedPoints.stream()
                .collect(Collectors.groupingBy(p -> p.getLastReviewAt().toLocalDate()));
                
        Map<LocalDate, List<Point>> dueMap = duePoints.stream()
                .collect(Collectors.groupingBy(Point::getNextReviewDate));

        // 4. 遍历每一天构建 DTO
        for (LocalDate date = start; !date.isAfter(end); date = date.plusDays(1)) {
            CalendarRecord record = recordMap.get(date);
            CalendarRecordDTO dto = new CalendarRecordDTO();
            dto.setDate(date);
            dto.setIsToday(date.equals(today));

            if (record != null) {
                dto.setStatus(record.getStatus().getValue());
                dto.setStudyMinutes(record.getStudyMinutes());
                dto.setPointsCompleted(record.getPointsCompleted());
                dto.setWordsLearned(record.getWordsLearned());
            } else {
                // 尝试从 Point 数据推断
                int learnedCount = learnedMap.getOrDefault(date, Collections.emptyList()).size();
                int reviewedCount = reviewedMap.getOrDefault(date, Collections.emptyList()).size();
                int dueCount = dueMap.getOrDefault(date, Collections.emptyList()).size();
                
                int completedCount = learnedCount + reviewedCount;
                
                dto.setPointsCompleted(completedCount);
                dto.setWordsLearned(0); // 暂无法推断
                dto.setStudyMinutes(completedCount * 10); // 估算：每个要点10分钟
                
                // 确定状态
                if (completedCount > 0) {
                    // 有完成的学习或复习
                    if (dueCount > 0 && completedCount < dueCount) {
                         // 有待复习但完成数少于待复习数 -> 这里的逻辑比较模糊，暂定为 completed 如果有做
                         // 或者如果是过去的日子，且有未完成的 overdue -> missed
                         // 这里简化逻辑：只要有完成就是绿色
                         dto.setStatus("completed");
                    } else {
                        dto.setStatus("completed");
                    }
                } else {
                    // 没有完成
                    if (date.isBefore(today)) {
                         // 过去的日子
                         if (dueCount > 0) {
                             // 有安排但没做 -> Missed
                             dto.setStatus("missed");
                         } else {
                             dto.setStatus("none");
                         }
                    } else if (date.equals(today)) {
                        // 今天，还没做 -> partial 或 none (前端通常显示 Today 蓝色)
                        // 这里返回 none 让前端处理，或者 partial
                        dto.setStatus("none");
                    } else {
                        // 未来的日子
                         if (dueCount > 0) {
                             dto.setStatus("scheduled"); // 自定义状态，前端可能不需要，但可以作为扩展
                         } else {
                             dto.setStatus("none");
                         }
                    }
                }
            }
            result.add(dto);
        }

        return result;
    }
}
