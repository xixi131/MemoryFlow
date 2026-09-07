package com.memoryflow.service;

import com.memoryflow.entity.TodoTask;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

/**
 * 循环待办的日期推算与文案。纯函数实现，方便单测覆盖各种边界。
 */
public final class TodoRecurrence {

    /**
     * 一次「完成后顺延」最多向前推算的次数，避免历史任务导致死循环。
     */
    private static final int MAX_ADVANCE_STEPS = 500;

    private TodoRecurrence() {
    }

    /**
     * 循环序列推进后的结果。{@code dueDate} 为 null 表示序列已结束。
     */
    public static final class Occurrence {
        private final LocalDate dueDate;
        private final int repeatIndex;

        Occurrence(LocalDate dueDate, int repeatIndex) {
            this.dueDate = dueDate;
            this.repeatIndex = repeatIndex;
        }

        public LocalDate getDueDate() {
            return dueDate;
        }

        public int getRepeatIndex() {
            return repeatIndex;
        }

        public boolean isFinished() {
            return dueDate == null;
        }
    }

    public static boolean isRecurring(TodoTask task) {
        return task != null
                && task.getRepeatFreq() != null
                && task.getRepeatFreq() != TodoTask.RepeatFreq.NONE;
    }

    /**
     * 推算当前任务之后的下一次待办。
     *
     * @param today 参照的“今天”，早于今天的场次会被连续跳过，避免新任务一出生就逾期
     * @return 下一次的日期与序号；序列结束时 {@link Occurrence#isFinished()} 为 true
     */
    public static Occurrence nextOccurrence(TodoTask task, LocalDate today) {
        if (!isRecurring(task) || task.getDueDate() == null) {
            return new Occurrence(null, 0);
        }

        int interval = normalizeInterval(task.getRepeatInterval());
        Set<DayOfWeek> weekdays = parseWeekdays(task.getRepeatByWeekdays());
        int index = task.getRepeatIndex() == null ? 1 : task.getRepeatIndex();
        LocalDate cursor = task.getDueDate();

        for (int step = 0; step < MAX_ADVANCE_STEPS; step++) {
            cursor = advance(cursor, task.getRepeatFreq(), interval, weekdays);
            index++;

            if (task.getRepeatUntil() != null && cursor.isAfter(task.getRepeatUntil())) {
                return new Occurrence(null, 0);
            }
            if (task.getRepeatCount() != null && index > task.getRepeatCount()) {
                return new Occurrence(null, 0);
            }
            if (today == null || !cursor.isBefore(today)) {
                return new Occurrence(cursor, index);
            }
        }
        return new Occurrence(null, 0);
    }

    /**
     * 归一化循环序列的第一次日期。循环任务问的是「从哪天开始」而不是「哪天截止」，
     * 所以第一次永远不该落在今天之前，否则任务一创建就是逾期状态。
     *
     * <p>每周循环若指定了星期，还会把首次日期前推到最近一个选中的星期。
     *
     * @return 归一化后的首次日期；非循环任务原样返回
     */
    public static LocalDate firstOccurrence(LocalDate start,
                                            TodoTask.RepeatFreq freq,
                                            String weekdaysRaw,
                                            LocalDate today) {
        if (start == null || freq == null || freq == TodoTask.RepeatFreq.NONE) {
            return start;
        }

        LocalDate candidate = (today != null && start.isBefore(today)) ? today : start;

        if (freq == TodoTask.RepeatFreq.WEEKLY) {
            Set<DayOfWeek> weekdays = parseWeekdays(weekdaysRaw);
            if (!weekdays.isEmpty()) {
                for (int offset = 0; offset < 7 && !weekdays.contains(candidate.getDayOfWeek()); offset++) {
                    candidate = candidate.plusDays(1);
                }
            }
        }
        return candidate;
    }

    private static LocalDate advance(LocalDate from,
                                     TodoTask.RepeatFreq freq,
                                     int interval,
                                     Set<DayOfWeek> weekdays) {
        switch (freq) {
            case DAILY:
                return from.plusDays(interval);
            case WEEKLY:
                return advanceWeekly(from, interval, weekdays);
            case MONTHLY:
                return from.plusMonths(interval);
            case YEARLY:
                return from.plusYears(interval);
            default:
                return from.plusDays(interval);
        }
    }

