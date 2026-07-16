
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { message } from '../components/Message';
import { ModalWrapper } from '../components/Modals';
import todoApis, {
    CreateTodoTaskPayload,
    TodoListDTO,
    TodoPriority,
    TodoSortBy,
    TodoSortOrder,
    TodoStatsDTO,
    TodoTagDTO,
    TodoTaskDTO,
    TodoTimeFilter
} from '../services/todoApis';

type TodoQueryState = {
    keyword: string;
    status: 'all' | 'todo' | 'completed';
    timeFilter: TodoTimeFilter;
    priority: 'all' | TodoPriority;
    listId?: number;
    tagId?: number;
    sortBy: TodoSortBy;
    sortOrder: TodoSortOrder;
};

type TaskEditorDraft = {
    id: number;
    title: string;
    descriptionMd: string;
    listId: number | null;
    priority: TodoPriority;
    dueDate: string;
    dueTime: string;
    tagIds: number[];
};

type CreateDraft = {
    title: string;
    descriptionMd: string;
    priority: TodoPriority;
    dueDate: string;
    dueTime: string;
    tagIds: number[];
};

const DEFAULT_QUERY: TodoQueryState = {
    keyword: '',
    status: 'all',
    timeFilter: 'all',
    priority: 'all',
    sortBy: 'custom',
    sortOrder: 'asc'
};

const EMPTY_STATS: TodoStatsDTO = {
    totalTasks: 0,
    pendingTasks: 0,
    completedTasks: 0,
    dueToday: 0,
    dueTomorrow: 0,
    overdueTasks: 0,
    highPriorityPending: 0,
    createdThisWeek: 0,
    completedThisWeek: 0,
    weekCompletionRate: 0
};

const PRIORITY_LABEL: Record<TodoPriority, string> = {
    high: '紧急',
    medium: '重要',
    low: '普通',
    none: '未设置'
};

const PRIORITY_VALUES: TodoPriority[] = ['high', 'medium', 'low', 'none'];

const PRIORITY_CLASS: Record<TodoPriority, string> = {
    high: 'bg-red-500/15 text-red-500 border-red-500/25',
    medium: 'bg-amber-500/15 text-amber-500 border-amber-500/25',
    low: 'bg-blue-500/15 text-blue-500 border-blue-500/25',
    none: 'bg-slate-500/15 text-slate-500 border-slate-500/25'
};

const TIME_OPTIONS: Array<{ value: TodoTimeFilter; label: string }> = [
    { value: 'all', label: '全部' },
    { value: 'today', label: '今天' },
    { value: 'tomorrow', label: '明天' },
    { value: 'week', label: '本周' },
    { value: 'no-date', label: '无日期' },
    { value: 'overdue', label: '已过期' }
];

const SORT_OPTIONS: Array<{ value: TodoSortBy; label: string }> = [
    { value: 'custom', label: '自定义' },
    { value: 'created', label: '创建时间' },
    { value: 'due', label: '截止时间' },
    { value: 'priority', label: '优先级' }
];

const TASK_STATUS_OPTIONS: SelectOption[] = [
    { value: 'all', label: '状态：全部' },
    { value: 'todo', label: '状态：进行中' },
    { value: 'completed', label: '状态：已完成' }
];

const TASK_PRIORITY_FILTER_OPTIONS: SelectOption[] = [
    { value: 'all', label: '优先级：全部' },
    ...PRIORITY_VALUES.map((value) => ({ value, label: `优先级：${PRIORITY_LABEL[value]}` }))
];

const PRIORITY_PICKER_OPTIONS: SelectOption[] = PRIORITY_VALUES.map((value) => ({
    value,
    label: PRIORITY_LABEL[value]
}));

const SORT_ORDER_OPTIONS: SelectOption[] = [
    { value: 'asc', label: '升序' },
    { value: 'desc', label: '降序' }
];

const panelClass =
    'bg-white dark:bg-surface-dark border border-slate-200/80 dark:border-white/5 shadow-[0_12px_30px_rgba(15,23,42,0.08),0_2px_8px_rgba(15,23,42,0.05)] dark:shadow-[0_14px_44px_rgba(0,0,0,0.48),0_4px_14px_rgba(0,0,0,0.24)]';

const softClass =
    'bg-slate-100/75 dark:bg-[#0F172A]/70 border border-slate-200/70 dark:border-white/10';

const inputClass =
    'w-full rounded-lg border border-slate-300 bg-white px-4 py-3 text-slate-900 outline-none transition-colors placeholder:text-slate-500 hover:border-slate-400 focus:border-primary focus:ring-2 focus:ring-primary/25 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 disabled:opacity-70 dark:border-slate-600 dark:bg-[#111827] dark:text-white dark:placeholder:text-slate-400 dark:hover:border-slate-500 dark:focus:border-primary dark:disabled:bg-[#0B1220] dark:disabled:text-slate-400';

const selectClass =
    'rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 outline-none transition-colors hover:border-slate-400 focus:border-primary focus:ring-2 focus:ring-primary/25 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 disabled:opacity-70 dark:border-slate-600 dark:bg-[#111827] dark:text-white dark:hover:border-slate-500 dark:focus:border-primary dark:disabled:bg-[#0B1220] dark:disabled:text-slate-400';

const quickCreateInputClass =
    'w-full px-4 py-3 bg-slate-200/95 dark:bg-[#16263b]/88 text-slate-900 dark:text-white border-0 outline-none transition-colors rounded-2xl shadow-[inset_0_1px_1px_rgba(15,23,42,0.09)] dark:shadow-[inset_0_1px_2px_rgba(0,0,0,0.35)] focus:ring-2 focus:ring-primary/25';

type SelectOption = {
    value: string;
    label: string;
};

