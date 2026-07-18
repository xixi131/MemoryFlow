
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
    BarChart3,
    CalendarDays,
    Check,
    ChevronRight,
    CirclePlus,
    Clock3,
    GripVertical,
    ListFilter,
    ListTodo,
    Minus,
    Search,
    SlidersHorizontal,
    Tags,
    Trash2
} from 'lucide-react';
import { message } from '../components/Message';
import { ModalWrapper } from '../components/Modals';
import TodoTrendChart from '../components/todo/TodoTrendChart';
import { useTodoSynchronization } from '../hooks/useTodoSynchronization';
import todoApis, {
    CreateTodoTaskPayload,
    TodoPriority,
    TodoSortBy,
    TodoSortOrder,
    TodoStatsDTO,
    TodoTagDTO,
    TodoTaskDTO,
    TodoTimeFilter,
    TodoTrendDays
} from '../services/todoApis';

type TodoQueryState = {
    keyword: string;
    status: 'all' | 'todo' | 'completed';
    timeFilter: TodoTimeFilter;
    priority: 'all' | TodoPriority;
    tagId?: number;
    sortBy: TodoSortBy;
    sortOrder: TodoSortOrder;
};

type TaskEditorDraft = {
    id: number;
    title: string;
    descriptionMd: string;
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
    'w-full border border-slate-200/90 bg-white px-4 py-3 text-slate-900 outline-none transition-[border-color,box-shadow,background-color] placeholder:text-slate-400 hover:border-slate-300 focus:border-primary/70 focus:ring-4 focus:ring-primary/10 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 disabled:opacity-70 dark:border-white/10 dark:bg-[#101725] dark:text-white dark:placeholder:text-slate-500 dark:hover:border-white/20 dark:focus:border-primary/70 dark:disabled:bg-[#0B1220] dark:disabled:text-slate-400';

const selectClass =
    'border border-slate-200/90 bg-white px-3.5 py-2.5 text-slate-900 outline-none transition-[border-color,box-shadow,background-color] hover:border-slate-300 focus:border-primary/70 focus:ring-4 focus:ring-primary/10 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 disabled:opacity-70 dark:border-white/10 dark:bg-[#101725] dark:text-white dark:hover:border-white/20 dark:focus:border-primary/70 dark:disabled:bg-[#0B1220] dark:disabled:text-slate-400';

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
                style={continuous(16)}
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
                style={continuous(16)}
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
                    style={continuous(18)}
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

const AppleCheckbox: React.FC<{
    checked: boolean;
    indeterminate?: boolean;
    ariaLabel: string;
    label?: string;
    className?: string;
    onChange: (checked: boolean) => void;
}> = ({ checked, indeterminate = false, ariaLabel, label, className, onChange }) => {
    const active = checked || indeterminate;

    return (
        <button
            type="button"
            role="checkbox"
            aria-checked={indeterminate ? 'mixed' : checked}
            aria-label={ariaLabel}
            onClick={(event) => {
                event.stopPropagation();
                onChange(!checked);
            }}
            className={`inline-flex shrink-0 items-center gap-2 text-xs font-semibold text-slate-500 dark:text-text-secondary ${className || ''}`}
        >
            <span
                aria-hidden="true"
                className={`relative flex size-5 items-center justify-center border transition-[background-color,border-color,box-shadow] ${
                    active
                        ? 'border-[#0A84FF] bg-[#0A84FF] text-white shadow-[0_1px_3px_rgba(10,132,255,0.3)]'
                        : 'border-slate-300 bg-white text-transparent hover:border-slate-400 dark:border-slate-500 dark:bg-[#101725] dark:hover:border-slate-400'
                }`}
                style={continuous(6)}
            >
                {indeterminate ? <Minus size={14} strokeWidth={2.8} /> : <Check size={14} strokeWidth={2.8} />}
            </span>
            {label && <span>{label}</span>}
        </button>
    );
};

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
    return String(task.dueDate).slice(0, 10);
};

