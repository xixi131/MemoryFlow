package com.memoryflow.controller;

import com.memoryflow.dto.ApiResponse;
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
import com.memoryflow.dto.todo.UpdateTodoListRequest;
import com.memoryflow.dto.todo.UpdateTodoSubtaskRequest;
import com.memoryflow.dto.todo.UpdateTodoSubtaskStatusRequest;
import com.memoryflow.dto.todo.UpdateTodoTagRequest;
import com.memoryflow.dto.todo.UpdateTodoTaskRequest;
import com.memoryflow.dto.todo.UpdateTodoTaskStatusRequest;
import com.memoryflow.security.SecurityUtils;
import com.memoryflow.service.TodoService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/todos")
@RequiredArgsConstructor
public class TodoController {

    private final TodoService todoService;
    private final SecurityUtils securityUtils;

    @GetMapping("/lists")
    public ApiResponse<List<TodoListDTO>> getLists() {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.getLists(userId));
    }

    @PostMapping("/lists")
    public ApiResponse<TodoListDTO> createList(@Valid @RequestBody CreateTodoListRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.createList(userId, request));
    }

    @PutMapping("/lists/{id}")
    public ApiResponse<TodoListDTO> updateList(@PathVariable Long id, @Valid @RequestBody UpdateTodoListRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.updateList(userId, id, request));
    }

    @DeleteMapping("/lists/{id}")
    public ApiResponse<Void> deleteList(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        todoService.deleteList(userId, id);
        return ApiResponse.success();
    }

    @GetMapping("/tags")
    public ApiResponse<List<TodoTagDTO>> getTags() {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.getTags(userId));
    }

    @PostMapping("/tags")
    public ApiResponse<TodoTagDTO> createTag(@Valid @RequestBody CreateTodoTagRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.createTag(userId, request));
    }

    @PutMapping("/tags/{id}")
    public ApiResponse<TodoTagDTO> updateTag(@PathVariable Long id, @Valid @RequestBody UpdateTodoTagRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.updateTag(userId, id, request));
    }

    @DeleteMapping("/tags/{id}")
    public ApiResponse<Void> deleteTag(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        todoService.deleteTag(userId, id);
        return ApiResponse.success();
    }

    @GetMapping("/tasks")
    public ApiResponse<List<TodoTaskDTO>> getTasks(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false, defaultValue = "all") String status,
            @RequestParam(required = false, defaultValue = "all") String timeFilter,
            @RequestParam(required = false, defaultValue = "all") String priority,
            @RequestParam(required = false) Long listId,
            @RequestParam(required = false) Long tagId,
            @RequestParam(required = false, defaultValue = "custom") String sortBy,
            @RequestParam(required = false, defaultValue = "asc") String sortOrder
    ) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.getTasks(
                userId, keyword, status, timeFilter, priority, listId, tagId, sortBy, sortOrder));
    }

    @GetMapping("/tasks/{id}")
    public ApiResponse<TodoTaskDTO> getTaskById(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.getTaskById(userId, id));
    }

    @PostMapping("/tasks")
    public ApiResponse<TodoTaskDTO> createTask(@Valid @RequestBody CreateTodoTaskRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.createTask(userId, request));
    }

    @PutMapping("/tasks/{id}")
    public ApiResponse<TodoTaskDTO> updateTask(@PathVariable Long id, @Valid @RequestBody UpdateTodoTaskRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.updateTask(userId, id, request));
    }

    @PatchMapping("/tasks/{id}/status")
    public ApiResponse<TodoTaskDTO> updateTaskStatus(@PathVariable Long id,
                                                     @Valid @RequestBody UpdateTodoTaskStatusRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.updateTaskStatus(userId, id, request));
    }

    @DeleteMapping("/tasks/{id}")
    public ApiResponse<Void> deleteTask(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        todoService.deleteTask(userId, id);
        return ApiResponse.success();
    }

    @PostMapping("/tasks/batch")
    public ApiResponse<BatchOperationResultDTO> batchOperateTasks(@Valid @RequestBody BatchTodoTaskRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.batchOperateTasks(userId, request));
    }

    @PostMapping("/tasks/reorder")
    public ApiResponse<Void> reorderTasks(@Valid @RequestBody ReorderRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        todoService.reorderTasks(userId, request);
        return ApiResponse.success();
    }

    @PostMapping("/tasks/{taskId}/subtasks")
    public ApiResponse<TodoSubtaskDTO> createSubtask(@PathVariable Long taskId,
                                                     @Valid @RequestBody CreateTodoSubtaskRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.createSubtask(userId, taskId, request));
    }

    @PutMapping("/subtasks/{id}")
    public ApiResponse<TodoSubtaskDTO> updateSubtask(@PathVariable Long id,
                                                     @Valid @RequestBody UpdateTodoSubtaskRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.updateSubtask(userId, id, request));
    }

    @PatchMapping("/subtasks/{id}/status")
    public ApiResponse<TodoSubtaskDTO> updateSubtaskStatus(@PathVariable Long id,
                                                           @Valid @RequestBody UpdateTodoSubtaskStatusRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.updateSubtaskStatus(userId, id, request));
    }

    @DeleteMapping("/subtasks/{id}")
    public ApiResponse<Void> deleteSubtask(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUserId();
        todoService.deleteSubtask(userId, id);
        return ApiResponse.success();
    }

    @PostMapping("/tasks/{taskId}/subtasks/reorder")
    public ApiResponse<Void> reorderSubtasks(@PathVariable Long taskId, @Valid @RequestBody ReorderRequest request) {
        Long userId = securityUtils.getCurrentUserId();
        todoService.reorderSubtasks(userId, taskId, request);
        return ApiResponse.success();
    }

    @GetMapping("/stats")
    public ApiResponse<TodoStatsDTO> getTodoStats() {
        Long userId = securityUtils.getCurrentUserId();
        return ApiResponse.success(todoService.getStats(userId));
    }
}

