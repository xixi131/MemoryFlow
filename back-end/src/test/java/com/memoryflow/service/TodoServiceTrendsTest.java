package com.memoryflow.service;

import com.memoryflow.dto.todo.TodoTrendCountDTO;
import com.memoryflow.dto.todo.TodoTrendPointDTO;
import com.memoryflow.dto.todo.TodoTrendsDTO;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.mapper.TodoListMapper;
import com.memoryflow.mapper.TodoSubtaskMapper;
import com.memoryflow.mapper.TodoTagMapper;
import com.memoryflow.mapper.TodoTaskMapper;
import com.memoryflow.mapper.TodoTaskTagMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TodoServiceTrendsTest {

    @Mock private TodoListMapper todoListMapper;
    @Mock private TodoTaskMapper todoTaskMapper;
    @Mock private TodoSubtaskMapper todoSubtaskMapper;
    @Mock private TodoTagMapper todoTagMapper;
    @Mock private TodoTaskTagMapper todoTaskTagMapper;

    private TodoService todoService;

    @BeforeEach
    void setUp() {
        todoService = new TodoService(todoListMapper, todoTaskMapper, todoSubtaskMapper,
                todoTagMapper, todoTaskTagMapper);
    }

    @Test
    void returnsSevenDayTrendWithZeroFillAndInclusiveBoundaries() {
        Long userId = 42L;
        LocalDate endDate = LocalDate.of(2026, 7, 16);
        LocalDate startDate = LocalDate.of(2026, 7, 10);
        LocalDateTime startInclusive = startDate.atStartOfDay();
        LocalDateTime endExclusive = endDate.plusDays(1).atStartOfDay();

        when(todoTaskMapper.countCreatedTasksByDate(userId, startInclusive, endExclusive))
                .thenReturn(List.of(
                        new TodoTrendCountDTO(startDate, 2),
                        new TodoTrendCountDTO(endDate, 1)));
        when(todoTaskMapper.countCompletedTasksByDate(userId, startInclusive, endExclusive))
                .thenReturn(List.of(new TodoTrendCountDTO(startDate.plusDays(3), 4)));

        TodoTrendsDTO result = todoService.getTrends(userId, 7, endDate);

        assertThat(result.getDays()).isEqualTo(7);
        assertThat(result.getStartDate()).isEqualTo(startDate);
        assertThat(result.getEndDate()).isEqualTo(endDate);
        assertThat(result.getPoints()).hasSize(7);
        assertThat(result.getPoints()).extracting(TodoTrendPointDTO::getDate).isSorted();
        assertThat(result.getPoints().get(0).getCreatedTasks()).isEqualTo(2);
        assertThat(result.getPoints().get(3).getCompletedTasks()).isEqualTo(4);
        assertThat(result.getPoints().get(5).getCreatedTasks()).isZero();
        assertThat(result.getPoints().get(6).getCreatedTasks()).isEqualTo(1);
        verify(todoTaskMapper).countCreatedTasksByDate(userId, startInclusive, endExclusive);
        verify(todoTaskMapper).countCompletedTasksByDate(userId, startInclusive, endExclusive);
    }

    @Test
    void returnsThirtyZeroFilledDaysForEmptyData() {
        Long userId = 7L;
        LocalDate endDate = LocalDate.of(2026, 7, 16);
        LocalDate startDate = endDate.minusDays(29);
        when(todoTaskMapper.countCreatedTasksByDate(userId, startDate.atStartOfDay(),
                endDate.plusDays(1).atStartOfDay())).thenReturn(List.of());
        when(todoTaskMapper.countCompletedTasksByDate(userId, startDate.atStartOfDay(),
                endDate.plusDays(1).atStartOfDay())).thenReturn(List.of());

        TodoTrendsDTO result = todoService.getTrends(userId, 30, endDate);

        assertThat(result.getPoints()).hasSize(30);
        assertThat(result.getPoints()).allSatisfy(point -> {
            assertThat(point.getCreatedTasks()).isZero();
            assertThat(point.getCompletedTasks()).isZero();
        });
        verify(todoTaskMapper).countCreatedTasksByDate(userId, startDate.atStartOfDay(),
                endDate.plusDays(1).atStartOfDay());
        verify(todoTaskMapper).countCompletedTasksByDate(userId, startDate.atStartOfDay(),
                endDate.plusDays(1).atStartOfDay());
    }

    @Test
    void rejectsUnsupportedRangeBeforeQueryingData() {
        assertThatThrownBy(() -> todoService.getTrends(42L, 14, LocalDate.of(2026, 7, 16)))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("days");
        verifyNoInteractions(todoTaskMapper);
    }
}
