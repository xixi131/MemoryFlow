package com.memoryflow.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.memoryflow.dto.todo.BatchOperationResultDTO;
import com.memoryflow.dto.todo.BatchTodoTaskRequest;
import com.memoryflow.dto.todo.CreateTodoListRequest;
import com.memoryflow.dto.todo.CreateTodoSubtaskRequest;
import com.memoryflow.dto.todo.CreateTodoTagRequest;
import com.memoryflow.dto.todo.CreateTodoTaskRequest;
import com.memoryflow.dto.todo.ReorderRequest;
import com.memoryflow.dto.todo.TodoListDTO;
import com.memoryflow.dto.todo.TodoStatsDTO;
import com.memoryflow.dto.todo.TodoSubtaskDTO;
import com.memoryflow.dto.todo.TodoTagDTO;
import com.memoryflow.dto.todo.TodoTaskDTO;
import com.memoryflow.dto.todo.TodoTrendCountDTO;
import com.memoryflow.dto.todo.TodoTrendPointDTO;
import com.memoryflow.dto.todo.TodoTrendsDTO;
import com.memoryflow.dto.todo.UpdateTodoListRequest;
import com.memoryflow.dto.todo.UpdateTodoSubtaskRequest;
import com.memoryflow.dto.todo.UpdateTodoSubtaskStatusRequest;
import com.memoryflow.dto.todo.UpdateTodoTagRequest;
import com.memoryflow.dto.todo.UpdateTodoTaskRequest;
import com.memoryflow.dto.todo.UpdateTodoTaskStatusRequest;
import com.memoryflow.entity.TodoList;
import com.memoryflow.entity.TodoSubtask;
import com.memoryflow.entity.TodoTag;
import com.memoryflow.entity.TodoTask;
import com.memoryflow.entity.TodoTaskTag;
import com.memoryflow.exception.BusinessException;
import com.memoryflow.exception.ErrorCode;
import com.memoryflow.mapper.TodoListMapper;
import com.memoryflow.mapper.TodoSubtaskMapper;
import com.memoryflow.mapper.TodoTagMapper;
import com.memoryflow.mapper.TodoTaskMapper;
import com.memoryflow.mapper.TodoTaskTagMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class TodoService {

    private final TodoListMapper todoListMapper;
    private final TodoTaskMapper todoTaskMapper;
    private final TodoSubtaskMapper todoSubtaskMapper;
    private final TodoTagMapper todoTagMapper;
    private final TodoTaskTagMapper todoTaskTagMapper;

    public List<TodoListDTO> getLists(Long userId) {
        ensureDefaultList(userId);
        return todoListMapper.selectList(new LambdaQueryWrapper<TodoList>()
                        .eq(TodoList::getUserId, userId)
                        .orderByDesc(TodoList::getIsDefault)
                        .orderByAsc(TodoList::getSortOrder)
                        .orderByAsc(TodoList::getId))
                .stream()
                .map(this::toListDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public TodoListDTO createList(Long userId, CreateTodoListRequest request) {
        String name = safeTrim(request.getName());
        validateRequired(name, "清单名称不能为空");

        ensureListNameUnique(userId, name, null);

        TodoList list = TodoList.builder()
                .userId(userId)
                .name(name)
                .color(defaultIfBlank(request.getColor(), "#3A7FF1"))
                .icon(defaultIfBlank(request.getIcon(), "checklist"))
                .sortOrder(nextListSortOrder(userId))
                .isDefault(false)
                .build();
        todoListMapper.insert(list);
        return toListDTO(list);
    }

    @Transactional
    public TodoListDTO updateList(Long userId, Long listId, UpdateTodoListRequest request) {
        TodoList list = requireListOwner(listId, userId);

        String name = safeTrim(request.getName());
        validateRequired(name, "清单名称不能为空");
        ensureListNameUnique(userId, name, listId);

        list.setName(name);
        if (StringUtils.hasText(request.getColor())) {
            list.setColor(request.getColor().trim());
        }
        if (StringUtils.hasText(request.getIcon())) {
            list.setIcon(request.getIcon().trim());
        }
        if (request.getSortOrder() != null) {
            list.setSortOrder(request.getSortOrder());
        }

        todoListMapper.updateById(list);
        return toListDTO(list);
    }

    @Transactional
    public void deleteList(Long userId, Long listId) {
        TodoList list = requireListOwner(listId, userId);
        if (Boolean.TRUE.equals(list.getIsDefault())) {
            throw new BusinessException(ErrorCode.TODO_DEFAULT_LIST_DELETE_DENIED);
        }
        todoListMapper.deleteById(listId);
    }

    public List<TodoTagDTO> getTags(Long userId) {
        return todoTagMapper.selectList(new LambdaQueryWrapper<TodoTag>()
                        .eq(TodoTag::getUserId, userId)
                        .orderByAsc(TodoTag::getName))
                .stream()
                .map(this::toTagDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public TodoTagDTO createTag(Long userId, CreateTodoTagRequest request) {
        String name = safeTrim(request.getName());
        validateRequired(name, "标签名称不能为空");
        ensureTagNameUnique(userId, name, null);

        TodoTag tag = TodoTag.builder()
                .userId(userId)
                .name(name)
                .color(defaultIfBlank(request.getColor(), "#94A3B8"))
                .build();
        todoTagMapper.insert(tag);
        return toTagDTO(tag);
    }

    @Transactional
    public TodoTagDTO updateTag(Long userId, Long tagId, UpdateTodoTagRequest request) {
        TodoTag tag = requireTagOwner(tagId, userId);
        String name = safeTrim(request.getName());
        validateRequired(name, "标签名称不能为空");
        ensureTagNameUnique(userId, name, tagId);

        tag.setName(name);
        if (StringUtils.hasText(request.getColor())) {
            tag.setColor(request.getColor().trim());
        }
        todoTagMapper.updateById(tag);
        return toTagDTO(tag);
    }

    @Transactional
    public void deleteTag(Long userId, Long tagId) {
        requireTagOwner(tagId, userId);
        todoTaskTagMapper.deleteByTagId(tagId);
        todoTagMapper.deleteById(tagId);
    }

    public List<TodoTaskDTO> getTasks(Long userId,
                                      String keyword,
                                      String status,
                                      String timeFilter,
                                      String priority,
                                      Long listId,
                                      Long tagId,
                                      String sortBy,
                                      String sortOrder) {
        LambdaQueryWrapper<TodoTask> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TodoTask::getUserId, userId);

        if (listId != null) {
            requireListOwner(listId, userId);
            wrapper.eq(TodoTask::getListId, listId);
        }

        if (StringUtils.hasText(keyword)) {
            String value = keyword.trim();
            wrapper.and(w -> w.like(TodoTask::getTitle, value)
                    .or()
                    .like(TodoTask::getDescriptionMd, value));
        }

        String normalizedStatus = normalize(status);
        if (StringUtils.hasText(normalizedStatus) && !"all".equals(normalizedStatus)) {
            wrapper.eq(TodoTask::getStatus, parseTaskStatus(normalizedStatus));
        }

        String normalizedPriority = normalize(priority);
        if (StringUtils.hasText(normalizedPriority) && !"all".equals(normalizedPriority)) {
            wrapper.eq(TodoTask::getPriority, parsePriority(normalizedPriority));
        }

        applyTimeFilter(wrapper, timeFilter);

        if (tagId != null) {
            requireTagOwner(tagId, userId);
            List<Long> taskIds = todoTaskTagMapper.findTaskIdsByTagId(tagId);
            if (taskIds == null || taskIds.isEmpty()) {
                return Collections.emptyList();
            }
            wrapper.in(TodoTask::getId, taskIds);
        }

        applyTaskSort(wrapper, sortBy, sortOrder);

        List<TodoTask> tasks = todoTaskMapper.selectList(wrapper);
        return enrichTaskDTOs(tasks);
    }

    public TodoTaskDTO getTaskById(Long userId, Long taskId) {
        TodoTask task = requireTaskOwner(taskId, userId);
        List<TodoTaskDTO> dtos = enrichTaskDTOs(Collections.singletonList(task));
        if (dtos.isEmpty()) {
            throw new BusinessException(ErrorCode.TODO_TASK_NOT_FOUND);
        }
        return dtos.get(0);
    }

    @Transactional
    public TodoTaskDTO createTask(Long userId, CreateTodoTaskRequest request) {
        String title = safeTrim(request.getTitle());
        validateRequired(title, "任务标题不能为空");

        if (request.getListId() != null) {
            requireListOwner(request.getListId(), userId);
        }

        TodoTask task = TodoTask.builder()
                .userId(userId)
                .listId(request.getListId())
                .title(title)
                .descriptionMd(request.getDescriptionMd())
                .status(TodoTask.TaskStatus.TODO)
                .priority(parsePriority(defaultIfBlank(request.getPriority(), "none")))
                .dueDate(parseDateOrNull(request.getDueDate(), false))
                .dueTime(parseTimeOrNull(request.getDueTime(), false))
                .sortOrder(request.getSortOrder() != null ? request.getSortOrder() : nextTaskSortOrder(userId, request.getListId()))
                .completedAt(null)
                .build();

        todoTaskMapper.insert(task);
        syncTaskTags(userId, task.getId(), request.getTagIds());
        return getTaskById(userId, task.getId());
    }

    @Transactional
    public TodoTaskDTO updateTask(Long userId, Long taskId, UpdateTodoTaskRequest request) {
        TodoTask task = requireTaskOwner(taskId, userId);

        if (request.getTitle() != null) {
            String title = safeTrim(request.getTitle());
            validateRequired(title, "任务标题不能为空");
            task.setTitle(title);
        }
        if (request.getDescriptionMd() != null) {
            task.setDescriptionMd(request.getDescriptionMd());
        }
        if (request.getListId() != null) {
            requireListOwner(request.getListId(), userId);
            task.setListId(request.getListId());
        }
        if (request.getStatus() != null) {
            TodoTask.TaskStatus nextStatus = parseTaskStatus(request.getStatus());
            task.setStatus(nextStatus);
            task.setCompletedAt(nextStatus == TodoTask.TaskStatus.COMPLETED ? LocalDateTime.now() : null);
        }
        if (request.getPriority() != null) {
            task.setPriority(parsePriority(request.getPriority()));
        }
        if (request.getDueDate() != null) {
            task.setDueDate(parseDateOrNull(request.getDueDate(), true));
        }
        if (request.getDueTime() != null) {
            task.setDueTime(parseTimeOrNull(request.getDueTime(), true));
        }
        if (request.getSortOrder() != null) {
            task.setSortOrder(request.getSortOrder());
        }

        todoTaskMapper.updateById(task);

        if (request.getTagIds() != null) {
            syncTaskTags(userId, taskId, request.getTagIds());
        }

        return getTaskById(userId, taskId);
    }

    @Transactional
    public TodoTaskDTO updateTaskStatus(Long userId, Long taskId, UpdateTodoTaskStatusRequest request) {
        TodoTask task = requireTaskOwner(taskId, userId);
        if (Boolean.TRUE.equals(request.getCompleted())) {
            task.setStatus(TodoTask.TaskStatus.COMPLETED);
            task.setCompletedAt(LocalDateTime.now());
        } else {
            task.setStatus(TodoTask.TaskStatus.TODO);
            task.setCompletedAt(null);
        }
        todoTaskMapper.updateById(task);
        return getTaskById(userId, taskId);
    }

    @Transactional
    public void deleteTask(Long userId, Long taskId) {
        requireTaskOwner(taskId, userId);
        todoTaskTagMapper.deleteByTaskId(taskId);
        todoSubtaskMapper.delete(new LambdaQueryWrapper<TodoSubtask>().eq(TodoSubtask::getTaskId, taskId));
        todoTaskMapper.deleteById(taskId);
    }

    @Transactional
    public BatchOperationResultDTO batchOperateTasks(Long userId, BatchTodoTaskRequest request) {
        if (request.getTaskIds() == null || request.getTaskIds().isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "任务ID列表不能为空");
        }

        List<Long> uniqueIds = distinctNonNullIds(request.getTaskIds());
        if (uniqueIds.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "任务ID列表不能为空");
        }

        List<TodoTask> tasks = todoTaskMapper.selectList(new LambdaQueryWrapper<TodoTask>()
                .eq(TodoTask::getUserId, userId)
                .in(TodoTask::getId, uniqueIds));

        if (tasks.size() != uniqueIds.size()) {
            throw new BusinessException(ErrorCode.TODO_TASK_ACCESS_DENIED);
        }

        String action = normalize(request.getAction());
        int affected;
        switch (action) {
            case "complete":
                affected = updateTasksStatus(tasks, TodoTask.TaskStatus.COMPLETED);
                break;
            case "uncomplete":
                affected = updateTasksStatus(tasks, TodoTask.TaskStatus.TODO);
                break;
            case "delete":
                todoTaskTagMapper.deleteByTaskIds(uniqueIds);
                todoSubtaskMapper.delete(new LambdaQueryWrapper<TodoSubtask>().in(TodoSubtask::getTaskId, uniqueIds));
                affected = todoTaskMapper.deleteBatchIds(uniqueIds);
                break;
            case "move-list":
                if (request.getListId() != null) {
                    requireListOwner(request.getListId(), userId);
                }
                affected = moveTasksToList(tasks, request.getListId(), userId);
                break;
            case "set-priority":
                affected = updateTasksPriority(tasks, parsePriority(request.getPriority()));
                break;
            default:
                throw new BusinessException(ErrorCode.BAD_REQUEST, "不支持的批量操作: " + action);
        }

        return BatchOperationResultDTO.builder().affectedCount(affected).build();
    }

    @Transactional
    public void reorderTasks(Long userId, ReorderRequest request) {
        List<Long> taskIds = distinctNonNullIds(request.getIds());
        if (taskIds.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "排序ID列表不能为空");
        }

        List<TodoTask> tasks = todoTaskMapper.selectList(new LambdaQueryWrapper<TodoTask>()
                .eq(TodoTask::getUserId, userId)
                .in(TodoTask::getId, taskIds));
        if (tasks.size() != taskIds.size()) {
            throw new BusinessException(ErrorCode.TODO_TASK_ACCESS_DENIED);
        }

        Map<Long, TodoTask> taskMap = tasks.stream().collect(Collectors.toMap(TodoTask::getId, t -> t));
        for (int i = 0; i < taskIds.size(); i++) {
            TodoTask task = taskMap.get(taskIds.get(i));
            if (task != null) {
                task.setSortOrder(i);
                todoTaskMapper.updateById(task);
            }
        }
    }

    @Transactional
    public TodoSubtaskDTO createSubtask(Long userId, Long taskId, CreateTodoSubtaskRequest request) {
        TodoTask task = requireTaskOwner(taskId, userId);
        String title = safeTrim(request.getTitle());
        validateRequired(title, "子任务标题不能为空");

        TodoSubtask subtask = TodoSubtask.builder()
                .taskId(task.getId())
                .title(title)
                .status(TodoSubtask.SubtaskStatus.TODO)
                .sortOrder(nextSubtaskSortOrder(taskId))
                .build();
        todoSubtaskMapper.insert(subtask);
        return toSubtaskDTO(subtask);
    }

    @Transactional
    public TodoSubtaskDTO updateSubtask(Long userId, Long subtaskId, UpdateTodoSubtaskRequest request) {
        TodoSubtask subtask = requireSubtaskOwner(subtaskId, userId);
        if (request.getTitle() != null) {
            String title = safeTrim(request.getTitle());
            validateRequired(title, "子任务标题不能为空");
            subtask.setTitle(title);
        }
        if (request.getStatus() != null) {
            TodoSubtask.SubtaskStatus status = parseSubtaskStatus(request.getStatus());
            subtask.setStatus(status);
            subtask.setCompletedAt(status == TodoSubtask.SubtaskStatus.COMPLETED ? LocalDateTime.now() : null);
        }
        if (request.getSortOrder() != null) {
            subtask.setSortOrder(request.getSortOrder());
        }
        todoSubtaskMapper.updateById(subtask);
        return toSubtaskDTO(subtask);
    }

    @Transactional
    public TodoSubtaskDTO updateSubtaskStatus(Long userId, Long subtaskId, UpdateTodoSubtaskStatusRequest request) {
        TodoSubtask subtask = requireSubtaskOwner(subtaskId, userId);
        if (Boolean.TRUE.equals(request.getCompleted())) {
            subtask.setStatus(TodoSubtask.SubtaskStatus.COMPLETED);
            subtask.setCompletedAt(LocalDateTime.now());
        } else {
            subtask.setStatus(TodoSubtask.SubtaskStatus.TODO);
            subtask.setCompletedAt(null);
        }
        todoSubtaskMapper.updateById(subtask);
        return toSubtaskDTO(subtask);
    }

    @Transactional
    public void deleteSubtask(Long userId, Long subtaskId) {
        requireSubtaskOwner(subtaskId, userId);
        todoSubtaskMapper.deleteById(subtaskId);
    }

    @Transactional
    public void reorderSubtasks(Long userId, Long taskId, ReorderRequest request) {
        requireTaskOwner(taskId, userId);
        List<Long> subtaskIds = distinctNonNullIds(request.getIds());
        if (subtaskIds.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "排序ID列表不能为空");
        }

        List<TodoSubtask> subtasks = todoSubtaskMapper.selectList(new LambdaQueryWrapper<TodoSubtask>()
                .eq(TodoSubtask::getTaskId, taskId)
                .in(TodoSubtask::getId, subtaskIds));
        if (subtasks.size() != subtaskIds.size()) {
            throw new BusinessException(ErrorCode.TODO_SUBTASK_ACCESS_DENIED);
        }

        Map<Long, TodoSubtask> subtaskMap = subtasks.stream().collect(Collectors.toMap(TodoSubtask::getId, s -> s));
        for (int i = 0; i < subtaskIds.size(); i++) {
            TodoSubtask subtask = subtaskMap.get(subtaskIds.get(i));
            if (subtask != null) {
                subtask.setSortOrder(i);
                todoSubtaskMapper.updateById(subtask);
            }
        }
    }

    public TodoStatsDTO getStats(Long userId) {
        LocalDate today = LocalDate.now();
        LocalDate weekStart = today.minusDays(6);
        LocalDateTime weekStartTime = weekStart.atStartOfDay();

        int total = countTasks(userId, null, null, null, null);
        int pending = countTasks(userId, TodoTask.TaskStatus.TODO, null, null, null);
        int completed = countTasks(userId, TodoTask.TaskStatus.COMPLETED, null, null, null);
        int dueToday = countTasks(userId, TodoTask.TaskStatus.TODO, today, null, null);
        int dueTomorrow = countTasks(userId, TodoTask.TaskStatus.TODO, today.plusDays(1), null, null);
        int overdue = countTasks(userId, TodoTask.TaskStatus.TODO, null, today, true);
        int highPriorityPending = countTasks(userId, TodoTask.TaskStatus.TODO, null, null, TodoTask.Priority.HIGH);

        int createdThisWeek = todoTaskMapper.selectCount(new LambdaQueryWrapper<TodoTask>()
                .eq(TodoTask::getUserId, userId)
                .ge(TodoTask::getCreatedAt, weekStartTime)).intValue();

        int completedThisWeek = todoTaskMapper.selectCount(new LambdaQueryWrapper<TodoTask>()
                .eq(TodoTask::getUserId, userId)
                .eq(TodoTask::getStatus, TodoTask.TaskStatus.COMPLETED)
                .ge(TodoTask::getCompletedAt, weekStartTime)).intValue();

        double weekRate = createdThisWeek == 0 ? 0D : Math.min(100D, (completedThisWeek * 100D / createdThisWeek));

        return TodoStatsDTO.builder()
                .totalTasks(total)
                .pendingTasks(pending)
                .completedTasks(completed)
                .dueToday(dueToday)
                .dueTomorrow(dueTomorrow)
                .overdueTasks(overdue)
                .highPriorityPending(highPriorityPending)
                .createdThisWeek(createdThisWeek)
                .completedThisWeek(completedThisWeek)
                .weekCompletionRate(Math.round(weekRate * 100.0) / 100.0)
                .build();
    }

    public TodoTrendsDTO getTrends(Long userId, int days) {
        return getTrends(userId, days, LocalDate.now());
    }

    TodoTrendsDTO getTrends(Long userId, int days, LocalDate endDate) {
        if (days != 7 && days != 30) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "days 仅支持 7 或 30");
        }

        LocalDate startDate = endDate.minusDays(days - 1L);
        LocalDateTime startInclusive = startDate.atStartOfDay();
        LocalDateTime endExclusive = endDate.plusDays(1).atStartOfDay();

        Map<LocalDate, Integer> createdCounts = toTrendCountMap(
                todoTaskMapper.countCreatedTasksByDate(userId, startInclusive, endExclusive));
        Map<LocalDate, Integer> completedCounts = toTrendCountMap(
                todoTaskMapper.countCompletedTasksByDate(userId, startInclusive, endExclusive));

        List<TodoTrendPointDTO> points = new ArrayList<>(days);
        for (int offset = 0; offset < days; offset++) {
            LocalDate date = startDate.plusDays(offset);
            points.add(TodoTrendPointDTO.builder()
                    .date(date)
                    .createdTasks(createdCounts.getOrDefault(date, 0))
                    .completedTasks(completedCounts.getOrDefault(date, 0))
                    .build());
        }

        return TodoTrendsDTO.builder()
                .days(days)
                .startDate(startDate)
                .endDate(endDate)
                .points(points)
                .build();
    }

    private Map<LocalDate, Integer> toTrendCountMap(List<TodoTrendCountDTO> counts) {
        if (counts == null || counts.isEmpty()) {
            return Collections.emptyMap();
        }
        return counts.stream().collect(Collectors.toMap(
                TodoTrendCountDTO::getDate,
                count -> count.getTaskCount() == null ? 0 : count.getTaskCount(),
                Integer::sum));
    }

    private int countTasks(Long userId,
                           TodoTask.TaskStatus status,
                           LocalDate dueDateEq,
                           LocalDate dueDateBefore,
                           Object extra) {
        LambdaQueryWrapper<TodoTask> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(TodoTask::getUserId, userId);
        if (status != null) {
            wrapper.eq(TodoTask::getStatus, status);
        }
        if (dueDateEq != null) {
            wrapper.eq(TodoTask::getDueDate, dueDateEq);
        }
        if (dueDateBefore != null) {
            wrapper.isNotNull(TodoTask::getDueDate).lt(TodoTask::getDueDate, dueDateBefore);
        }
        if (extra instanceof TodoTask.Priority) {
            wrapper.eq(TodoTask::getPriority, extra);
        }
        Long count = todoTaskMapper.selectCount(wrapper);
        return count == null ? 0 : count.intValue();
    }

    private int updateTasksStatus(List<TodoTask> tasks, TodoTask.TaskStatus status) {
        int affected = 0;
        for (TodoTask task : tasks) {
            task.setStatus(status);
            task.setCompletedAt(status == TodoTask.TaskStatus.COMPLETED ? LocalDateTime.now() : null);
            affected += todoTaskMapper.updateById(task);
        }
        return affected;
    }

    private int updateTasksPriority(List<TodoTask> tasks, TodoTask.Priority priority) {
        int affected = 0;
        for (TodoTask task : tasks) {
            task.setPriority(priority);
            affected += todoTaskMapper.updateById(task);
        }
        return affected;
    }

    private int moveTasksToList(List<TodoTask> tasks, Long listId, Long userId) {
        int nextSortOrder = nextTaskSortOrder(userId, listId);
        int affected = 0;
        for (TodoTask task : tasks) {
            task.setListId(listId);
            task.setSortOrder(nextSortOrder++);
            affected += todoTaskMapper.updateById(task);
        }
        return affected;
    }

    private void applyTimeFilter(LambdaQueryWrapper<TodoTask> wrapper, String timeFilter) {
        String normalized = normalize(timeFilter);
        if (!StringUtils.hasText(normalized) || "all".equals(normalized)) {
            return;
        }

        LocalDate today = LocalDate.now();
        switch (normalized) {
            case "today":
                wrapper.eq(TodoTask::getDueDate, today);
                break;
            case "tomorrow":
                wrapper.eq(TodoTask::getDueDate, today.plusDays(1));
                break;
            case "week":
                wrapper.isNotNull(TodoTask::getDueDate)
                        .ge(TodoTask::getDueDate, today)
                        .le(TodoTask::getDueDate, today.plusDays(6));
                break;
            case "no-date":
                wrapper.isNull(TodoTask::getDueDate);
                break;
            case "overdue":
                wrapper.isNotNull(TodoTask::getDueDate)
                        .lt(TodoTask::getDueDate, today)
                        .eq(TodoTask::getStatus, TodoTask.TaskStatus.TODO);
                break;
            default:
                throw new BusinessException(ErrorCode.BAD_REQUEST, "不支持的时间筛选: " + timeFilter);
        }
    }

    private void applyTaskSort(LambdaQueryWrapper<TodoTask> wrapper, String sortBy, String sortOrder) {
        String normalizedSortBy = normalize(sortBy);
        String normalizedOrder = normalize(sortOrder);
        boolean desc = "desc".equals(normalizedOrder);

        if (!StringUtils.hasText(normalizedSortBy) || "custom".equals(normalizedSortBy)) {
            wrapper.orderByAsc(TodoTask::getSortOrder).orderByDesc(TodoTask::getCreatedAt);
            return;
        }

        switch (normalizedSortBy) {
            case "created":
                wrapper.orderBy(true, !desc, TodoTask::getCreatedAt).orderByAsc(TodoTask::getSortOrder);
                break;
            case "due":
                wrapper.orderBy(true, !desc, TodoTask::getDueDate)
                        .orderBy(true, !desc, TodoTask::getDueTime)
                        .orderByAsc(TodoTask::getSortOrder);
                break;
            case "priority":
                String direction = desc ? "DESC" : "ASC";
                wrapper.last("ORDER BY CASE priority " +
                        "WHEN 'high' THEN 1 " +
                        "WHEN 'medium' THEN 2 " +
                        "WHEN 'low' THEN 3 " +
                        "ELSE 4 END " + direction + ", sort_order ASC");
                break;
            default:
                throw new BusinessException(ErrorCode.BAD_REQUEST, "不支持的排序方式: " + sortBy);
        }
    }

    private List<TodoTaskDTO> enrichTaskDTOs(List<TodoTask> tasks) {
        if (tasks == null || tasks.isEmpty()) {
            return Collections.emptyList();
        }

        List<Long> taskIds = tasks.stream().map(TodoTask::getId).collect(Collectors.toList());
        Map<Long, List<TodoSubtask>> subtaskMap = buildSubtaskMap(taskIds);
        Map<Long, List<TodoTag>> tagMap = buildTaskTagMap(taskIds);

        List<TodoTaskDTO> result = new ArrayList<>();
        LocalDate today = LocalDate.now();
        for (TodoTask task : tasks) {
            List<TodoSubtask> subtasks = subtaskMap.getOrDefault(task.getId(), Collections.emptyList());
            List<TodoTag> tags = tagMap.getOrDefault(task.getId(), Collections.emptyList());

            int subtaskTotal = subtasks.size();
            int subtaskCompleted = (int) subtasks.stream()
                    .filter(s -> s.getStatus() == TodoSubtask.SubtaskStatus.COMPLETED)
                    .count();
            int subtaskProgress = subtaskTotal == 0 ? 0 : (int) Math.round(subtaskCompleted * 100.0 / subtaskTotal);

            boolean overdue = task.getStatus() != TodoTask.TaskStatus.COMPLETED
                    && task.getDueDate() != null
                    && task.getDueDate().isBefore(today);
            boolean dueToday = task.getDueDate() != null && task.getDueDate().isEqual(today);
            boolean dueTomorrow = task.getDueDate() != null && task.getDueDate().isEqual(today.plusDays(1));

            TodoTaskDTO dto = TodoTaskDTO.builder()
                    .id(task.getId())
                    .listId(task.getListId())
                    .title(task.getTitle())
                    .descriptionMd(task.getDescriptionMd())
                    .status(task.getStatus().getValue())
                    .priority(task.getPriority().getValue())
                    .dueDate(task.getDueDate())
                    .dueTime(task.getDueTime())
                    .sortOrder(task.getSortOrder())
                    .completedAt(formatDateTime(task.getCompletedAt()))
                    .createdAt(formatDateTime(task.getCreatedAt()))
                    .updatedAt(formatDateTime(task.getUpdatedAt()))
                    .overdue(overdue)
                    .dueToday(dueToday)
                    .dueTomorrow(dueTomorrow)
                    .subtaskTotal(subtaskTotal)
                    .subtaskCompleted(subtaskCompleted)
                    .subtaskProgress(subtaskProgress)
                    .tags(tags.stream().map(this::toTagDTO).collect(Collectors.toList()))
                    .subtasks(subtasks.stream()
                            .sorted(Comparator.comparing(TodoSubtask::getSortOrder).thenComparing(TodoSubtask::getId))
                            .map(this::toSubtaskDTO)
                            .collect(Collectors.toList()))
                    .build();
            result.add(dto);
        }
        return result;
    }

    private Map<Long, List<TodoSubtask>> buildSubtaskMap(List<Long> taskIds) {
        if (taskIds.isEmpty()) {
            return Collections.emptyMap();
        }
        List<TodoSubtask> subtasks = todoSubtaskMapper.findByTaskIds(taskIds);
        return subtasks.stream().collect(Collectors.groupingBy(TodoSubtask::getTaskId));
    }

    private Map<Long, List<TodoTag>> buildTaskTagMap(List<Long> taskIds) {
        if (taskIds.isEmpty()) {
            return Collections.emptyMap();
        }

        List<TodoTaskTag> taskTags = todoTaskTagMapper.findByTaskIds(taskIds);
        if (taskTags.isEmpty()) {
            return Collections.emptyMap();
        }

        Set<Long> tagIds = taskTags.stream().map(TodoTaskTag::getTagId).collect(Collectors.toSet());
        Map<Long, TodoTag> tagById = todoTagMapper.selectBatchIds(tagIds).stream()
                .collect(Collectors.toMap(TodoTag::getId, t -> t));

        Map<Long, List<TodoTag>> taskTagMap = new HashMap<>();
        for (TodoTaskTag taskTag : taskTags) {
            TodoTag tag = tagById.get(taskTag.getTagId());
            if (tag == null) {
                continue;
            }
            taskTagMap.computeIfAbsent(taskTag.getTaskId(), k -> new ArrayList<>()).add(tag);
        }
        return taskTagMap;
    }

    private void syncTaskTags(Long userId, Long taskId, List<Long> tagIds) {
        todoTaskTagMapper.deleteByTaskId(taskId);
        if (tagIds == null || tagIds.isEmpty()) {
            return;
        }

        List<Long> distinctTagIds = distinctNonNullIds(tagIds);
        if (distinctTagIds.isEmpty()) {
            return;
        }

        List<TodoTag> tags = todoTagMapper.selectList(new LambdaQueryWrapper<TodoTag>()
                .eq(TodoTag::getUserId, userId)
                .in(TodoTag::getId, distinctTagIds));
        if (tags.size() != distinctTagIds.size()) {
            throw new BusinessException(ErrorCode.TODO_TAG_ACCESS_DENIED);
        }

        for (Long tagId : distinctTagIds) {
            todoTaskTagMapper.insert(TodoTaskTag.builder().taskId(taskId).tagId(tagId).build());
        }
    }

    private TodoList requireListOwner(Long listId, Long userId) {
        TodoList list = todoListMapper.selectById(listId);
        if (list == null) {
            throw new BusinessException(ErrorCode.TODO_LIST_NOT_FOUND);
        }
        if (!Objects.equals(list.getUserId(), userId)) {
            throw new BusinessException(ErrorCode.TODO_LIST_ACCESS_DENIED);
        }
        return list;
    }

    private TodoTask requireTaskOwner(Long taskId, Long userId) {
        TodoTask task = todoTaskMapper.selectById(taskId);
        if (task == null) {
            throw new BusinessException(ErrorCode.TODO_TASK_NOT_FOUND);
        }
        if (!Objects.equals(task.getUserId(), userId)) {
            throw new BusinessException(ErrorCode.TODO_TASK_ACCESS_DENIED);
        }
        return task;
    }

    private TodoTag requireTagOwner(Long tagId, Long userId) {
        TodoTag tag = todoTagMapper.selectById(tagId);
        if (tag == null) {
            throw new BusinessException(ErrorCode.TODO_TAG_NOT_FOUND);
        }
        if (!Objects.equals(tag.getUserId(), userId)) {
            throw new BusinessException(ErrorCode.TODO_TAG_ACCESS_DENIED);
        }
        return tag;
    }

    private TodoSubtask requireSubtaskOwner(Long subtaskId, Long userId) {
        TodoSubtask subtask = todoSubtaskMapper.selectById(subtaskId);
        if (subtask == null) {
            throw new BusinessException(ErrorCode.TODO_SUBTASK_NOT_FOUND);
        }
        requireTaskOwner(subtask.getTaskId(), userId);
        return subtask;
    }

    private void ensureDefaultList(Long userId) {
        Long count = todoListMapper.selectCount(new LambdaQueryWrapper<TodoList>().eq(TodoList::getUserId, userId));
        if (count != null && count > 0) {
            return;
        }
        TodoList defaultList = TodoList.builder()
                .userId(userId)
                .name("我的待办")
                .color("#3A7FF1")
                .icon("checklist")
                .sortOrder(0)
                .isDefault(true)
                .build();
        todoListMapper.insert(defaultList);
    }

    private int nextListSortOrder(Long userId) {
        TodoList last = todoListMapper.selectOne(new LambdaQueryWrapper<TodoList>()
                .eq(TodoList::getUserId, userId)
                .orderByDesc(TodoList::getSortOrder)
                .last("LIMIT 1"));
        return last == null || last.getSortOrder() == null ? 0 : last.getSortOrder() + 1;
    }

    private int nextTaskSortOrder(Long userId, Long listId) {
        LambdaQueryWrapper<TodoTask> query = new LambdaQueryWrapper<TodoTask>().eq(TodoTask::getUserId, userId);
        if (listId == null) {
            query.isNull(TodoTask::getListId);
        } else {
            query.eq(TodoTask::getListId, listId);
        }
        TodoTask last = todoTaskMapper.selectOne(query.orderByDesc(TodoTask::getSortOrder).last("LIMIT 1"));
        return last == null || last.getSortOrder() == null ? 0 : last.getSortOrder() + 1;
    }

    private int nextSubtaskSortOrder(Long taskId) {
        TodoSubtask last = todoSubtaskMapper.selectOne(new LambdaQueryWrapper<TodoSubtask>()
                .eq(TodoSubtask::getTaskId, taskId)
                .orderByDesc(TodoSubtask::getSortOrder)
                .last("LIMIT 1"));
        return last == null || last.getSortOrder() == null ? 0 : last.getSortOrder() + 1;
    }

    private void ensureListNameUnique(Long userId, String name, Long excludeId) {
        LambdaQueryWrapper<TodoList> query = new LambdaQueryWrapper<TodoList>()
                .eq(TodoList::getUserId, userId)
                .eq(TodoList::getName, name);
        if (excludeId != null) {
            query.ne(TodoList::getId, excludeId);
        }
        Long count = todoListMapper.selectCount(query);
        if (count != null && count > 0) {
            throw new BusinessException(ErrorCode.TODO_LIST_NAME_DUPLICATED);
        }
    }

    private void ensureTagNameUnique(Long userId, String name, Long excludeId) {
        LambdaQueryWrapper<TodoTag> query = new LambdaQueryWrapper<TodoTag>()
                .eq(TodoTag::getUserId, userId)
                .eq(TodoTag::getName, name);
        if (excludeId != null) {
            query.ne(TodoTag::getId, excludeId);
        }
        Long count = todoTagMapper.selectCount(query);
        if (count != null && count > 0) {
            throw new BusinessException(ErrorCode.TODO_TAG_NAME_DUPLICATED);
        }
    }

    private TodoTask.TaskStatus parseTaskStatus(String raw) {
        String value = normalize(raw);
        switch (value) {
            case "todo":
                return TodoTask.TaskStatus.TODO;
            case "completed":
                return TodoTask.TaskStatus.COMPLETED;
            default:
                throw new BusinessException(ErrorCode.BAD_REQUEST, "无效的任务状态: " + raw);
        }
    }

    private TodoTask.Priority parsePriority(String raw) {
        String value = normalize(raw);
        if (!StringUtils.hasText(value) || "none".equals(value)) {
            return TodoTask.Priority.NONE;
        }
        switch (value) {
            case "high":
                return TodoTask.Priority.HIGH;
            case "medium":
                return TodoTask.Priority.MEDIUM;
            case "low":
                return TodoTask.Priority.LOW;
            default:
                throw new BusinessException(ErrorCode.BAD_REQUEST, "无效的优先级: " + raw);
        }
    }

    private TodoSubtask.SubtaskStatus parseSubtaskStatus(String raw) {
        String value = normalize(raw);
        switch (value) {
            case "todo":
                return TodoSubtask.SubtaskStatus.TODO;
            case "completed":
                return TodoSubtask.SubtaskStatus.COMPLETED;
            default:
                throw new BusinessException(ErrorCode.BAD_REQUEST, "无效的子任务状态: " + raw);
        }
    }

    private LocalDate parseDateOrNull(String raw, boolean allowBlankToClear) {
        if (raw == null) {
            return null;
        }
        String value = raw.trim();
        if (value.isEmpty() && allowBlankToClear) {
            return null;
        }
        if (value.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "截止日期格式不正确");
        }
        try {
            return LocalDate.parse(value);
        } catch (DateTimeParseException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "截止日期格式应为 YYYY-MM-DD");
        }
    }

    private LocalTime parseTimeOrNull(String raw, boolean allowBlankToClear) {
        if (raw == null) {
            return null;
        }
        String value = raw.trim();
        if (value.isEmpty() && allowBlankToClear) {
            return null;
        }
        if (value.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "截止时间格式不正确");
        }
        try {
            return LocalTime.parse(value);
        } catch (DateTimeParseException e) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "截止时间格式应为 HH:mm 或 HH:mm:ss");
        }
    }

    private String formatDateTime(LocalDateTime time) {
        return time == null ? null : time.toString();
    }

    private TodoListDTO toListDTO(TodoList entity) {
        return TodoListDTO.builder()
                .id(entity.getId())
                .name(entity.getName())
                .color(entity.getColor())
                .icon(entity.getIcon())
                .sortOrder(entity.getSortOrder())
                .isDefault(entity.getIsDefault())
                .build();
    }

    private TodoTagDTO toTagDTO(TodoTag entity) {
        return TodoTagDTO.builder()
                .id(entity.getId())
                .name(entity.getName())
                .color(entity.getColor())
                .build();
    }

    private TodoSubtaskDTO toSubtaskDTO(TodoSubtask entity) {
        return TodoSubtaskDTO.builder()
                .id(entity.getId())
                .taskId(entity.getTaskId())
                .title(entity.getTitle())
                .status(entity.getStatus().getValue())
                .sortOrder(entity.getSortOrder())
                .completedAt(formatDateTime(entity.getCompletedAt()))
                .build();
    }

    private void validateRequired(String value, String message) {
        if (!StringUtils.hasText(value)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, message);
        }
    }

    private String safeTrim(String value) {
        return value == null ? null : value.trim();
    }

    private String defaultIfBlank(String value, String defaultValue) {
        return StringUtils.hasText(value) ? value.trim() : defaultValue;
    }

    private String normalize(String value) {
        if (value == null) {
            return null;
        }
        return value.trim().toLowerCase();
    }

    private List<Long> distinctNonNullIds(Collection<Long> ids) {
        if (ids == null) {
            return Collections.emptyList();
        }
        Set<Long> set = new LinkedHashSet<>();
        for (Long id : ids) {
            if (id != null) {
                set.add(id);
            }
        }
        return new ArrayList<>(set);
    }
}