const ProjectSelect: React.FC<{
    value: string;
    options: SelectOption[];
    onChange: (value: string) => void;
    className?: string;
}> = ({ value, options, onChange, className }) => {
    const [open, setOpen] = useState(false);
    const rootRef = useRef<HTMLDivElement | null>(null);
    const selected = options.find((opt) => opt.value === value) || options[0];

    useEffect(() => {
        const handleOutsideClick = (event: MouseEvent) => {
            const node = event.target as Node;
            if (!rootRef.current || rootRef.current.contains(node)) return;
            setOpen(false);
        };
        document.addEventListener('mousedown', handleOutsideClick);
        return () => document.removeEventListener('mousedown', handleOutsideClick);
    }, []);

    return (
        <div ref={rootRef} className={`relative ${className || ''}`}>
            <button
                type="button"
                className={`w-full text-left ${selectClass} inline-flex items-center justify-between`}
                onClick={() => setOpen((prev) => !prev)}
                aria-haspopup="listbox"
                aria-expanded={open}
            >
                <span className="truncate">{selected?.label || ''}</span>
                <span className={`material-symbols-outlined text-[20px] text-slate-500 dark:text-text-secondary transition-transform ${open ? 'rotate-180' : ''}`}>
                    expand_more
                </span>
            </button>
            {open && (
                <div
                    className="absolute z-40 mt-2 w-full overflow-hidden bg-white dark:bg-surface-dark border border-slate-200 dark:border-white/10 shadow-[0_14px_40px_rgba(15,23,42,0.16)]"
                    role="listbox"
                    style={continuous(8)}
                >
                    {options.map((option) => {
                        const active = option.value === value;
                        return (
                            <button
                                key={option.value}
                                type="button"
                                role="option"
                                aria-selected={active}
                                className={`w-full text-left px-4 py-3 text-base transition-colors ${
                                    active
                                        ? 'bg-primary text-white font-bold'
                                        : 'text-slate-800 dark:text-white hover:bg-slate-100 dark:hover:bg-white/10'
                                }`}
                                onClick={() => {
                                    onChange(option.value);
                                    setOpen(false);
                                }}
                            >
                                {option.label}
                            </button>
                        );
                    })}
                </div>
            )}
        </div>
    );
};

const ProjectNativePicker: React.FC<{
    type: 'date' | 'time';
    value: string;
    placeholder: string;
    onChange: (value: string) => void;
    disabled?: boolean;
    className?: string;
}> = ({ type, value, placeholder, onChange, disabled = false, className }) => {
    const inputRef = useRef<HTMLInputElement | null>(null);

    const openPicker = () => {
        if (disabled) return;
        const input = inputRef.current as (HTMLInputElement & { showPicker?: () => void }) | null;
        if (!input) return;
        if (typeof input.showPicker === 'function') {
            input.showPicker();
            return;
        }
        input.focus();
        input.click();
    };

    const displayValue = useMemo(() => {
        if (!value) return placeholder;
        if (type === 'date') return value.replace(/-/g, '/');
        return value;
    }, [type, value, placeholder]);

    return (
        <div className={`relative ${className || ''}`}>
            <input
                ref={inputRef}
                type={type}
                value={value}
                onChange={(e) => onChange(e.target.value)}
                disabled={disabled}
                className="absolute inset-0 opacity-0 pointer-events-none"
                tabIndex={-1}
            />
            <button
                type="button"
                onClick={openPicker}
                disabled={disabled}
                className={`w-full ${selectClass} inline-flex items-center justify-between`}
            >
                <span className={`${value ? 'text-slate-900 dark:text-white' : 'text-slate-400 dark:text-text-secondary'}`}>
                    {displayValue}
                </span>
                <span className="material-symbols-outlined text-[20px] text-slate-500 dark:text-text-secondary">
                    expand_more
                </span>
            </button>
        </div>
    );
};

const QuickCreateModal: React.FC<{
    title: string;
    placeholder: string;
    value: string;
    confirmText: string;
    onChange: (value: string) => void;
    onCancel: () => void;
    onConfirm: () => void;
}> = ({ title, placeholder, value, confirmText, onChange, onCancel, onConfirm }) => {
    return (
        <ModalWrapper onClose={onCancel} className="glass-panel max-w-md rounded-3xl shadow-lg">
            <div className="p-6 flex flex-col gap-5">
                <div className="flex items-center justify-between">
                    <h3 className="text-xl font-bold text-slate-900 dark:text-white">{title}</h3>
                    <button
                        type="button"
                        onClick={onCancel}
                        className="size-9 rounded-full flex items-center justify-center text-slate-500 hover:bg-slate-200 dark:text-text-secondary dark:hover:text-white dark:hover:bg-white/10 transition-colors"
                    >
                        <span className="material-symbols-outlined text-[20px]">close</span>
                    </button>
                </div>
                <input
                    autoFocus
                    value={value}
                    onChange={(e) => onChange(e.target.value)}
                    onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                            e.preventDefault();
                            onConfirm();
                        }
                    }}
                    placeholder={placeholder}
                    className={quickCreateInputClass}
                />
                <div className="flex justify-end gap-2">
                    <button
                        type="button"
                        onClick={onCancel}
                        className="px-4 py-2 rounded-xl border border-slate-300 dark:border-white/10 text-slate-500 dark:text-text-secondary"
                    >
                        取消
                    </button>
                    <button
                        type="button"
                        onClick={onConfirm}
                        className="px-4 py-2 rounded-xl bg-primary text-white font-bold hover:bg-blue-600 transition-colors"
                    >
                        {confirmText}
                    </button>
                </div>
            </div>
        </ModalWrapper>
    );
};

const continuous = (radius = 28) => ({
    borderRadius: radius,
    borderCurve: 'continuous'
} as React.CSSProperties & Record<string, string>);

const continuousLeft = (radius = 32) => ({
    borderTopLeftRadius: radius,
    borderBottomLeftRadius: radius,
    borderCurve: 'continuous'
} as React.CSSProperties & Record<string, string>);

const toDateInput = (value?: string | null) => (value ? String(value).slice(0, 10) : '');

const toTimeInput = (value?: string | null) => {
    if (!value) return '';
    const parts = String(value).split(':');
    if (parts.length < 2) return '';
    return `${parts[0]}:${parts[1]}`;
};

