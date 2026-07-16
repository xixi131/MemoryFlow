package com.memoryflow.controller;

import com.memoryflow.dto.todo.TodoTrendsDTO;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.exception.GlobalExceptionHandler;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.TodoService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.LocalDate;
import java.util.List;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
class TodoControllerTrendsTest {

    @Mock private TodoService todoService;
    @Mock private SecurityUtils securityUtils;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new TodoController(todoService, securityUtils))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void returnsAuthenticatedUsersTrend() throws Exception {
        LocalDate date = LocalDate.of(2026, 7, 16);
        TodoTrendsDTO response = TodoTrendsDTO.builder()
                .days(7)
                .startDate(date.minusDays(6))
                .endDate(date)
                .points(List.of())
                .build();
        when(securityUtils.getCurrentUserId()).thenReturn(42L);
        when(todoService.getTrends(42L, 7)).thenReturn(response);

        mockMvc.perform(get("/todos/stats/trends").param("days", "7"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.days").value(7))
                .andExpect(jsonPath("$.data.startDate").value("2026-07-10"))
                .andExpect(jsonPath("$.data.endDate").value("2026-07-16"));

        verify(todoService).getTrends(42L, 7);
    }

    @Test
    void returnsBadRequestForUnsupportedRange() throws Exception {
        when(securityUtils.getCurrentUserId()).thenReturn(42L);
        when(todoService.getTrends(42L, 14))
                .thenThrow(new BusinessException(ErrorCode.BAD_REQUEST, "days 仅支持 7 或 30"));

        mockMvc.perform(get("/todos/stats/trends").param("days", "14"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));
    }
}