const TodoPage: React.FC = () => {
    const location = useLocation();
    const isStatisticsRoute = location.pathname === '/stats';
    const [tags, setTags] = useState<TodoTagDTO[]>([]);
    const [query, setQuery] = useState<TodoQueryState>(DEFAULT_QUERY);
    const [searchInput, setSearchInput] = useState('');
    const [tagsLoading, setTagsLoading] = useState(true);
    const [trendDays, setTrendDays] = useState<TodoTrendDays>(7);
    const [saving, setSaving] = useState(false);

    const taskQuery = useMemo(
        () => ({
            keyword: query.keyword || undefined,
            status: query.status,
            timeFilter: query.timeFilter,
            priority: query.priority,
            tagId: query.tagId,
            sortBy: query.sortBy,
            sortOrder: query.sortOrder
        }),
        [query]
    );
    const {
        tasks,
        setTasks,
        stats,
        statsLoadState,
        trend,
        trendLoadState,
        trendError,
        tasksLoading,
        refreshNow
    } = useTodoSynchronization({
        routeKey: location.pathname,
        taskQuery,
        trendDays,
        initialStats: EMPTY_STATS
    });

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
    const someVisibleSelected = selectedTaskIds.length > 0 && !allVisibleSelected;
    const canDragSort = query.sortBy === 'custom';
    const toEditorDraft = useCallback(
        (task: TodoTaskDTO): TaskEditorDraft => ({
            id: task.id,
            title: task.title,
            descriptionMd: task.descriptionMd || '',
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
    useEffect(() => {
        if (!isStatisticsRoute) return;
        if (isDrawerMounted) closeDrawer();
        setShowTagCreateModal(false);
    }, [closeDrawer, isDrawerMounted, isStatisticsRoute]);
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

    const loadTags = useCallback(async () => {
        setTagsLoading(true);
        try {
            const res: any = await todoApis.getTags();
            if (res.code === 200) setTags(Array.isArray(res.data) ? res.data : []);
        } catch (error) {
            console.error(error);
            message.error('标签加载失败');
        } finally {
            setTagsLoading(false);
        }
    }, []);

    const refreshAfterMutation = useCallback(
        async (refreshTags = false) => {
            if (refreshTags) await loadTags();
            await refreshNow();
        },
        [loadTags, refreshNow]
    );

    useEffect(() => {
        void loadTags();
    }, [loadTags]);

    useEffect(() => {
        setSelectedTaskIds((prev) => prev.filter((id) => tasks.some((task) => task.id === id)));
        const activeDrawerTaskId = drawerTaskIdRef.current;
        if (activeDrawerTaskId && !tasks.some((task) => task.id === activeDrawerTaskId)) {
            closeDrawer();
        }
    }, [closeDrawer, tasks]);

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

            await refreshNow();
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
                await refreshNow();
            } else {
                await refreshNow();
            }
        } catch (error) {
            console.error(error);
            message.error('排序失败，已恢复');
            await refreshNow();
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
                priority: drawerDraft.priority,
                dueDate: drawerDraft.dueDate || '',
                dueTime: drawerDraft.dueDate ? drawerDraft.dueTime || '' : '',
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
        <div className="flex w-full flex-col gap-6 animate-fade-in">
            <header className="flex flex-col gap-5 px-2 lg:flex-row lg:items-end lg:justify-between">
                <div>
                    <p className="mb-2 text-sm font-semibold text-primary">专注与进度</p>
                    <h2 className="text-3xl font-extrabold text-slate-900 dark:text-white sm:text-4xl">待办工作台</h2>
                    <p className="mt-2 max-w-2xl text-base text-slate-500 dark:text-text-secondary">
                        {isStatisticsRoute ? '查看任务进度、到期风险与本周完成情况。' : '清晰安排任务，专注处理此刻最重要的事情。'}
                    </p>
                </div>
                <nav
                    aria-label="待办工作区视图"
                    className="relative grid h-12 w-full grid-cols-2 bg-slate-200/80 p-1 dark:bg-white/10 sm:w-[300px]"
                    style={continuous(999)}
                >
                    <span
                        aria-hidden="true"
                        className="absolute bottom-1 left-1 top-1 w-[calc(50%-4px)] bg-white shadow-[0_1px_3px_rgba(15,23,42,0.12),0_6px_16px_rgba(15,23,42,0.08)] transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] dark:bg-[#202938] dark:shadow-[0_8px_18px_rgba(0,0,0,0.28)]"
                        style={{ ...continuous(999), transform: `translateX(${isStatisticsRoute ? '100%' : '0'})` }}
                    />
                    <Link
                        to="/todo"
                        aria-current={!isStatisticsRoute ? 'page' : undefined}
                        className={`relative z-10 flex min-h-10 items-center justify-center gap-2 px-4 py-2 text-sm font-bold transition-colors ${
                            !isStatisticsRoute
                                ? 'text-slate-900 dark:text-white'
                                : 'text-slate-500 hover:text-slate-800 dark:text-text-secondary dark:hover:text-white'
                        }`}
                        style={continuous(999)}
                    >
                        <ListTodo size={17} strokeWidth={2.2} />
                        待办
                    </Link>
                    <Link
                        to="/stats"
                        aria-current={isStatisticsRoute ? 'page' : undefined}
                        className={`relative z-10 flex min-h-10 items-center justify-center gap-2 px-4 py-2 text-sm font-bold transition-colors ${
                            isStatisticsRoute
                                ? 'text-slate-900 dark:text-white'
                                : 'text-slate-500 hover:text-slate-800 dark:text-text-secondary dark:hover:text-white'
                        }`}
                        style={continuous(999)}
                    >
                        <BarChart3 size={17} strokeWidth={2.2} />
                        统计
                    </Link>
                </nav>
            </header>

            <div className="flex flex-col gap-6 px-2">
                {isStatisticsRoute ? (
                    <section aria-labelledby="todo-statistics-heading" className="flex flex-col gap-5 min-w-0">
                        <div>
                            <h3 id="todo-statistics-heading" className="text-xl font-bold text-slate-900 dark:text-white">任务概览</h3>
                            <p className="mt-1 text-sm text-slate-500 dark:text-text-secondary">统计数据来自当前账户的全部任务。</p>
                        </div>
                        {statsLoadState === 'loading' ? (
                            <div className="min-h-[132px] py-10 text-center text-sm text-slate-500 dark:text-text-secondary">统计加载中...</div>
                        ) : (
                            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
                                {[
                                    { label: '总任务', value: stats.totalTasks, detail: '全部已创建任务', tone: 'text-slate-900 dark:text-white' },
                                    { label: '进行中', value: stats.pendingTasks, detail: '尚未完成', tone: 'text-blue-500' },
                                    { label: '已完成', value: stats.completedTasks, detail: '累计完成', tone: 'text-emerald-500' },
                                    { label: '今日到期', value: stats.dueToday, detail: '需要今日处理', tone: 'text-amber-500' },
                                    { label: '明日到期', value: stats.dueTomorrow, detail: '即将到期', tone: 'text-cyan-500' },
                                    { label: '已经逾期', value: stats.overdueTasks, detail: '待处理的逾期任务', tone: 'text-red-500' },
                                    { label: '紧急任务', value: stats.highPriorityPending, detail: '未完成的紧急任务', tone: 'text-orange-500' },
                                    {
                                        label: '本周完成率',
                                        value: `${stats.weekCompletionRate}%`,
                                        detail: `创建 ${stats.createdThisWeek} · 完成 ${stats.completedThisWeek}`,
                                        tone: 'text-purple-500'
                                    }
                                ].map((metric) => (
                                    <article
                                        key={metric.label}
                                        className="flex min-h-[132px] flex-col justify-between border border-slate-200 bg-white/80 p-4 shadow-[0_8px_24px_rgba(15,23,42,0.05)] dark:border-white/10 dark:bg-white/5"
                                        style={continuous(24)}
                                    >
                                        <p className="text-sm font-bold text-slate-500 dark:text-text-secondary">{metric.label}</p>
                                        <p className={`text-3xl font-extrabold ${metric.tone}`}>{metric.value}</p>
                                        <p className="text-xs text-slate-400 dark:text-text-secondary/80">{metric.detail}</p>
                                    </article>
                                ))}
                            </div>
                        )}
                        <TodoTrendChart
                            days={trendDays}
                            trend={trend}
                            loadState={trendLoadState}
                            errorMessage={trendError}
                            onDaysChange={setTrendDays}
                            onRetry={() => {
                                void refreshNow();
                            }}
                        />
                    </section>
                ) : (
                    <>
                <section
                    aria-labelledby="todo-create-heading"
                    className="min-w-0 border border-slate-200/90 bg-slate-50/80 p-4 shadow-[0_14px_36px_rgba(15,23,42,0.05)] dark:border-white/10 dark:bg-white/[0.035] sm:p-5"
                    style={continuous(28)}
                >
                    <div className="mb-4 flex items-center gap-3">
                        <span className="flex size-10 shrink-0 items-center justify-center bg-primary/10 text-primary" style={continuous(14)}>
                            <CirclePlus size={21} strokeWidth={2.1} />
                        </span>
                        <div>
                            <h3 id="todo-create-heading" className="text-base font-bold text-slate-900 dark:text-white">新建任务</h3>
                            <p className="mt-0.5 text-sm text-slate-500 dark:text-text-secondary">快速记录，再补充时间与优先级。</p>
                        </div>
                    </div>
                    <div className="flex flex-col gap-3">
                            <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
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
                                    style={continuous(18)}
                                    placeholder="任务标题（回车可创建）"
                                />
                                <button
                                    type="button"
                                    onClick={handleCreateTask}
                                    disabled={saving}
                                    className="inline-flex min-h-12 shrink-0 items-center justify-center gap-2 bg-primary px-5 py-3 text-sm font-bold text-white shadow-[0_8px_20px_rgba(37,99,235,0.22)] transition-[background-color,transform,box-shadow] hover:bg-blue-600 hover:shadow-[0_10px_24px_rgba(37,99,235,0.28)] active:scale-[0.98] disabled:opacity-60"
                                    style={continuous(18)}
                                >
                                    <CirclePlus size={18} />
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
                                    <button type="button" onClick={openCreateTagModal} className="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-bold text-primary hover:bg-primary/10" style={continuous(999)}>
                                        <Tags size={15} />
                                        新建标签
                                    </button>
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
                                    style={continuous(18)}
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
                                            className={`border px-2.5 py-1 text-xs ${active ? 'ring-1' : ''}`}
                                            style={{ ...continuous(999), color: tag.color, borderColor: `${tag.color}88`, backgroundColor: active ? `${tag.color}22` : `${tag.color}10` }}
                                        >
                                            #{tag.name}
                                        </button>
                                    );
                                })}
                            </div>
                    </div>
                </section>

                <section
                    aria-labelledby="todo-filter-heading"
                    className="min-w-0 border border-slate-200/90 bg-white/70 p-4 dark:border-white/10 dark:bg-white/[0.025] sm:p-5"
                    style={continuous(28)}
                >
                    <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                        <div className="flex items-center gap-3">
                            <span className="flex size-10 shrink-0 items-center justify-center bg-slate-200/70 text-slate-600 dark:bg-white/10 dark:text-slate-300" style={continuous(14)}>
                                <ListFilter size={20} strokeWidth={2.1} />
                            </span>
                            <div>
                                <h3 id="todo-filter-heading" className="text-base font-bold text-slate-900 dark:text-white">查询与筛选</h3>
                                <p className="mt-0.5 text-sm text-slate-500 dark:text-text-secondary">组合条件，快速定位需要处理的任务。</p>
                            </div>
                        </div>
                        <button
                            type="button"
                            onClick={() => { setQuery(DEFAULT_QUERY); setSearchInput(''); }}
                            className="inline-flex items-center justify-center gap-1.5 self-start bg-slate-100 px-3 py-2 text-xs font-bold text-slate-600 transition-colors hover:bg-slate-200 dark:bg-white/10 dark:text-slate-300 dark:hover:bg-white/15 sm:self-auto"
                            style={continuous(999)}
                        >
                            <SlidersHorizontal size={14} />
                            重置筛选
                        </button>
                    </div>
                        <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-7">
                            <label className="relative sm:col-span-2 xl:col-span-2">
                                <Search className="pointer-events-none absolute left-3.5 top-1/2 z-10 -translate-y-1/2 text-slate-400" size={18} />
                                <input
                                    value={searchInput}
                                    onChange={(e) => setSearchInput(e.target.value)}
                                    className={`${inputClass} py-2.5 pl-11`}
                                    style={continuous(16)}
                                    placeholder="搜索任务标题或描述"
                                />
                            </label>
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
                        </div>
                        <p className="mt-3 text-xs text-slate-500 dark:text-text-secondary">{orderHint}</p>
                        <div className="mt-3 flex flex-wrap items-center gap-2">
                            <span className="mr-1 inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 dark:text-text-secondary"><Tags size={14} />标签</span>
                            <button type="button" onClick={() => setQuery((prev) => ({ ...prev, tagId: undefined }))} className={`border px-3 py-1.5 text-xs font-semibold ${query.tagId == null ? 'border-primary/40 text-primary bg-primary/10' : 'border-slate-200 text-slate-500 dark:border-white/10'}`} style={continuous(999)}>全部</button>
                            {tags.map((tag) => (
                                <div key={tag.id} className="inline-flex items-center gap-1">
                                    <button type="button" onClick={() => setQuery((prev) => ({ ...prev, tagId: tag.id }))} className="border px-3 py-1.5 text-xs font-semibold" style={{ ...continuous(999), color: tag.color, borderColor: `${tag.color}88`, backgroundColor: query.tagId === tag.id ? `${tag.color}22` : `${tag.color}10` }}>
                                        #{tag.name}
                                    </button>
                                    <button type="button" onClick={() => handleDeleteTag(tag)} aria-label={`删除标签 ${tag.name}`} className="flex size-7 items-center justify-center text-slate-400 hover:text-red-500" style={continuous(999)}><Trash2 size={13} /></button>
                                </div>
                            ))}
                        </div>
                </section>

                <section aria-labelledby="todo-list-heading" className="w-full min-w-0 pt-1">
                    <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                        <div className="flex items-center gap-3">
                            <h3 id="todo-list-heading" className="text-xl font-bold text-slate-900 dark:text-white">任务列表</h3>
                            <span className="bg-slate-200/80 px-2.5 py-1 text-xs font-bold text-slate-600 dark:bg-white/10 dark:text-slate-300" style={continuous(999)}>{tasks.length}</span>
                        </div>
                        <div className="flex flex-wrap items-center gap-1.5 sm:justify-end">
                            {selectedTaskIds.length > 0 && (
                                <>
                                    <span className="px-2 text-xs font-bold text-slate-500 dark:text-slate-300">已选 {selectedTaskIds.length} 项</span>
                                    <button type="button" onClick={() => runBatchAction('complete')} className="px-3 py-1.5 text-xs font-bold text-emerald-600 hover:bg-emerald-500/10" style={continuous(999)}>标记完成</button>
                                    <button type="button" onClick={() => runBatchAction('uncomplete')} className="px-3 py-1.5 text-xs font-bold text-blue-600 hover:bg-blue-500/10" style={continuous(999)}>恢复待办</button>
                                    <button type="button" onClick={() => runBatchAction('delete')} className="px-3 py-1.5 text-xs font-bold text-red-500 hover:bg-red-500/10" style={continuous(999)}>删除</button>
                                    <span className="mx-1 h-4 w-px bg-slate-200 dark:bg-white/10" aria-hidden="true" />
                                </>
                            )}
                            <AppleCheckbox
                                checked={allVisibleSelected}
                                indeterminate={someVisibleSelected}
                                ariaLabel="全选可见任务"
                                label="全选"
                                onChange={(checked) => setSelectedTaskIds(checked ? tasks.map((task) => task.id) : [])}
                            />
                        </div>
                    </div>

                    <div className="-m-3 flex max-h-[70vh] flex-col gap-3 overflow-y-auto p-3">
                        {tasksLoading || tagsLoading ? (
                            <div className="border border-slate-200 bg-white/70 py-14 text-center text-sm text-slate-500 dark:border-white/10 dark:bg-white/[0.03]" style={continuous(24)}>加载中...</div>
                        ) : tasks.length === 0 ? (
                            <div className="flex flex-col items-center border border-dashed border-slate-300 bg-white/50 px-6 py-14 text-center dark:border-white/15 dark:bg-white/[0.02]" style={continuous(28)}>
                                <span className="mb-3 flex size-12 items-center justify-center bg-slate-100 text-slate-400 dark:bg-white/10" style={continuous(18)}><ListTodo size={23} /></span>
                                <p className="font-bold text-slate-700 dark:text-slate-200">没有符合条件的任务</p>
                                <p className="mt-1 text-sm text-slate-400">新建一个任务，或调整上方筛选条件。</p>
                            </div>
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
                                        className={`group cursor-pointer p-4 shadow-[0_5px_16px_rgba(15,23,42,0.08),0_1px_3px_rgba(15,23,42,0.04)] dark:shadow-[0_7px_20px_rgba(0,0,0,0.24),0_1px_3px_rgba(0,0,0,0.16)] ${
                                            done
                                                ? 'bg-slate-50/75 dark:bg-white/[0.025]'
                                                : 'bg-white dark:bg-[#101725]'
                                        }`}
                                        style={continuous(24)}
                                        onClick={() => openDrawer(task)}
                                    >
                                        <div className="flex items-start gap-3">
                                            {canDragSort && <GripVertical className="mt-1.5 hidden shrink-0 text-slate-300 transition-colors group-hover:text-slate-400 sm:block" size={17} aria-hidden="true" />}
                                            <AppleCheckbox
                                                checked={selectedTaskIds.includes(task.id)}
                                                ariaLabel={`选择任务 ${task.title}`}
                                                className="mt-1"
                                                onChange={(checked) =>
                                                    setSelectedTaskIds((prev) =>
                                                        checked ? [...prev, task.id] : prev.filter((id) => id !== task.id)
                                                    )
                                                }
                                            />
                                            <button
                                                type="button"
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    handleToggleTask(task);
                                                }}
                                                className={`group/check relative mt-0.5 size-7 shrink-0 border-2 transition-[border-color,background-color,transform] active:scale-90 ${
                                                    done
                                                        ? 'bg-emerald-500 border-emerald-500'
                                                        : 'bg-white/80 dark:bg-[#0F172A] border-slate-300 dark:border-slate-500 hover:border-emerald-400'
                                                }`}
                                                style={continuous(999)}
                                                aria-label={done ? '标记为未完成' : '标记为完成'}
                                            >
                                                <Check className={`absolute inset-0 m-auto size-4 transition-opacity ${done ? 'opacity-100 text-white' : 'opacity-0 text-emerald-500 group-hover/check:opacity-100'}`} strokeWidth={2.8} />
                                            </button>
                                            <div className="min-w-0 flex-1">
                                                <div className="flex flex-wrap items-center gap-2">
                                                    <p className={`min-w-0 truncate text-[15px] font-bold ${done ? 'line-through text-slate-400' : 'text-slate-900 dark:text-white'}`}>{task.title}</p>
                                                    <span className={`border px-2.5 py-1 text-[10px] font-bold ${PRIORITY_CLASS[task.priority]}`} style={continuous(999)}>{PRIORITY_LABEL[task.priority]}</span>
                                                </div>
                                                {!!task.descriptionMd && <p className="mt-1.5 line-clamp-1 text-sm text-slate-500 dark:text-text-secondary">{compactMarkdown(task.descriptionMd)}</p>}
                                                <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 text-xs font-medium text-slate-400 dark:text-slate-500">
                                                    <span className="inline-flex items-center gap-1.5"><CalendarDays size={14} />{buildDueLabel(task)}</span>
                                                    {(task.subtaskTotal || 0) > 0 && <span className="inline-flex items-center gap-1.5"><Check size={14} />子任务 {task.subtaskCompleted || 0}/{task.subtaskTotal || 0}</span>}
                                                    {!!task.dueTime && <span className="inline-flex items-center gap-1.5"><Clock3 size={14} />{toTimeInput(task.dueTime)}</span>}
                                                </div>
                                                {!!task.tags?.length && (
                                                    <div className="mt-3 flex flex-wrap gap-1.5">
                                                        {task.tags.slice(0, 4).map((tag) => (
                                                            <span key={tag.id} className="px-2 py-1 text-[10px] font-semibold" style={{ ...continuous(999), color: tag.color, backgroundColor: `${tag.color}12` }}>#{tag.name}</span>
                                                        ))}
                                                    </div>
                                                )}
                                            </div>
                                            <div className="flex shrink-0 items-center gap-1">
                                                <button type="button" onClick={(e) => { e.stopPropagation(); handleDeleteTask(task); }} aria-label={`删除任务 ${task.title}`} className="flex size-9 items-center justify-center text-slate-300 opacity-100 transition-[color,background-color,opacity] hover:bg-red-500/10 hover:text-red-500 sm:opacity-0 sm:group-hover:opacity-100 sm:focus:opacity-100" style={continuous(999)}><Trash2 size={16} /></button>
                                                <ChevronRight className="text-slate-300 transition-transform group-hover:translate-x-0.5 group-hover:text-slate-500" size={19} aria-hidden="true" />
                                            </div>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>
                </section>
                    </>
                )}
            </div>

            {!isStatisticsRoute && isDrawerMounted && drawerDraft && drawerTask && (
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
                            <input value={drawerDraft.title} onChange={(e) => setDrawerDraft((prev) => (prev ? { ...prev, title: e.target.value } : prev))} className={inputClass} style={continuous(18)} placeholder="任务标题" />
                            <div>
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
                            </div>
                            <div className="grid grid-cols-2 gap-2">
                                <ProjectNativePicker
                                    type="date"
                                    value={drawerDraft.dueDate}
                                    placeholder="选择日期"
                                    onChange={(nextValue) =>
                                        setDrawerDraft((prev) =>
                                            prev
                                                ? {
                                                      ...prev,
                                                      dueDate: nextValue,
                                                      dueTime: nextValue ? prev.dueTime : ''
                                                  }
                                                : prev
                                        )
                                    }
                                />
                                <ProjectNativePicker
                                    type="time"
                                    value={drawerDraft.dueTime}
                                    placeholder={drawerDraft.dueDate ? '选择时间' : '请先选择日期'}
                                    disabled={!drawerDraft.dueDate}
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
                                    style={continuous(18)}
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
                                            <div key={subtask.id} className={`${softClass} flex items-center gap-2 px-2.5 py-2`} style={continuous(14)}>
                                                <button type="button" onClick={() => handleToggleSubtask(subtask.id, done)} className={`size-4 rounded-full border-2 ${done ? 'bg-green-500 border-green-500' : 'border-slate-300 dark:border-slate-500'}`} />
                                                <span className={`flex-1 text-xs ${done ? 'line-through text-slate-400' : 'text-slate-700 dark:text-white'}`}>{subtask.title}</span>
                                                <button type="button" onClick={() => handleDeleteSubtask(subtask.id)} className="text-slate-400 hover:text-red-500"><span className="material-symbols-outlined text-[16px]">delete</span></button>
                                            </div>
                                        );
                                    })}
                                </div>
                                <div className="mt-2 flex gap-2">
                                    <input value={newSubtaskTitle} onChange={(e) => setNewSubtaskTitle(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), handleCreateSubtask())} className={`${inputClass} text-sm`} style={continuous(16)} placeholder="输入子任务并回车" />
                                    <button type="button" onClick={handleCreateSubtask} className="px-3 py-2 text-xs font-bold rounded-xl bg-slate-200 dark:bg-white/10">添加</button>
                                </div>
                            </div>

                            <button type="button" onClick={() => handleDeleteTask(drawerTask)} className="w-full py-2.5 text-sm font-bold text-white bg-red-500 hover:bg-red-600 rounded-xl">删除任务</button>
                        </div>
                    </aside>
                </div>
            )}

            {!isStatisticsRoute && showTagCreateModal && (
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