    private static LocalDate advanceWeekly(LocalDate from, int interval, Set<DayOfWeek> weekdays) {
        if (weekdays.isEmpty()) {
            return from.plusWeeks(interval);
        }

        // 先看本周剩余的选中星期；用完之后跳到 interval 周后的第一个选中星期。
        LocalDate weekStart = from.with(DayOfWeek.MONDAY);
        for (int offset = 1; offset <= 6; offset++) {
            LocalDate candidate = from.plusDays(offset);
            if (candidate.isBefore(weekStart.plusWeeks(1)) && weekdays.contains(candidate.getDayOfWeek())) {
                return candidate;
            }
        }

        LocalDate nextWeekStart = weekStart.plusWeeks(interval);
        DayOfWeek first = Collections.min(weekdays);
        return nextWeekStart.plusDays(first.getValue() - 1L);
    }

    public static int normalizeInterval(Integer interval) {
        if (interval == null || interval < 1) {
            return 1;
        }
        return Math.min(interval, 365);
    }

    /**
     * 解析 "1,3,5" 形式的 ISO 星期编号，非法值直接忽略。
     */
    public static Set<DayOfWeek> parseWeekdays(String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            return Collections.emptySet();
        }
        Set<DayOfWeek> days = new TreeSet<>();
        for (String part : raw.split(",")) {
            String value = part.trim();
            if (value.isEmpty()) {
                continue;
            }
            try {
                int day = Integer.parseInt(value);
                if (day >= 1 && day <= 7) {
                    days.add(DayOfWeek.of(day));
                }
            } catch (NumberFormatException ignored) {
                // 忽略脏数据，等价于未指定星期
            }
        }
        return days;
    }

    /**
     * 归一化前端传入的星期列表，输出稳定顺序的 "1,3,5"；无有效值返回 null。
     */
    public static String formatWeekdays(List<Integer> days) {
        if (days == null || days.isEmpty()) {
            return null;
        }
        Set<Integer> unique = new TreeSet<>();
        for (Integer day : days) {
            if (day != null && day >= 1 && day <= 7) {
                unique.add(day);
            }
        }
        if (unique.isEmpty()) {
            return null;
        }
        List<String> parts = new ArrayList<>(unique.size());
        for (Integer day : unique) {
            parts.add(String.valueOf(day));
        }
        return String.join(",", parts);
    }

    public static List<Integer> weekdayNumbers(String raw) {
        Set<Integer> numbers = new LinkedHashSet<>();
        for (DayOfWeek day : parseWeekdays(raw)) {
            numbers.add(day.getValue());
        }
        return new ArrayList<>(numbers);
    }

    private static final String[] WEEKDAY_LABELS = {"一", "二", "三", "四", "五", "六", "日"};

    /**
     * 生成「每 2 周 周一、周三」这类中文描述，直接展示在列表与详情里。
     */
    public static String describe(TodoTask task) {
        if (!isRecurring(task)) {
            return null;
        }

        int interval = normalizeInterval(task.getRepeatInterval());
        StringBuilder text = new StringBuilder();
        switch (task.getRepeatFreq()) {
            case DAILY:
                text.append(interval == 1 ? "每天" : "每 " + interval + " 天");
                break;
            case WEEKLY:
                text.append(interval == 1 ? "每周" : "每 " + interval + " 周");
                Set<DayOfWeek> weekdays = parseWeekdays(task.getRepeatByWeekdays());
                if (!weekdays.isEmpty()) {
                    List<String> labels = new ArrayList<>(weekdays.size());
                    for (DayOfWeek day : weekdays) {
                        labels.add("周" + WEEKDAY_LABELS[day.getValue() - 1]);
                    }
                    text.append(' ').append(String.join("、", labels));
                }
                break;
            case MONTHLY:
                text.append(interval == 1 ? "每月" : "每 " + interval + " 个月");
                break;
            case YEARLY:
                text.append(interval == 1 ? "每年" : "每 " + interval + " 年");
                break;
            default:
                return null;
        }

        if (task.getRepeatCount() != null) {
            text.append("，共 ").append(task.getRepeatCount()).append(" 次");
        } else if (task.getRepeatUntil() != null) {
            text.append("，至 ").append(task.getRepeatUntil());
        }
        return text.toString();
    }
}
