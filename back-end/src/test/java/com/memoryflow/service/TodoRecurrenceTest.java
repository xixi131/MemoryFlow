package com.memoryflow.service;

import com.memoryflow.entity.TodoTask;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class TodoRecurrenceTest {

    private TodoTask task(TodoTask.RepeatFreq freq, LocalDate dueDate) {
        return TodoTask.builder()
                .id(1L)
                .repeatFreq(freq)
                .repeatInterval(1)
                .repeatIndex(1)
                .dueDate(dueDate)
                .build();
    }

    @Test
    void dailyAdvancesByInterval() {
        TodoTask t = task(TodoTask.RepeatFreq.DAILY, LocalDate.of(2026, 9, 6));
        t.setRepeatInterval(3);

        TodoRecurrence.Occurrence next = TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 6));

        assertThat(next.getDueDate()).isEqualTo(LocalDate.of(2026, 9, 9));
        assertThat(next.getRepeatIndex()).isEqualTo(2);
    }

    @Test
    void weeklyWithoutWeekdaysKeepsSameDayOfWeek() {
        TodoTask t = task(TodoTask.RepeatFreq.WEEKLY, LocalDate.of(2026, 9, 7)); // 周一

        LocalDate next = TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 7)).getDueDate();

        assertThat(next).isEqualTo(LocalDate.of(2026, 9, 14));
    }

    @Test
    void weeklyWithWeekdaysPicksNextSelectedDayInSameWeek() {
        TodoTask t = task(TodoTask.RepeatFreq.WEEKLY, LocalDate.of(2026, 9, 7)); // 周一
        t.setRepeatByWeekdays("1,3,5"); // 周一、周三、周五

        LocalDate next = TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 7)).getDueDate();

        assertThat(next).isEqualTo(LocalDate.of(2026, 9, 9)); // 周三
    }

    @Test
    void weeklyWithWeekdaysJumpsToNextWeekAfterLastSelectedDay() {
        TodoTask t = task(TodoTask.RepeatFreq.WEEKLY, LocalDate.of(2026, 9, 11)); // 周五
        t.setRepeatByWeekdays("1,3,5");

        LocalDate next = TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 11)).getDueDate();

        assertThat(next).isEqualTo(LocalDate.of(2026, 9, 14)); // 下周一
    }

    @Test
    void biweeklySkipsOneFullWeek() {
        TodoTask t = task(TodoTask.RepeatFreq.WEEKLY, LocalDate.of(2026, 9, 11)); // 周五
        t.setRepeatInterval(2);
        t.setRepeatByWeekdays("5");

        LocalDate next = TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 11)).getDueDate();

        assertThat(next).isEqualTo(LocalDate.of(2026, 9, 25));
    }

    @Test
    void monthlyClampsToShorterMonth() {
        TodoTask t = task(TodoTask.RepeatFreq.MONTHLY, LocalDate.of(2026, 1, 31));

        LocalDate next = TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 1, 31)).getDueDate();

        assertThat(next).isEqualTo(LocalDate.of(2026, 2, 28));
    }

    @Test
    void skipsMissedOccurrencesSoNextTaskIsNotBornOverdue() {
        TodoTask t = task(TodoTask.RepeatFreq.DAILY, LocalDate.of(2026, 9, 1));

        TodoRecurrence.Occurrence next = TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 6));

        assertThat(next.getDueDate()).isEqualTo(LocalDate.of(2026, 9, 6));
        assertThat(next.getRepeatIndex()).isEqualTo(6);
    }

    @Test
    void stopsAfterRepeatUntil() {
        TodoTask t = task(TodoTask.RepeatFreq.WEEKLY, LocalDate.of(2026, 9, 7));
        t.setRepeatUntil(LocalDate.of(2026, 9, 10));

        assertThat(TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 7)).isFinished()).isTrue();
    }

    @Test
    void stopsAfterRepeatCount() {
        TodoTask t = task(TodoTask.RepeatFreq.DAILY, LocalDate.of(2026, 9, 6));
        t.setRepeatCount(3);
        t.setRepeatIndex(3);

        assertThat(TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 6)).isFinished()).isTrue();
    }

    @Test
    void nonRecurringTaskHasNoNextOccurrence() {
        TodoTask t = task(TodoTask.RepeatFreq.NONE, LocalDate.of(2026, 9, 6));

        assertThat(TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 6)).isFinished()).isTrue();
    }

    @Test
    void recurringTaskWithoutDueDateHasNoNextOccurrence() {
        TodoTask t = task(TodoTask.RepeatFreq.DAILY, null);

        assertThat(TodoRecurrence.nextOccurrence(t, LocalDate.of(2026, 9, 6)).isFinished()).isTrue();
    }

    @Test
    void formatWeekdaysDeduplicatesAndSorts() {
        assertThat(TodoRecurrence.formatWeekdays(List.of(5, 1, 3, 1))).isEqualTo("1,3,5");
        assertThat(TodoRecurrence.formatWeekdays(List.of(0, 9))).isNull();
        assertThat(TodoRecurrence.formatWeekdays(List.of())).isNull();
    }

    @Test
    void describeRendersChineseLabel() {
        TodoTask weekly = task(TodoTask.RepeatFreq.WEEKLY, LocalDate.of(2026, 9, 7));
        weekly.setRepeatInterval(2);
        weekly.setRepeatByWeekdays("1,3");

        assertThat(TodoRecurrence.describe(weekly)).isEqualTo("每 2 周 周一、周三");

        TodoTask monthly = task(TodoTask.RepeatFreq.MONTHLY, LocalDate.of(2026, 9, 7));
        monthly.setRepeatCount(6);

        assertThat(TodoRecurrence.describe(monthly)).isEqualTo("每月，共 6 次");
    }
}