const compactMarkdown = (value?: string | null) =>
    (value || '')
        .replace(/```[\s\S]*?```/g, ' ')
        .replace(/[#>*_\-\[\]\(\)`]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

const colorByText = (text: string) => {
    const palette = ['#3A7FF1', '#22C55E', '#EF4444', '#F59E0B', '#8B5CF6', '#14B8A6', '#06B6D4'];
    let hash = 0;
    for (let i = 0; i < text.length; i += 1) {
        hash = (hash << 5) - hash + text.charCodeAt(i);
        hash |= 0;
    }
    return palette[Math.abs(hash) % palette.length];
};

const reorderById = <T extends { id: number }>(items: T[], fromId: number, toId: number) => {
    const from = items.findIndex((item) => item.id === fromId);
    const to = items.findIndex((item) => item.id === toId);
    if (from < 0 || to < 0 || from === to) return items;
    const next = [...items];
    const [moved] = next.splice(from, 1);
    next.splice(to, 0, moved);
    return next;
};

const buildDueLabel = (task: TodoTaskDTO) => {
    if (!task.dueDate) return '无日期';
    const date = String(task.dueDate).slice(0, 10);
    const time = toTimeInput(task.dueTime);
    return time ? `${date} ${time}` : date;
};

const TodoPage: React.FC = () => {
    const [lists, setLists] = useState<TodoListDTO[]>([]);
    const [tags, setTags] = useState<TodoTagDTO[]>([]);
    const [tasks, setTasks] = useState<TodoTaskDTO[]>([]);
    const [stats, setStats] = useState<TodoStatsDTO>(EMPTY_STATS);
    const [query, setQuery] = useState<TodoQueryState>(DEFAULT_QUERY);
    const [searchInput, setSearchInput] = useState('');
    const [loading, setLoading] = useState(false);
    const [metaLoading, setMetaLoading] = useState(false);
    const [saving, setSaving] = useState(false);

    const [createDraft, setCreateDraft] = useState<CreateDraft>({
        title: '',
        descriptionMd: '',
        priority: 'medium',
        dueDate: '',
        dueTime: '',
        tagIds: []
    });

    const [selectedTaskIds, setSelectedTaskIds] = useState<number[]>([]);
    const [drawerTaskId, setDrawerTaskId] = useState<number | null>(null);
    const [drawerDraft, setDrawerDraft] = useState<TaskEditorDraft | null>(null);
    const [newSubtaskTitle, setNewSubtaskTitle] = useState('');
    const [draggingTaskId, setDraggingTaskId] = useState<number | null>(null);
    const [isDrawerMounted, setIsDrawerMounted] = useState(false);
    const [isDrawerVisible, setIsDrawerVisible] = useState(false);
    const drawerCloseTimerRef = useRef<number | null>(null);
    const drawerOpenRafRef = useRef<number | null>(null);
    const drawerTaskIdRef = useRef<number | null>(null);

    const [showTagCreateModal, setShowTagCreateModal] = useState(false);
    const [tagNameDraft, setTagNameDraft] = useState('');

    const drawerTask = useMemo(
        () => tasks.find((task) => task.id === drawerTaskId) || null,
        [tasks, drawerTaskId]
    );

    const allVisibleSelected = tasks.length > 0 && tasks.every((task) => selectedTaskIds.includes(task.id));
    const canDragSort = query.sortBy === 'custom';
    const toEditorDraft = useCallback(
        (task: TodoTaskDTO): TaskEditorDraft => ({
            id: task.id,
            title: task.title,
            descriptionMd: task.descriptionMd || '',
            listId: task.listId ?? null,
            priority: task.priority || 'none',
            dueDate: toDateInput(task.dueDate),
            dueTime: toTimeInput(task.dueTime),
            tagIds: (task.tags || []).map((tag) => tag.id)
        }),
        []
    );
    const openDrawer = useCallback(
        (task: TodoTaskDTO) => {
            if (drawerCloseTimerRef.current) {
                window.clearTimeout(drawerCloseTimerRef.current);
                drawerCloseTimerRef.current = null;
            }
            if (drawerOpenRafRef.current) {
                window.cancelAnimationFrame(drawerOpenRafRef.current);
                drawerOpenRafRef.current = null;
            }
            setDrawerTaskId(task.id);
            setDrawerDraft(toEditorDraft(task));
            setIsDrawerMounted(true);
            setIsDrawerVisible(false);
            drawerOpenRafRef.current = window.requestAnimationFrame(() => {
                drawerOpenRafRef.current = window.requestAnimationFrame(() => {
                    setIsDrawerVisible(true);
                });
            });
        },
        [toEditorDraft]
    );
    const closeDrawer = useCallback(() => {
        if (drawerOpenRafRef.current) {
            window.cancelAnimationFrame(drawerOpenRafRef.current);
            drawerOpenRafRef.current = null;
        }
        setIsDrawerVisible(false);
        if (drawerCloseTimerRef.current) {
            window.clearTimeout(drawerCloseTimerRef.current);
        }
        drawerCloseTimerRef.current = window.setTimeout(() => {
            setIsDrawerMounted(false);
            setDrawerTaskId(null);
        }, 260);
    }, []);
    const orderHint =
        query.sortBy === 'created'
            ? query.sortOrder === 'asc'
                ? '升序：创建时间从最早到最新'
                : '降序：创建时间从最新到最早'
            : query.sortBy === 'due'
            ? query.sortOrder === 'asc'
                ? '升序：截止时间从近到远'
                : '降序：截止时间从远到近'
            : query.sortBy === 'priority'
            ? query.sortOrder === 'asc'
                ? '升序：优先级从低到高'
                : '降序：优先级从高到低'
            : '自定义排序下可拖拽任务调整顺序';

    useEffect(() => {
        drawerTaskIdRef.current = drawerTaskId;
    }, [drawerTaskId]);

    useEffect(() => {
        return () => {
            if (drawerCloseTimerRef.current) {
                window.clearTimeout(drawerCloseTimerRef.current);
                drawerCloseTimerRef.current = null;
            }
            if (drawerOpenRafRef.current) {
                window.cancelAnimationFrame(drawerOpenRafRef.current);
                drawerOpenRafRef.current = null;
            }
        };
    }, []);

    const loadLists = useCallback(async () => {
        const res: any = await todoApis.getLists();
        if (res.code === 200) setLists(Array.isArray(res.data) ? res.data : []);
    }, []);

    const loadTags = useCallback(async () => {
        const res: any = await todoApis.getTags();
        if (res.code === 200) setTags(Array.isArray(res.data) ? res.data : []);
    }, []);

    const loadStats = useCallback(async () => {
        const res: any = await todoApis.getStats();
        if (res.code === 200 && res.data) setStats(res.data);
    }, []);

    const loadTasks = useCallback(async (showLoading = true) => {
        if (showLoading) setLoading(true);
        try {
            const res: any = await todoApis.getTasks({
                keyword: query.keyword || undefined,
                status: query.status,
                timeFilter: query.timeFilter,
                priority: query.priority,
                listId: query.listId,
                tagId: query.tagId,
                sortBy: query.sortBy,
                sortOrder: query.sortOrder
            });
            if (res.code !== 200) {
                message.error(res.message || '任务加载失败');
                return;
            }
            const next: TodoTaskDTO[] = Array.isArray(res.data) ? res.data : [];
            setTasks(next);
            setSelectedTaskIds((prev) => prev.filter((id) => next.some((task) => task.id === id)));
            const activeDrawerTaskId = drawerTaskIdRef.current;
            if (activeDrawerTaskId && !next.some((task) => task.id === activeDrawerTaskId)) {
                closeDrawer();
            }
        } catch (error) {
            console.error(error);
            message.error('任务加载失败');
        } finally {
            if (showLoading) setLoading(false);
        }
    }, [query, closeDrawer]);

    const loadMeta = useCallback(async () => {
        setMetaLoading(true);
        try {
            await Promise.all([loadLists(), loadTags(), loadStats()]);
        } catch (error) {
            console.error(error);
            message.error('基础数据加载失败');
        } finally {
            setMetaLoading(false);
        }
    }, [loadLists, loadTags, loadStats]);

    const refreshAfterMutation = useCallback(
        async (refreshMeta = false) => {
            if (refreshMeta) await loadMeta();
            await Promise.all([loadTasks(), loadStats()]);
        },
        [loadMeta, loadStats, loadTasks]
    );

    useEffect(() => {
        loadMeta();
    }, [loadMeta]);

    useEffect(() => {
        loadTasks();
    }, [loadTasks]);

    useEffect(() => {
        const timer = window.setTimeout(() => {
            setQuery((prev) => ({ ...prev, keyword: searchInput.trim() }));
        }, 220);
        return () => window.clearTimeout(timer);
    }, [searchInput]);

    useEffect(() => {
        if (!drawerTaskId) {
            setDrawerDraft(null);
        }
    }, [drawerTaskId]);

    const handleCreateTask = async () => {
        const title = createDraft.title.trim();
        if (!title) {
            message.warning('请输入任务标题');
            return;
        }
        const payload: CreateTodoTaskPayload = {
            title,
            descriptionMd: createDraft.descriptionMd,
            priority: createDraft.priority,
            dueDate: createDraft.dueDate || undefined,
            dueTime: createDraft.dueDate ? createDraft.dueTime || undefined : undefined,
            tagIds: createDraft.tagIds
        };
        setSaving(true);
        try {
            const res: any = await todoApis.createTask(payload);
            if (res.code === 200) {
                message.success('任务已创建');
                setCreateDraft((prev) => ({ ...prev, title: '', descriptionMd: '' }));
                await refreshAfterMutation();
            } else {
                message.error(res.message || '创建失败');
            }
        } catch (error) {
            console.error(error);
            message.error('创建失败');
        } finally {
            setSaving(false);
        }
    };

    const handleToggleTask = async (task: TodoTaskDTO) => {
        const nextCompleted = task.status !== 'completed';
        const prevStatus = task.status;
        setTasks((prev) =>
            prev.map((item) =>
                item.id === task.id
                    ? {
                          ...item,
                          status: nextCompleted ? 'completed' : 'todo'
                      }
                    : item
            )
        );
        try {
            let res: any = null;
            try {
                res = await todoApis.updateTaskStatus(task.id, nextCompleted);
            } catch (_e) {
                res = null;
            }

            let updatedTask: any = null;
            if (!res || res.code !== 200) {
                const fallback: any = await todoApis.updateTask(task.id, {
                    status: nextCompleted ? 'completed' : 'todo'
                });
                if (!fallback || fallback.code !== 200) {
                    throw new Error(fallback?.message || res?.message || '状态更新失败');
                }
                updatedTask = fallback.data || null;
            } else {
                updatedTask = res.data || null;
            }

            const finalStatus = (updatedTask?.status as 'todo' | 'completed' | undefined) || (nextCompleted ? 'completed' : 'todo');
            const shouldRemoveByFilter =
                (query.status === 'todo' && finalStatus === 'completed') ||
                (query.status === 'completed' && finalStatus === 'todo');

            setTasks((prev) => {
                if (shouldRemoveByFilter) {
                    return prev.filter((item) => item.id !== task.id);
                }
                return prev.map((item) =>
                    item.id === task.id
                        ? {
                              ...item,
                              ...(updatedTask || {}),
                              status: finalStatus
                          }
                        : item
                );
            });

            if (shouldRemoveByFilter) {
                setSelectedTaskIds((prev) => prev.filter((id) => id !== task.id));
                if (drawerTaskId === task.id) {
                    closeDrawer();
                }
            }

            await loadStats();
        } catch (error) {
            console.error(error);
            setTasks((prev) =>
                prev.map((item) =>
                    item.id === task.id
                        ? {
                              ...item,
                              status: prevStatus
                          }
                        : item
                )
            );
            message.error('状态更新失败');
        }
    };

    const handleDeleteTask = async (task: TodoTaskDTO) => {
        if (!window.confirm(`确定删除任务「${task.title}」吗？`)) return;
        try {
            const res: any = await todoApis.deleteTask(task.id);
            if (res.code === 200) {
                message.success('任务已删除');
                if (drawerTaskId === task.id) closeDrawer();
                await refreshAfterMutation();
            } else {
                message.error(res.message || '删除失败');
            }
        } catch (error) {
            console.error(error);
            message.error('删除失败');
        }
    };

    const runBatchAction = async (action: 'complete' | 'uncomplete' | 'delete') => {
        if (selectedTaskIds.length === 0) return;
        if (action === 'delete' && !window.confirm(`确认删除已选中的 ${selectedTaskIds.length} 项任务吗？`)) return;
        try {
            const res: any = await todoApis.batchOperateTasks({
                taskIds: selectedTaskIds,
                action
            });
            if (res.code === 200) {
                message.success(`已处理 ${res.data?.affectedCount || selectedTaskIds.length} 项任务`);
                setSelectedTaskIds([]);
                await refreshAfterMutation();
            } else {
                message.error(res.message || '批量操作失败');
            }
        } catch (error) {
            console.error(error);
            message.error('批量操作失败');
        }
    };

    const handleDragDrop = async (targetId: number) => {
        if (!canDragSort || draggingTaskId == null || draggingTaskId === targetId) return;
        const reordered = reorderById(tasks, draggingTaskId, targetId);
        setTasks(reordered);
        setDraggingTaskId(null);
        try {
            const res: any = await todoApis.reorderTasks(reordered.map((task) => task.id));
            if (res.code !== 200) {
                message.error(res.message || '排序失败，已恢复');
                await loadTasks();
            }
        } catch (error) {
            console.error(error);
            message.error('排序失败，已恢复');
            await loadTasks();
        }
    };

    const handleDeleteList = async (list: TodoListDTO) => {
        if (!window.confirm(`确认删除清单「${list.name}」吗？`)) return;
        try {
            const res: any = await todoApis.deleteList(list.id);
            if (res.code === 200) {
                message.success('清单已删除');
                setQuery((prev) => ({ ...prev, listId: prev.listId === list.id ? undefined : prev.listId }));
                await refreshAfterMutation(true);
            } else {
                message.error(res.message || '清单删除失败');
            }
        } catch (error) {
            console.error(error);
            message.error('清单删除失败');
        }
    };

    const openCreateTagModal = () => {
        setTagNameDraft('');
        setShowTagCreateModal(true);
    };

    const handleCreateTag = async () => {
        const name = tagNameDraft.trim();
        if (!name) {
            message.warning('请输入标签名称');
            return;
        }
        try {
            const res: any = await todoApis.createTag({
                name,
                color: colorByText(name)
            });
            if (res.code === 200) {
                message.success('标签已创建');
                setShowTagCreateModal(false);
                await refreshAfterMutation(true);
            } else {
                message.error(res.message || '标签创建失败');
            }
        } catch (error) {
            console.error(error);
            message.error('标签创建失败');
        }
    };

    const handleDeleteTag = async (tag: TodoTagDTO) => {
        if (!window.confirm(`确认删除标签「${tag.name}」吗？`)) return;
        try {
            const res: any = await todoApis.deleteTag(tag.id);
            if (res.code === 200) {
                message.success('标签已删除');
                setQuery((prev) => ({ ...prev, tagId: prev.tagId === tag.id ? undefined : prev.tagId }));
                await refreshAfterMutation(true);
            } else {
                message.error(res.message || '标签删除失败');
            }
        } catch (error) {
            console.error(error);
            message.error('标签删除失败');
        }
    };

    const toggleCreateTag = (tagId: number) => {
        setCreateDraft((prev) => {
            const has = prev.tagIds.includes(tagId);
            return { ...prev, tagIds: has ? prev.tagIds.filter((id) => id !== tagId) : [...prev.tagIds, tagId] };
        });
    };

    const toggleDrawerTag = (tagId: number) => {
        setDrawerDraft((prev) => {
            if (!prev) return prev;
            const has = prev.tagIds.includes(tagId);
            return { ...prev, tagIds: has ? prev.tagIds.filter((id) => id !== tagId) : [...prev.tagIds, tagId] };
        });
    };

    const handleSaveDrawer = async () => {
        if (!drawerDraft) return;
        const title = drawerDraft.title.trim();
        if (!title) {
            message.warning('任务标题不能为空');
            return;
        }
        setSaving(true);
        try {
            const res: any = await todoApis.updateTask(drawerDraft.id, {
                title,
                descriptionMd: drawerDraft.descriptionMd || '',
                listId: drawerDraft.listId,
                priority: drawerDraft.priority,
                dueDate: drawerDraft.dueDate || '',
                dueTime: drawerDraft.dueTime || '',
                tagIds: drawerDraft.tagIds
            });
            if (res.code === 200) {
                message.success('任务已更新');
                await refreshAfterMutation();
            } else {
                message.error(res.message || '保存失败');
            }
        } catch (error) {
            console.error(error);
            message.error('保存失败');
        } finally {
            setSaving(false);
        }
    };

    const handleCreateSubtask = async () => {
        if (!drawerTask || !newSubtaskTitle.trim()) return;
        try {
            const res: any = await todoApis.createSubtask(drawerTask.id, { title: newSubtaskTitle.trim() });
            if (res.code === 200) {
                setNewSubtaskTitle('');
                await refreshAfterMutation();
            } else {
                message.error(res.message || '子任务创建失败');
            }
        } catch (error) {
            console.error(error);
            message.error('子任务创建失败');
        }
    };

    const handleToggleSubtask = async (subtaskId: number, completed: boolean) => {
        try {
            const res: any = await todoApis.updateSubtaskStatus(subtaskId, !completed);
            if (res.code === 200) {
                await refreshAfterMutation();
            } else {
                message.error(res.message || '子任务状态更新失败');
            }
        } catch (error) {
            console.error(error);
            message.error('子任务状态更新失败');
        }
    };

    const handleDeleteSubtask = async (subtaskId: number) => {
        if (!window.confirm('确认删除该子任务吗？')) return;
        try {
            const res: any = await todoApis.deleteSubtask(subtaskId);
            if (res.code === 200) {
                await refreshAfterMutation();
            } else {
                message.error(res.message || '删除失败');
            }
        } catch (error) {
            console.error(error);
            message.error('删除失败');
        }
    };

    return (
        <div className="flex flex-col gap-6 w-full animate-fade-in">
            <header className="px-2">
                <h2 className="text-4xl font-extrabold tracking-tight text-slate-900 dark:text-white">待办事项</h2>
                <p className="text-slate-500 dark:text-text-secondary text-lg mt-1">更简约的任务工作台，支持侧边抽屉编辑。</p>
            </header>

            <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_22rem] gap-6 px-2">
                <section className="flex flex-col gap-5 min-w-0">
                    <div className="p-0">
                        <div className="flex flex-col gap-3">
                            <div className="flex items-center gap-3">
                                <input
                                    value={createDraft.title}
                                    onChange={(e) => setCreateDraft((prev) => ({ ...prev, title: e.target.value }))}
                                    onKeyDown={(e) => {
                                        if (e.key === 'Enter') {
                                            e.preventDefault();
                                            handleCreateTask();
                                        }
                                    }}
                                    className={`${inputClass} flex-1`}
                                    placeholder="任务标题（回车可创建）"
                                />
                                <button
                                    type="button"
                                    onClick={handleCreateTask}
                                    disabled={saving}
                                    className="px-5 py-3 bg-primary hover:bg-blue-600 text-white text-sm font-bold shadow-glow transition-colors disabled:opacity-60 rounded-2xl"
                                >
                                    创建
                                </button>
                            </div>
                            <div className="grid grid-cols-1 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_auto] gap-3">
                                <ProjectSelect
                                    className="w-full"
                                    value={createDraft.priority}
                                    options={PRIORITY_PICKER_OPTIONS}
                                    onChange={(nextValue) =>
                                        setCreateDraft((prev) => ({
                                            ...prev,
                                            priority: nextValue as TodoPriority
                                        }))
                                    }
                                />
                                <ProjectNativePicker
                                    type="date"
                                    value={createDraft.dueDate}
                                    placeholder="选择日期"
                                    onChange={(nextValue) =>
                                        setCreateDraft((prev) => ({
                                            ...prev,
                                            dueDate: nextValue,
                                            dueTime: nextValue ? prev.dueTime : ''
                                        }))
                                    }
                                />
                                <ProjectNativePicker
                                    type="time"
                                    value={createDraft.dueTime}
                                    placeholder={createDraft.dueDate ? '选择时间' : '请先选择日期'}
                                    disabled={!createDraft.dueDate}
                                    onChange={(nextValue) =>
                                        setCreateDraft((prev) => ({ ...prev, dueTime: nextValue }))
                                    }
                                />
                                <div className="flex items-center justify-end">
                                    <button type="button" onClick={openCreateTagModal} className="text-xs font-bold text-primary">+ 标签</button>
                                </div>
                            </div>
                            <div>
                                <p className="text-xs font-bold text-slate-500 dark:text-text-secondary mb-2">任务描述</p>
                                <textarea
                                    value={createDraft.descriptionMd}
                                    onChange={(e) => setCreateDraft((prev) => ({ ...prev, descriptionMd: e.target.value }))}
                                    placeholder="输入任务描述或备注..."
                                    rows={4}
                                    className={`${inputClass} resize-y`}
                                />
                            </div>
                            <div className="flex flex-wrap gap-2">
                                {tags.map((tag) => {
                                    const active = createDraft.tagIds.includes(tag.id);
                                    return (
                                        <button
                                            key={tag.id}
                                            type="button"
                                            onClick={() => toggleCreateTag(tag.id)}
                                            className={`px-2.5 py-1 text-xs border rounded-full ${active ? 'ring-1' : ''}`}
                                            style={{ color: tag.color, borderColor: `${tag.color}88`, backgroundColor: active ? `${tag.color}22` : `${tag.color}10` }}
                                        >
                                            #{tag.name}
                                        </button>
                                    );
                                })}
                            </div>
                        </div>
                    </div>

                    <div className="px-1">
                        <div className="flex flex-wrap items-center gap-4 text-sm">
                            <span className="text-slate-500 dark:text-text-secondary">总任务 <b className="text-slate-900 dark:text-white ml-1">{stats.totalTasks}</b></span>
                            <span className="text-slate-500 dark:text-text-secondary">进行中 <b className="text-blue-500 ml-1">{stats.pendingTasks}</b></span>
                            <span className="text-slate-500 dark:text-text-secondary">已完成 <b className="text-green-500 ml-1">{stats.completedTasks}</b></span>
                            <span className="text-slate-500 dark:text-text-secondary">今日到期 <b className="text-amber-500 ml-1">{stats.dueToday}</b></span>
                            <span className="text-slate-500 dark:text-text-secondary">本周完成率 <b className="text-purple-500 ml-1">{stats.weekCompletionRate}%</b></span>
                        </div>
                    </div>

                    <div className="px-1 pb-1">
                        <div className="grid grid-cols-2 md:grid-cols-8 gap-2">
                            <input value={searchInput} onChange={(e) => setSearchInput(e.target.value)} className={`md:col-span-2 ${inputClass}`} placeholder="搜索任务" />
                            <ProjectSelect
                                className="w-full"
                                value={query.status}
                                options={TASK_STATUS_OPTIONS}
                                onChange={(nextValue) =>
                                    setQuery((prev) => ({
                                        ...prev,
                                        status: nextValue as TodoQueryState['status']
                                    }))
                                }
                            />
                            <ProjectSelect
                                className="w-full"
                                value={query.timeFilter}
                                options={TIME_OPTIONS.map((option) => ({ value: option.value, label: `时间：${option.label}` }))}
                                onChange={(nextValue) =>
                                    setQuery((prev) => ({
                                        ...prev,
                                        timeFilter: nextValue as TodoTimeFilter
                                    }))
                                }
                            />
                            <ProjectSelect
                                className="w-full"
                                value={query.priority}
                                options={TASK_PRIORITY_FILTER_OPTIONS}
                                onChange={(nextValue) =>
                                    setQuery((prev) => ({
                                        ...prev,
                                        priority: nextValue as TodoQueryState['priority']
                                    }))
                                }
                            />
                            <ProjectSelect
                                className="w-full"
                                value={query.sortBy}
                                options={SORT_OPTIONS.map((option) => ({ value: option.value, label: `排序：${option.label}` }))}
                                onChange={(nextValue) =>
                                    setQuery((prev) => ({
                                        ...prev,
                                        sortBy: nextValue as TodoSortBy
                                    }))
                                }
                            />
                            <ProjectSelect
                                className="w-full"
                                value={query.sortOrder}
                                options={SORT_ORDER_OPTIONS}
                                onChange={(nextValue) =>
                                    setQuery((prev) => ({
                                        ...prev,
                                        sortOrder: nextValue as TodoSortOrder
                                    }))
                                }
                            />
                            <button type="button" onClick={() => { setQuery(DEFAULT_QUERY); setSearchInput(''); }} className="px-3 py-2 text-xs font-bold bg-slate-200 dark:bg-white/10 rounded-2xl">重置</button>
                        </div>
                        <p className="mt-2 text-xs text-slate-500 dark:text-text-secondary">{orderHint}</p>
                        <div className="mt-3 flex flex-wrap gap-2">
                            <button type="button" onClick={() => setQuery((prev) => ({ ...prev, listId: undefined }))} className={`px-3 py-1 text-xs rounded-full border ${query.listId == null ? 'border-primary text-primary bg-primary/10' : 'border-slate-300 text-slate-500'}`}>全部清单</button>
                            {lists.map((list) => (
                                <div key={list.id} className="inline-flex items-center gap-1.5">
                                    <button type="button" onClick={() => setQuery((prev) => ({ ...prev, listId: list.id }))} className={`px-3 py-1 text-xs rounded-full border ${query.listId === list.id ? 'text-primary border-primary bg-primary/10' : 'text-slate-500 border-slate-300'}`}>
                                        {list.name}
                                    </button>
                                    {!list.isDefault && <button type="button" onClick={() => handleDeleteList(list)} className="text-slate-400 hover:text-red-500"><span className="material-symbols-outlined text-[14px]">close</span></button>}
                                </div>
                            ))}
                            <button type="button" onClick={() => setQuery((prev) => ({ ...prev, tagId: undefined }))} className={`px-3 py-1 text-xs rounded-full border ${query.tagId == null ? 'border-primary text-primary bg-primary/10' : 'border-slate-300 text-slate-500'}`}>全部标签</button>
                            {tags.map((tag) => (
                                <div key={tag.id} className="inline-flex items-center gap-1">
                                    <button type="button" onClick={() => setQuery((prev) => ({ ...prev, tagId: tag.id }))} className="px-3 py-1 text-xs rounded-full border" style={{ color: tag.color, borderColor: `${tag.color}88`, backgroundColor: query.tagId === tag.id ? `${tag.color}22` : `${tag.color}10` }}>
                                        #{tag.name}
                                    </button>
                                    <button type="button" onClick={() => handleDeleteTag(tag)} className="text-slate-400 hover:text-red-500"><span className="material-symbols-outlined text-[14px]">close</span></button>
                                </div>
                            ))}
                        </div>
                    </div>
                </section>

                <aside className={`${panelClass} p-4 lg:sticky lg:top-24 h-fit`} style={continuous(32)}>
                    <div className="flex items-center justify-between mb-3">
                        <h3 className="text-lg font-bold text-slate-900 dark:text-white">任务列表 ({tasks.length})</h3>
                        <label className="text-xs text-slate-500 dark:text-text-secondary inline-flex items-center gap-1.5">
                            <input type="checkbox" checked={allVisibleSelected} onChange={(e) => setSelectedTaskIds(e.target.checked ? tasks.map((task) => task.id) : [])} />
                            全选
                        </label>
                    </div>

                    {selectedTaskIds.length > 0 && (
                        <div className="flex gap-2 mb-3">
                            <button type="button" onClick={() => runBatchAction('complete')} className="px-2.5 py-1.5 text-xs rounded-xl bg-green-500/20 text-green-500">完成</button>
                            <button type="button" onClick={() => runBatchAction('uncomplete')} className="px-2.5 py-1.5 text-xs rounded-xl bg-blue-500/20 text-blue-500">未完成</button>
                            <button type="button" onClick={() => runBatchAction('delete')} className="px-2.5 py-1.5 text-xs rounded-xl bg-red-500 text-white">删除</button>
                        </div>
                    )}

                    <div className="flex flex-col gap-2 max-h-[70vh] overflow-y-auto pr-1">
                        {loading || metaLoading ? (
                            <div className="text-sm text-slate-500 py-10 text-center">加载中...</div>
                        ) : tasks.length === 0 ? (
                            <div className="text-sm text-slate-400 py-10 text-center">暂无任务</div>
                        ) : (
                            tasks.map((task) => {
                                const done = task.status === 'completed';
                                return (
                                    <div
                                        key={task.id}
                                        draggable={canDragSort}
                                        onDragStart={() => setDraggingTaskId(task.id)}
                                        onDragOver={(e) => {
                                            if (canDragSort) e.preventDefault();
                                        }}
                                        onDrop={() => handleDragDrop(task.id)}
                                        className={`${softClass} p-3 cursor-pointer transition-colors ${done ? 'opacity-75' : ''}`}
                                        style={continuous(22)}
                                        onClick={() => openDrawer(task)}
                                    >
                                        <div className="flex items-start gap-2">
                                            <input type="checkbox" checked={selectedTaskIds.includes(task.id)} onChange={(e) => setSelectedTaskIds((prev) => (e.target.checked ? [...prev, task.id] : prev.filter((id) => id !== task.id)))} onClick={(e) => e.stopPropagation()} className="mt-1.5" />
                                            <button
                                                type="button"
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    handleToggleTask(task);
                                                }}
                                                className={`group/check mt-0.5 relative size-6 rounded-full border-2 transition-colors ${
                                                    done
                                                        ? 'bg-emerald-500 border-emerald-500'
                                                        : 'bg-white/80 dark:bg-[#0F172A] border-slate-300 dark:border-slate-500 hover:border-emerald-400'
                                                }`}
                                                aria-label={done ? '标记为未完成' : '标记为完成'}
                                            >
                                                <svg
                                                    viewBox="0 0 24 24"
                                                    className={`absolute inset-0 m-auto h-3.5 w-3.5 transition-opacity ${
                                                        done ? 'opacity-100 text-white' : 'opacity-0 text-emerald-500 group-hover/check:opacity-100'
                                                    }`}
                                                    fill="none"
                                                    stroke="currentColor"
                                                    strokeWidth="2.6"
                                                    strokeLinecap="round"
                                                    strokeLinejoin="round"
                                                >
                                                    <path d="M20 6 9 17l-5-5" />
                                                </svg>
                                            </button>
                                            <div className="min-w-0 flex-1">
                                                <div className="flex items-center gap-2 flex-wrap">
                                                    <p className={`text-sm font-bold truncate ${done ? 'line-through text-slate-400' : 'text-slate-900 dark:text-white'}`}>{task.title}</p>
                                                    <span className={`px-2 py-0.5 text-[10px] border rounded-full ${PRIORITY_CLASS[task.priority]}`}>{PRIORITY_LABEL[task.priority]}</span>
                                                </div>
                                                <div className="mt-1 text-[11px] text-slate-500 dark:text-text-secondary">{buildDueLabel(task)} · 子任务 {task.subtaskCompleted || 0}/{task.subtaskTotal || 0}</div>
                                                {!!task.descriptionMd && <div className="mt-1 text-[11px] text-slate-500 line-clamp-1">{compactMarkdown(task.descriptionMd)}</div>}
                                            </div>
                                            <button type="button" onClick={(e) => { e.stopPropagation(); handleDeleteTask(task); }} className="text-slate-400 hover:text-red-500"><span className="material-symbols-outlined text-[16px]">delete</span></button>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>
                </aside>
            </div>

            {isDrawerMounted && drawerDraft && drawerTask && (
                <div className="fixed inset-0 z-50">
                    <button
                        type="button"
                        className={`absolute inset-0 bg-black/30 transition-opacity duration-300 ${isDrawerVisible ? 'opacity-100' : 'opacity-0'}`}
                        onClick={closeDrawer}
                    />
                    <aside
                        className={`absolute right-0 top-0 h-full w-full max-w-[430px] bg-slate-50 dark:bg-background-dark border-l border-slate-200 dark:border-white/10 p-5 overflow-y-auto transition-all duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] ${
                            isDrawerVisible ? 'translate-x-0 opacity-100' : 'translate-x-8 opacity-0'
                        }`}
                        style={continuousLeft(36)}
                    >
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-xl font-bold text-slate-900 dark:text-white">编辑任务</h3>
                            <div className="flex items-center gap-2">
                                <button type="button" onClick={handleSaveDrawer} disabled={saving} className="px-4 py-2 text-xs font-bold text-white bg-primary hover:bg-blue-600 rounded-xl disabled:opacity-60">保存</button>
                                <button type="button" onClick={closeDrawer} className="text-slate-500 hover:text-slate-900 dark:text-text-secondary dark:hover:text-white"><span className="material-symbols-outlined">close</span></button>
                            </div>
                        </div>

                        <div className="space-y-3">
                            <input value={drawerDraft.title} onChange={(e) => setDrawerDraft((prev) => (prev ? { ...prev, title: e.target.value } : prev))} className={inputClass} placeholder="任务标题" />
                            <div className="grid grid-cols-2 gap-2">
                                <ProjectSelect
                                    className="w-full"
                                    value={drawerDraft.priority}
                                    options={PRIORITY_PICKER_OPTIONS}
                                    onChange={(nextValue) =>
                                        setDrawerDraft((prev) =>
                                            prev
                                                ? {
                                                      ...prev,
                                                      priority: nextValue as TodoPriority
                                                  }
                                                : prev
                                        )
                                    }
                                />
                                <ProjectSelect
                                    className="w-full"
                                    value={drawerDraft.listId == null ? '' : String(drawerDraft.listId)}
                                    options={[
                                        { value: '', label: '未归类' },
                                        ...lists.map((list) => ({ value: String(list.id), label: list.name }))
                                    ]}
                                    onChange={(nextValue) =>
                                        setDrawerDraft((prev) =>
                                            prev
                                                ? {
                                                      ...prev,
                                                      listId: nextValue ? Number(nextValue) : null
                                                  }
                                                : prev
                                        )
                                    }
                                />
                            </div>
                            <div className="grid grid-cols-2 gap-2">
                                <ProjectNativePicker
                                    type="date"
                                    value={drawerDraft.dueDate}
                                    placeholder="选择日期"
                                    onChange={(nextValue) =>
                                        setDrawerDraft((prev) =>
                                            prev ? { ...prev, dueDate: nextValue } : prev
                                        )
                                    }
                                />
                                <ProjectNativePicker
                                    type="time"
                                    value={drawerDraft.dueTime}
                                    placeholder="选择时间"
                                    onChange={(nextValue) =>
                                        setDrawerDraft((prev) =>
                                            prev ? { ...prev, dueTime: nextValue } : prev
                                        )
                                    }
                                />
                            </div>
                            <div className="flex flex-wrap gap-2">
                                {tags.map((tag) => {
                                    const active = drawerDraft.tagIds.includes(tag.id);
                                    return (
                                        <button key={tag.id} type="button" onClick={() => toggleDrawerTag(tag.id)} className={`px-2.5 py-1 text-xs border rounded-full ${active ? 'ring-1' : ''}`} style={{ color: tag.color, borderColor: `${tag.color}88`, backgroundColor: active ? `${tag.color}22` : `${tag.color}10` }}>
                                            #{tag.name}
                                        </button>
                                    );
                                })}
                            </div>
                            <div>
                                <p className="text-xs font-bold text-slate-500 dark:text-text-secondary mb-2">任务描述</p>
                                <textarea
                                    value={drawerDraft.descriptionMd}
                                    onChange={(e) => setDrawerDraft((prev) => (prev ? { ...prev, descriptionMd: e.target.value } : prev))}
                                    rows={5}
                                    placeholder="可编辑任务描述"
                                    className={`${inputClass} resize-y`}
                                />
                            </div>

                            <div className={`${panelClass} p-3`} style={continuous(20)}>
                                <div className="flex items-center justify-between mb-2 text-xs text-slate-500 dark:text-text-secondary">
                                    <span>子任务 ({drawerTask.subtaskCompleted || 0}/{drawerTask.subtaskTotal || 0})</span>
                                    <span>{drawerTask.subtaskProgress || 0}%</span>
                                </div>
                                <div className="h-1.5 bg-slate-200 dark:bg-white/10 rounded-full mb-3 overflow-hidden">
                                    <div className="h-full bg-primary" style={{ width: `${drawerTask.subtaskProgress || 0}%` }} />
                                </div>
                                <div className="space-y-2">
                                    {(drawerTask.subtasks || []).map((subtask) => {
                                        const done = subtask.status === 'completed';
                                        return (
                                            <div key={subtask.id} className={`${softClass} px-2.5 py-2 rounded-xl flex items-center gap-2`}>
                                                <button type="button" onClick={() => handleToggleSubtask(subtask.id, done)} className={`size-4 rounded-full border-2 ${done ? 'bg-green-500 border-green-500' : 'border-slate-300 dark:border-slate-500'}`} />
                                                <span className={`flex-1 text-xs ${done ? 'line-through text-slate-400' : 'text-slate-700 dark:text-white'}`}>{subtask.title}</span>
                                                <button type="button" onClick={() => handleDeleteSubtask(subtask.id)} className="text-slate-400 hover:text-red-500"><span className="material-symbols-outlined text-[16px]">delete</span></button>
                                            </div>
                                        );
                                    })}
                                </div>
                                <div className="mt-2 flex gap-2">
                                    <input value={newSubtaskTitle} onChange={(e) => setNewSubtaskTitle(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), handleCreateSubtask())} className={`${inputClass} text-sm`} placeholder="输入子任务并回车" />
                                    <button type="button" onClick={handleCreateSubtask} className="px-3 py-2 text-xs font-bold rounded-xl bg-slate-200 dark:bg-white/10">添加</button>
                                </div>
                            </div>

                            <button type="button" onClick={() => handleDeleteTask(drawerTask)} className="w-full py-2.5 text-sm font-bold text-white bg-red-500 hover:bg-red-600 rounded-xl">删除任务</button>
                        </div>
                    </aside>
                </div>
            )}

            {showTagCreateModal && (
                <QuickCreateModal
                    title="新建标签"
                    placeholder="请输入标签名称"
                    value={tagNameDraft}
                    confirmText="创建标签"
                    onChange={setTagNameDraft}
                    onCancel={() => setShowTagCreateModal(false)}
                    onConfirm={handleCreateTag}
                />
            )}
        </div>
    );
};

export default TodoPage;
