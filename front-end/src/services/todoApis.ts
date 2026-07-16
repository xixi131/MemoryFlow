import request from './api';

export type TodoTaskStatus = 'todo' | 'completed';
export type TodoPriority = 'high' | 'medium' | 'low' | 'none';
export type TodoTimeFilter = 'all' | 'today' | 'tomorrow' | 'week' | 'no-date' | 'overdue';
export type TodoSortBy = 'custom' | 'created' | 'due' | 'priority';
export type TodoSortOrder = 'asc' | 'desc';

export interface TodoListDTO {
    id: number;
    name: string;
    color: string;
    icon: string;
    sortOrder: number;
    isDefault: boolean;
}

export interface TodoTagDTO {
    id: number;
    name: string;
    color: string;
}

export interface TodoSubtaskDTO {
    id: number;
    taskId: number;
    title: string;
    status: TodoTaskStatus;
    sortOrder: number;
    completedAt?: string | null;
}

export interface TodoTaskDTO {
    id: number;
    listId?: number | null;
    title: string;
    descriptionMd?: string | null;
    status: TodoTaskStatus;
    priority: TodoPriority;
    dueDate?: string | null;
    dueTime?: string | null;
    sortOrder?: number | null;
    completedAt?: string | null;
    createdAt?: string | null;
    updatedAt?: string | null;
    overdue?: boolean;
    dueToday?: boolean;
    dueTomorrow?: boolean;
    subtaskTotal?: number;
    subtaskCompleted?: number;
    subtaskProgress?: number;
    tags: TodoTagDTO[];
    subtasks: TodoSubtaskDTO[];
}

export interface TodoStatsDTO {
    totalTasks: number;
    pendingTasks: number;
    completedTasks: number;
    dueToday: number;
    dueTomorrow: number;
    overdueTasks: number;
    highPriorityPending: number;
    createdThisWeek: number;
    completedThisWeek: number;
    weekCompletionRate: number;
}

export interface TodoTaskQuery {
    keyword?: string;
    status?: 'all' | TodoTaskStatus;
    timeFilter?: TodoTimeFilter;
    priority?: 'all' | TodoPriority;
    listId?: number;
    tagId?: number;
    sortBy?: TodoSortBy;
    sortOrder?: TodoSortOrder;
}

export interface CreateTodoTaskPayload {
    title: string;
    descriptionMd?: string;
    priority?: TodoPriority;
    dueDate?: string;
    dueTime?: string;
    sortOrder?: number;
    tagIds?: number[];
}

export interface UpdateTodoTaskPayload {
    title?: string;
    descriptionMd?: string;
    listId?: number | null;
    status?: TodoTaskStatus;
    priority?: TodoPriority;
    dueDate?: string;
    dueTime?: string;
    sortOrder?: number;
    tagIds?: number[];
}

export interface BatchTodoTaskPayload {
    taskIds: number[];
    action: 'complete' | 'uncomplete' | 'delete' | 'move-list' | 'set-priority';
    listId?: number | null;
    priority?: TodoPriority;
}

const cleanParams = (params: Record<string, unknown>) => {
    const result: Record<string, unknown> = {};
    Object.keys(params).forEach((key) => {
        const value = params[key];
        if (value === undefined || value === null || value === '') return;
        result[key] = value;
    });
    return result;
};

const todoApis = {
    getLists: () => request({ url: '/todos/lists', method: 'get' }),

    createList: (data: { name: string; color?: string; icon?: string }) =>
        request({ url: '/todos/lists', method: 'post', data }),

    updateList: (id: number, data: { name: string; color?: string; icon?: string; sortOrder?: number }) =>
        request({ url: `/todos/lists/${id}`, method: 'put', data }),

    deleteList: (id: number) => request({ url: `/todos/lists/${id}`, method: 'delete' }),

    getTags: () => request({ url: '/todos/tags', method: 'get' }),

    createTag: (data: { name: string; color?: string }) =>
        request({ url: '/todos/tags', method: 'post', data }),

    updateTag: (id: number, data: { name: string; color?: string }) =>
        request({ url: `/todos/tags/${id}`, method: 'put', data }),

    deleteTag: (id: number) => request({ url: `/todos/tags/${id}`, method: 'delete' }),

    getTasks: (params: TodoTaskQuery = {}) =>
        request({ url: '/todos/tasks', method: 'get', params: cleanParams(params as Record<string, unknown>) }),

    getTaskById: (id: number) => request({ url: `/todos/tasks/${id}`, method: 'get' }),

    createTask: (data: CreateTodoTaskPayload) => request({ url: '/todos/tasks', method: 'post', data }),

    updateTask: (id: number, data: UpdateTodoTaskPayload) =>
        request({ url: `/todos/tasks/${id}`, method: 'put', data }),

    updateTaskStatus: (id: number, completed: boolean) =>
        request({ url: `/todos/tasks/${id}/status`, method: 'patch', data: { completed } }),

    deleteTask: (id: number) => request({ url: `/todos/tasks/${id}`, method: 'delete' }),

    batchOperateTasks: (data: BatchTodoTaskPayload) =>
        request({ url: '/todos/tasks/batch', method: 'post', data }),

    reorderTasks: (ids: number[]) => request({ url: '/todos/tasks/reorder', method: 'post', data: { ids } }),

    createSubtask: (taskId: number, data: { title: string }) =>
        request({ url: `/todos/tasks/${taskId}/subtasks`, method: 'post', data }),

    updateSubtask: (id: number, data: { title?: string; status?: TodoTaskStatus; sortOrder?: number }) =>
        request({ url: `/todos/subtasks/${id}`, method: 'put', data }),

    updateSubtaskStatus: (id: number, completed: boolean) =>
        request({ url: `/todos/subtasks/${id}/status`, method: 'patch', data: { completed } }),

    deleteSubtask: (id: number) => request({ url: `/todos/subtasks/${id}`, method: 'delete' }),

    reorderSubtasks: (taskId: number, ids: number[]) =>
        request({ url: `/todos/tasks/${taskId}/subtasks/reorder`, method: 'post', data: { ids } }),

    getStats: () => request({ url: '/todos/stats', method: 'get' })
};

export default todoApis;
