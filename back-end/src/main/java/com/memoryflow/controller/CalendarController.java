package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
import com.memoryflow.dto.calendar.CalendarRecordDTO;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.CalendarService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/calendar")
@RequiredArgsConstructor
public class CalendarController {

    private final CalendarService calendarService;
    private final SecurityUtils securityUtils;

    @GetMapping("/records")
    public ApiResponse<List<CalendarRecordDTO>> getMonthlyRecords(
            @RequestParam Integer year,
            @RequestParam Integer month) {
        Long userId = securityUtils.getCurrentUserId();
        List<CalendarRecordDTO> records = calendarService.getMonthlyRecords(userId, year, month);
        return ApiResponse.success(records);
    }
}
