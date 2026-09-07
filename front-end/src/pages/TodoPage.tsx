
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
    Plus,
    Repeat,
    Search,
    SkipForward,
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
    TodoRecurrencePayload,
    TodoRepeatFreq,
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

type RecurrenceEndMode = 'never' | 'until' | 'count';

type RecurrenceDraft = {
    freq: TodoRepeatFreq;
    interval: number;
    weekdays: number[];
    endMode: RecurrenceEndMode;
    until: string;
    count: number;
};

type TaskEditorDraft = {
    id: number;
    title: string;
    descriptionMd: string;
    priority: TodoPriority;
    dueDate: string;
    dueTime: string;
    tagIds: number[];
    recurrence: RecurrenceDraft;
};

type CreateDraft = {
    title: string;
    descriptionMd: string;
    priority: TodoPriority;
    dueDate: string;
    dueTime: string;
    tagIds: number[];
    recurrence: RecurrenceDraft;
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

const REPEAT_OPTIONS: Array<{ value: TodoRepeatFreq; label: string }> = [
    { value: 'none', label: '不重复' },
    { value: 'daily', label: '每天' },
    { value: 'weekly', label: '每周' },
    { value: 'monthly', label: '每月' },
    { value: 'yearly', label: '每年' }
];

const REPEAT_UNIT: Record<Exclude<TodoRepeatFreq, 'none'>, string> = {
    daily: '天',
    weekly: '周',
    monthly: '个月',
    yearly: '年'
};

const WEEKDAY_LABELS = ['一', '二', '三', '四', '五', '六', '日'];

const REPEAT_END_OPTIONS: Array<{ value: RecurrenceEndMode; label: string }> = [
    { value: 'never', label: '永不结束' },
    { value: 'until', label: '截止日期' },
    { value: 'count', label: '重复次数' }
];

const EMPTY_RECURRENCE: RecurrenceDraft = {
    freq: 'none',
    interval: 1,
    weekdays: [],
    endMode: 'never',
    until: '',
    count: 10
};

const recurrenceFromTask = (task: TodoTaskDTO): RecurrenceDraft => {
    const freq = task.repeatFreq || 'none';
    if (freq === 'none') return { ...EMPTY_RECURRENCE };
    return {
        freq,
        interval: Math.max(1, task.repeatInterval || 1),
        weekdays: task.repeatByWeekdays || [],
        endMode: task.repeatCount ? 'count' : task.repeatUntil ? 'until' : 'never',
        until: toDateInput(task.repeatUntil),
        count: task.repeatCount || 10
    };
};

const recurrenceToPayload = (draft: RecurrenceDraft): TodoRecurrencePayload => {
    if (draft.freq === 'none') {
        return { repeatFreq: 'none' };
    }
    return {
        repeatFreq: draft.freq,
        repeatInterval: Math.max(1, draft.interval || 1),
        repeatByWeekdays: draft.freq === 'weekly' ? draft.weekdays : [],
        repeatUntil: draft.endMode === 'until' ? draft.until : '',
        repeatCount: draft.endMode === 'count' ? Math.max(1, draft.count || 1) : 0
    };
};

const todayInput = () => {
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
};

/**
 * 与后端 TodoRecurrence#firstOccurrence 对齐：循环任务的第一次永远不落在今天之前，
 * 每周循环还会前推到最近一个选中的星期。用于在界面上提前把真实的首次日期显示出来。
 */
const resolveFirstOccurrence = (dueDate: string, draft: RecurrenceDraft): string => {
    if (!dueDate || draft.freq === 'none') return dueDate;

    const today = todayInput();
    let cursor = dueDate < today ? today : dueDate;

    if (draft.freq === 'weekly' && draft.weekdays.length > 0) {
        const date = new Date(`${cursor}T00:00:00`);
        for (let offset = 0; offset < 7; offset += 1) {
            const isoWeekday = date.getDay() === 0 ? 7 : date.getDay();
            if (draft.weekdays.includes(isoWeekday)) break;
            date.setDate(date.getDate() + 1);
        }
        const pad = (n: number) => String(n).padStart(2, '0');
        cursor = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }
    return cursor;
};

/** 循环开启时，日期字段问的是「第一次什么时候」，不是「什么时候截止」 */
const dateFieldLabels = (recurring: boolean) =>
    recurring
        ? { date: '首次日期', time: '提醒时间', datePlaceholder: '选择首次日期', timePlaceholder: '选择提醒时间' }
        : { date: '截止日期', time: '截止时间', datePlaceholder: '选择日期', timePlaceholder: '选择时间' };

/** 与后端 TodoRecurrence#describe 保持一致的本地预览文案 */
const describeRecurrence = (draft: RecurrenceDraft): string => {
    if (draft.freq === 'none') return '不重复';
    const interval = Math.max(1, draft.interval || 1);
    const unit = REPEAT_UNIT[draft.freq];
    let text = interval === 1 ? `每${draft.freq === 'monthly' ? '月' : unit}` : `每 ${interval} ${unit}`;
    if (draft.freq === 'weekly' && draft.weekdays.length > 0) {
        text += ` ${[...draft.weekdays].sort((a, b) => a - b).map((day) => `周${WEEKDAY_LABELS[day - 1]}`).join('、')}`;
    }
    if (draft.endMode === 'count') text += `，共 ${Math.max(1, draft.count || 1)} 次`;
    else if (draft.endMode === 'until' && draft.until) text += `，至 ${draft.until}`;
    return text;
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
    'w-full border border-slate-200/90 bg-white px-4 py-3 text-slate-900 outline-none transition-[border-color,box-shadow,background-color] placeholder:text-slate-400 hover:border-slate-300 focus:border-primary disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 disabled:opacity-70 dark:border-white/10 dark:bg-[#101725] dark:text-white dark:placeholder:text-slate-500 dark:hover:border-white/20 dark:focus:border-primary dark:disabled:bg-[#0B1220] dark:disabled:text-slate-400';

const selectClass =
    'field-control min-h-[52px] border border-slate-200/90 bg-white px-4 py-3 text-[15px] text-slate-900 outline-none transition-[border-color,box-shadow,background-color] hover:border-slate-300 focus:border-primary disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500 disabled:opacity-70 dark:border-white/10 dark:bg-[#101725] dark:text-white dark:hover:border-white/20 dark:focus:border-primary dark:disabled:bg-[#0B1220] dark:disabled:text-slate-400';

/**
 * 统一的按钮尺寸体系。所有可点区域至少 40px 高，主操作 48px，
 * 避免此前一排 text-xs / py-1.5 的小按钮挤在一起。
 */
const btnBase =
    'inline-flex items-center justify-center gap-2 font-semibold whitespace-nowrap transition-[background-color,color,box-shadow,transform] active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-50 disabled:active:scale-100';

const btnPrimary = `${btnBase} min-h-12 px-6 text-[15px] bg-primary text-white shadow-[0_6px_18px_rgba(0, 100, 225,0.24)] hover:bg-primary-hover hover:shadow-[0_8px_22px_rgba(0, 100, 225,0.3)]`;

const btnSecondary = `${btnBase} min-h-11 px-5 text-sm bg-slate-100 text-slate-700 hover:bg-slate-200 dark:bg-white/10 dark:text-slate-200 dark:hover:bg-white/[0.16]`;

const btnGhost = `${btnBase} min-h-11 px-4 text-sm text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-white/10`;

const btnDanger = `${btnBase} min-h-11 px-5 text-sm bg-red-500/10 text-red-600 hover:bg-red-500/[0.18] dark:bg-red-500/15 dark:text-red-400 dark:hover:bg-red-500/25`;

const iconBtnClass = `${btnBase} size-11 shrink-0 text-slate-400 hover:bg-slate-100 hover:text-slate-700 dark:hover:bg-white/10 dark:hover:text-white`;

const fieldLabelClass = 'mb-2 block text-[13px] font-semibold text-slate-600 dark:text-text-secondary';

const sectionCardClass =
    'min-w-0 border border-slate-200/90 bg-white/75 p-5 dark:border-white/10 dark:bg-white/[0.03] sm:p-6';

const quickCreateInputClass =
    'w-full px-4 py-3 bg-slate-200/95 dark:bg-[#16263b]/88 text-slate-900 dark:text-white border-0 outline-none transition-colors rounded-2xl shadow-[inset_0_1px_1px_rgba(15,23,42,0.09)] dark:shadow-[inset_0_1px_2px_rgba(0,0,0,0.35)]';

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
                <span className={`material-symbols-outlined ml-2 text-[22px] text-slate-500 dark:text-text-secondary transition-transform ${open ? 'rotate-180' : ''}`}>
                    expand_more
                </span>
            </button>
            {open && (
                <div
                    className="absolute z-40 mt-2 w-full overflow-hidden border border-slate-200 bg-white p-1.5 shadow-[0_18px_48px_rgba(15,23,42,0.18)] dark:border-white/10 dark:bg-surface-dark"
                    role="listbox"
                    style={continuous(18)}
                >
                    {options.map((option) => {
                        const active = option.value === value;
                        return (
                            <button
                                key={option.value}
                                type="button"
                                role="option"
                                aria-selected={active}
                                style={continuous(12)}
                                className={`flex min-h-11 w-full items-center px-3.5 text-left text-[15px] transition-colors ${
                                    active
                                        ? 'bg-primary font-bold text-white'
                                        : 'text-slate-800 hover:bg-slate-100 dark:text-white dark:hover:bg-white/10'
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
                <span className={`truncate ${value ? 'text-slate-900 dark:text-white' : 'text-slate-400 dark:text-text-secondary'}`}>
                    {displayValue}
                </span>
                <span className="material-symbols-outlined ml-2 text-[22px] text-slate-500 dark:text-text-secondary">
                    {type === 'date' ? 'calendar_today' : 'schedule'}
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
                        aria-label="关闭"
                        className="flex size-11 items-center justify-center rounded-full text-slate-500 transition-colors hover:bg-slate-200 dark:text-text-secondary dark:hover:bg-white/10 dark:hover:text-white"
                    >
                        <span className="material-symbols-outlined text-[22px]">close</span>
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
                <div className="flex justify-end gap-2.5">
                    <button
                        type="button"
                        onClick={onCancel}
                        className={`${btnBase} min-h-11 border border-slate-300 px-5 text-sm text-slate-600 hover:bg-slate-100 dark:border-white/10 dark:text-text-secondary dark:hover:bg-white/10`}
                        style={continuous(16)}
                    >
                        取消
                    </button>
                    <button
                        type="button"
                        onClick={onConfirm}
                        className={`${btnBase} min-h-11 bg-primary px-6 text-sm text-white shadow-[0_6px_16px_rgba(0, 100, 225,0.24)] hover:bg-primary-hover`}
                        style={continuous(16)}
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
            style={continuous(999)}
            className={`inline-flex min-h-11 shrink-0 items-center gap-2.5 text-sm font-semibold text-slate-500 transition-colors hover:bg-slate-100 dark:text-text-secondary dark:hover:bg-white/10 ${
                label ? 'px-3' : 'px-1.5'
            } ${className || ''}`}
        >
            <span
                aria-hidden="true"
                className={`relative flex size-[22px] items-center justify-center border transition-[background-color,border-color,box-shadow] ${
                    active
                        ? 'border-[#0064E1] bg-[#0064E1] text-white shadow-[0_1px_3px_rgba(0,100,225,0.3)]'
                        : 'border-slate-300 bg-white text-transparent hover:border-slate-400 dark:border-slate-500 dark:bg-[#101725] dark:hover:border-slate-400'
                }`}
                style={continuous(7)}
            >
                {indeterminate ? <Minus size={15} strokeWidth={2.8} /> : <Check size={15} strokeWidth={2.8} />}
            </span>
            {label && <span>{label}</span>}
        </button>
    );
};

/**
 * 重复规则选择器。收起时只是一行分段控件，选中频率后再展开细节，
 * 保持 Apple「渐进披露」的节奏，不给一次性任务增加噪音。
 */
const RecurrencePicker: React.FC<{
    value: RecurrenceDraft;
    onChange: (next: RecurrenceDraft) => void;
    hint?: string;
}> = ({ value, onChange, hint }) => {
    const expanded = value.freq !== 'none';

    const patch = (partial: Partial<RecurrenceDraft>) => onChange({ ...value, ...partial });

    const toggleWeekday = (day: number) =>
        patch({
            weekdays: value.weekdays.includes(day)
                ? value.weekdays.filter((item) => item !== day)
                : [...value.weekdays, day].sort((a, b) => a - b)
        });

    return (
        <div
            className="border border-slate-200/90 bg-white/70 p-5 transition-colors dark:border-white/10 dark:bg-white/[0.03]"
            style={continuous(24)}
        >
            <div className="mb-4 flex items-center gap-3">
                <span
                    className={`flex size-11 shrink-0 items-center justify-center transition-colors ${
                        expanded ? 'bg-primary/12 text-primary' : 'bg-slate-200/70 text-slate-500 dark:bg-white/10 dark:text-slate-400'
                    }`}
                    style={continuous(15)}
                >
                    <Repeat size={20} strokeWidth={2.2} />
                </span>
                <div className="min-w-0 flex-1">
                    <p className="text-[15px] font-bold text-slate-900 dark:text-white">重复</p>
                    <p className="mt-0.5 truncate text-sm text-slate-500 dark:text-text-secondary">
                        {expanded ? describeRecurrence(value) : '完成后不再自动生成新的待办'}
                    </p>
                </div>
            </div>

            <div className="flex flex-wrap gap-2">
                {REPEAT_OPTIONS.map((option) => {
                    const active = value.freq === option.value;
                    return (
                        <button
                            key={option.value}
                            type="button"
                            aria-pressed={active}
                            onClick={() =>
                                patch(
                                    option.value === 'none'
                                        ? { ...EMPTY_RECURRENCE }
                                        : { freq: option.value, interval: value.freq === 'none' ? 1 : value.interval }
                                )
                            }
                            className={`min-h-11 px-5 text-sm font-semibold transition-[background-color,color,box-shadow,transform] active:scale-[0.97] ${
                                active
                                    ? 'bg-primary text-white shadow-[0_6px_16px_rgba(0, 100, 225,0.26)]'
                                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200 dark:bg-white/10 dark:text-slate-300 dark:hover:bg-white/[0.16]'
                            }`}
                            style={continuous(999)}
                        >
                            {option.label}
                        </button>
                    );
                })}
            </div>

            {expanded && (
                <div className="mt-5 flex flex-col gap-5 border-t border-slate-200/80 pt-5 dark:border-white/10">
                    <div>
                        <span className={fieldLabelClass}>间隔</span>
                        <div
                            className="inline-flex items-center gap-1.5 bg-slate-100 p-1.5 dark:bg-white/10"
                            style={continuous(999)}
                        >
                            <button
                                type="button"
                                aria-label="减少间隔"
                                onClick={() => patch({ interval: Math.max(1, value.interval - 1) })}
                                disabled={value.interval <= 1}
                                className="flex size-10 items-center justify-center bg-white text-slate-700 shadow-[0_1px_3px_rgba(15,23,42,0.1)] transition-[background-color,transform] active:scale-90 disabled:opacity-35 disabled:active:scale-100 dark:bg-white/15 dark:text-slate-200"
                                style={continuous(999)}
                            >
                                <Minus size={17} strokeWidth={2.6} />
                            </button>
                            <span className="min-w-[5.5rem] text-center text-[15px] font-bold text-slate-900 dark:text-white">
                                {value.interval} {REPEAT_UNIT[value.freq as Exclude<TodoRepeatFreq, 'none'>]}
                            </span>
                            <button
                                type="button"
                                aria-label="增加间隔"
                                onClick={() => patch({ interval: Math.min(365, value.interval + 1) })}
                                className="flex size-10 items-center justify-center bg-white text-slate-700 shadow-[0_1px_3px_rgba(15,23,42,0.1)] transition-[background-color,transform] active:scale-90 dark:bg-white/15 dark:text-slate-200"
                                style={continuous(999)}
                            >
                                <Plus size={17} strokeWidth={2.6} />
                            </button>
                        </div>
                    </div>

                    {value.freq === 'weekly' && (
                        <div>
                            <span className={fieldLabelClass}>在这些星期重复</span>
                            <div className="flex flex-wrap gap-2">
                                {WEEKDAY_LABELS.map((label, index) => {
                                    const day = index + 1;
                                    const active = value.weekdays.includes(day);
                                    return (
                                        <button
                                            key={day}
                                            type="button"
                                            aria-pressed={active}
                                            aria-label={`周${label}`}
                                            onClick={() => toggleWeekday(day)}
                                            className={`size-11 text-[15px] font-semibold transition-[background-color,color,transform] active:scale-90 ${
                                                active
                                                    ? 'bg-primary text-white shadow-[0_4px_12px_rgba(0, 100, 225,0.26)]'
                                                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200 dark:bg-white/10 dark:text-slate-300 dark:hover:bg-white/[0.16]'
                                            }`}
                                            style={continuous(999)}
                                        >
                                            {label}
                                        </button>
                                    );
                                })}
                            </div>
                        </div>
                    )}

                    <div>
                        <span className={fieldLabelClass}>结束条件</span>
                        <div className="flex flex-wrap gap-2">
                            {REPEAT_END_OPTIONS.map((option) => {
                                const active = value.endMode === option.value;
                                return (
                                    <button
                                        key={option.value}
                                        type="button"
                                        aria-pressed={active}
                                        onClick={() => patch({ endMode: option.value })}
                                        className={`min-h-11 px-5 text-sm font-semibold transition-[background-color,color,transform] active:scale-[0.97] ${
                                            active
                                                ? 'bg-slate-900 text-white dark:bg-white dark:text-slate-900'
                                                : 'bg-slate-100 text-slate-600 hover:bg-slate-200 dark:bg-white/10 dark:text-slate-300 dark:hover:bg-white/[0.16]'
                                        }`}
                                        style={continuous(999)}
                                    >
                                        {option.label}
                                    </button>
                                );
                            })}
                        </div>

                        {value.endMode === 'until' && (
                            <div className="mt-3 max-w-xs">
                                <ProjectNativePicker
                                    type="date"
                                    value={value.until}
                                    placeholder="选择循环结束日期"
                                    onChange={(next) => patch({ until: next })}
                                />
                            </div>
                        )}

                        {value.endMode === 'count' && (
                            <label className="mt-3 flex items-center gap-3 text-sm font-semibold text-slate-600 dark:text-text-secondary">
                                共重复
                                <input
                                    type="number"
                                    min={1}
                                    max={9999}
                                    value={value.count}
                                    onChange={(e) => patch({ count: Number(e.target.value) || 1 })}
                                    className={`${selectClass} w-28 text-center`}
                                    style={continuous(16)}
                                />
                                次
                            </label>
                        )}
                    </div>

                    {!!hint && <p className="text-sm text-slate-400 dark:text-text-secondary/80">{hint}</p>}
                </div>
            )}
        </div>
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
    const palette = ['#0064E1', '#22C55E', '#EF4444', '#F59E0B', '#8B5CF6', '#14B8A6', '#06B6D4'];
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
        tagIds: [],
        recurrence: { ...EMPTY_RECURRENCE }
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

    const createLabels = dateFieldLabels(createDraft.recurrence.freq !== 'none');
    const createRecurrenceHint = useMemo(() => {
        if (createDraft.recurrence.freq === 'none') return undefined;
        if (!createDraft.dueDate) return '选择首次日期后，完成一次就会自动生成下一次。';
        const first = resolveFirstOccurrence(createDraft.dueDate, createDraft.recurrence);
        const moved = first !== createDraft.dueDate;
        return moved
            ? `首次待办为 ${first}（已按重复规则顺延，不会一创建就逾期），完成后自动生成下一次。`
            : `首次待办为 ${first}，完成后自动生成下一次。`;
    }, [createDraft.dueDate, createDraft.recurrence]);

    const drawerLabels = dateFieldLabels(!!drawerDraft && drawerDraft.recurrence.freq !== 'none');
    const drawerRecurrenceHint = useMemo(() => {
        if (!drawerDraft || drawerDraft.recurrence.freq === 'none') return undefined;
        const nextDue = toDateInput(drawerTask?.nextDueDate);
        return nextDue
            ? `完成或跳过后，会顺延到下一次：${nextDue}`
            : '完成后会自动生成下一次待办。';
    }, [drawerDraft, drawerTask]);

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
            tagIds: (task.tags || []).map((tag) => tag.id),
            recurrence: recurrenceFromTask(task)
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
        if (createDraft.recurrence.freq !== 'none' && !createDraft.dueDate) {
            message.warning('循环任务需要先选择首次日期');
            return;
        }
        const payload: CreateTodoTaskPayload = {
            title,
            descriptionMd: createDraft.descriptionMd,
            priority: createDraft.priority,
            dueDate: createDraft.dueDate || undefined,
            dueTime: createDraft.dueDate ? createDraft.dueTime || undefined : undefined,
            tagIds: createDraft.tagIds,
            ...recurrenceToPayload(createDraft.recurrence)
        };
        setSaving(true);
        try {
            const res: any = await todoApis.createTask(payload);
            if (res.code === 200) {
                message.success(createDraft.recurrence.freq === 'none' ? '任务已创建' : '循环任务已创建');
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

    const handleSkipOccurrence = async (task: TodoTaskDTO) => {
        try {
            const res: any = await todoApis.skipTaskOccurrence(task.id);
            if (res.code === 200) {
                const nextDue = toDateInput(res.data?.dueDate);
                message.success(nextDue ? `已跳过本次，顺延到 ${nextDue}` : '已跳过本次');
                await refreshAfterMutation();
            } else {
                message.error(res.message || '跳过失败');
            }
        } catch (error) {
            console.error(error);
            message.error('跳过失败');
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
        if (drawerDraft.recurrence.freq !== 'none' && !drawerDraft.dueDate) {
            message.warning('循环任务需要先选择首次日期');
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
                tagIds: drawerDraft.tagIds,
                ...recurrenceToPayload(drawerDraft.recurrence)
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
                                        className="flex min-h-[148px] flex-col justify-between border border-slate-200 bg-white/80 p-5 shadow-[0_8px_24px_rgba(15,23,42,0.05)] dark:border-white/10 dark:bg-white/5"
                                        style={continuous(26)}
                                    >
                                        <p className="text-sm font-bold text-slate-500 dark:text-text-secondary">{metric.label}</p>
                                        <p className={`text-4xl font-extrabold tracking-tight ${metric.tone}`}>{metric.value}</p>
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
                    className="min-w-0 border border-slate-200/90 bg-slate-50/80 p-5 shadow-[0_14px_36px_rgba(15,23,42,0.05)] dark:border-white/10 dark:bg-white/[0.035] sm:p-7"
                    style={continuous(30)}
                >
                    <div className="mb-6 flex items-center gap-3.5">
                        <span className="flex size-12 shrink-0 items-center justify-center bg-primary/10 text-primary" style={continuous(16)}>
                            <CirclePlus size={24} strokeWidth={2.1} />
                        </span>
                        <div>
                            <h3 id="todo-create-heading" className="text-lg font-bold text-slate-900 dark:text-white">新建任务</h3>
                            <p className="mt-0.5 text-sm text-slate-500 dark:text-text-secondary">快速记录，再补充时间与优先级。</p>
                        </div>
                    </div>

                    <div className="flex flex-col gap-6">
                        <div className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
                            <input
                                value={createDraft.title}
                                onChange={(e) => setCreateDraft((prev) => ({ ...prev, title: e.target.value }))}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') {
                                        e.preventDefault();
                                        handleCreateTask();
                                    }
                                }}
                                className={`${inputClass} min-h-[52px] flex-1 text-[15px]`}
                                style={continuous(18)}
                                placeholder="任务标题（回车可创建）"
                            />
                            <button
                                type="button"
                                onClick={handleCreateTask}
                                disabled={saving}
                                className={`${btnPrimary} shrink-0 sm:min-w-[132px]`}
                                style={continuous(18)}
                            >
                                <CirclePlus size={19} />
                                创建
                            </button>
                        </div>

                        <RecurrencePicker
                            value={createDraft.recurrence}
                            hint={createRecurrenceHint}
                            onChange={(next) =>
                                setCreateDraft((prev) => ({
                                    ...prev,
                                    recurrence: next,
                                    // 打开重复时如果还没选日期，默认从今天开始，省掉一次多余的操作
                                    dueDate: next.freq !== 'none' && !prev.dueDate ? todayInput() : prev.dueDate
                                }))
                            }
                        />

                        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                            <div>
                                <span className={fieldLabelClass}>优先级</span>
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
                            </div>
                            <div>
                                <span className={fieldLabelClass}>{createLabels.date}</span>
                                <ProjectNativePicker
                                    type="date"
                                    value={createDraft.dueDate}
                                    placeholder={createLabels.datePlaceholder}
                                    onChange={(nextValue) =>
                                        setCreateDraft((prev) => ({
                                            ...prev,
                                            dueDate: nextValue,
                                            dueTime: nextValue ? prev.dueTime : ''
                                        }))
                                    }
                                />
                            </div>
                            <div>
                                <span className={fieldLabelClass}>{createLabels.time}</span>
                                <ProjectNativePicker
                                    type="time"
                                    value={createDraft.dueTime}
                                    placeholder={createDraft.dueDate ? createLabels.timePlaceholder : '请先选择日期'}
                                    disabled={!createDraft.dueDate}
                                    onChange={(nextValue) =>
                                        setCreateDraft((prev) => ({ ...prev, dueTime: nextValue }))
                                    }
                                />
                            </div>
                        </div>

                        <div>
                            <span className={fieldLabelClass}>任务描述</span>
                            <textarea
                                value={createDraft.descriptionMd}
                                onChange={(e) => setCreateDraft((prev) => ({ ...prev, descriptionMd: e.target.value }))}
                                placeholder="输入任务描述或备注..."
                                rows={4}
                                className={`${inputClass} resize-y text-[15px] leading-relaxed`}
                                style={continuous(18)}
                            />
                        </div>

                        <div>
                            <div className="mb-3 flex items-center justify-between gap-3">
                                <span className="text-[13px] font-semibold text-slate-600 dark:text-text-secondary">标签</span>
                                <button
                                    type="button"
                                    onClick={openCreateTagModal}
                                    className={`${btnGhost} text-primary hover:bg-primary/10`}
                                    style={continuous(999)}
                                >
                                    <Tags size={17} />
                                    新建标签
                                </button>
                            </div>
                            {tags.length === 0 ? (
                                <p className="text-sm text-slate-400 dark:text-text-secondary/80">还没有标签，先创建一个吧。</p>
                            ) : (
                                <div className="flex flex-wrap gap-2.5">
                                    {tags.map((tag) => {
                                        const active = createDraft.tagIds.includes(tag.id);
                                        return (
                                            <button
                                                key={tag.id}
                                                type="button"
                                                aria-pressed={active}
                                                onClick={() => toggleCreateTag(tag.id)}
                                                className={`min-h-10 border px-4 text-sm font-semibold transition-[background-color,box-shadow,transform] active:scale-[0.97] ${active ? 'ring-2 ring-offset-1 ring-offset-transparent' : ''}`}
                                                style={{
                                                    ...continuous(999),
                                                    color: tag.color,
                                                    borderColor: `${tag.color}88`,
                                                    backgroundColor: active ? `${tag.color}26` : `${tag.color}12`,
                                                    ...(active ? { boxShadow: `0 0 0 2px ${tag.color}55` } : {})
                                                }}
                                            >
                                                #{tag.name}
                                            </button>
                                        );
                                    })}
                                </div>
                            )}
                        </div>
                    </div>
                </section>

                <section
                    aria-labelledby="todo-filter-heading"
                    className={sectionCardClass}
                    style={continuous(30)}
                >
                    <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                        <div className="flex items-center gap-3.5">
                            <span className="flex size-12 shrink-0 items-center justify-center bg-slate-200/70 text-slate-600 dark:bg-white/10 dark:text-slate-300" style={continuous(16)}>
                                <ListFilter size={23} strokeWidth={2.1} />
                            </span>
                            <div>
                                <h3 id="todo-filter-heading" className="text-lg font-bold text-slate-900 dark:text-white">查询与筛选</h3>
                                <p className="mt-0.5 text-sm text-slate-500 dark:text-text-secondary">组合条件，快速定位需要处理的任务。</p>
                            </div>
                        </div>
                        <button
                            type="button"
                            onClick={() => { setQuery(DEFAULT_QUERY); setSearchInput(''); }}
                            className={`${btnSecondary} self-start sm:self-auto`}
                            style={continuous(999)}
                        >
                            <SlidersHorizontal size={17} />
                            重置筛选
                        </button>
                    </div>

                    <label className="relative block">
                        <Search className="pointer-events-none absolute left-4 top-1/2 z-10 -translate-y-1/2 text-slate-400" size={20} />
                        <input
                            value={searchInput}
                            onChange={(e) => setSearchInput(e.target.value)}
                            className={`${inputClass} min-h-[52px] pl-12 text-[15px]`}
                            style={continuous(18)}
                            placeholder="搜索任务标题或描述"
                        />
                    </label>

                    <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                        <div>
                            <span className={fieldLabelClass}>状态</span>
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
                        </div>
                        <div>
                            <span className={fieldLabelClass}>时间范围</span>
                            <ProjectSelect
                                className="w-full"
                                value={query.timeFilter}
                                options={TIME_OPTIONS.map((option) => ({ value: option.value, label: option.label }))}
                                onChange={(nextValue) =>
                                    setQuery((prev) => ({
                                        ...prev,
                                        timeFilter: nextValue as TodoTimeFilter
                                    }))
                                }
                            />
                        </div>
                        <div>
                            <span className={fieldLabelClass}>优先级</span>
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
                        </div>
                        <div>
                            <span className={fieldLabelClass}>排序方式</span>
                            <ProjectSelect
                                className="w-full"
                                value={query.sortBy}
                                options={SORT_OPTIONS.map((option) => ({ value: option.value, label: option.label }))}
                                onChange={(nextValue) =>
                                    setQuery((prev) => ({
                                        ...prev,
                                        sortBy: nextValue as TodoSortBy
                                    }))
                                }
                            />
                        </div>
                        <div>
                            <span className={fieldLabelClass}>排序方向</span>
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
                        <p className="flex items-end pb-1 text-sm leading-relaxed text-slate-500 dark:text-text-secondary">{orderHint}</p>
                    </div>

                    <div className="mt-6 border-t border-slate-200/80 pt-5 dark:border-white/10">
                        <span className={`${fieldLabelClass} flex items-center gap-2`}>
                            <Tags size={16} />
                            按标签筛选
                        </span>
                        <div className="flex flex-wrap gap-2.5">
                            <button
                                type="button"
                                onClick={() => setQuery((prev) => ({ ...prev, tagId: undefined }))}
                                className={`min-h-10 border px-4 text-sm font-semibold transition-[background-color,transform] active:scale-[0.97] ${
                                    query.tagId == null
                                        ? 'border-primary/40 bg-primary/10 text-primary'
                                        : 'border-slate-200 text-slate-500 hover:bg-slate-100 dark:border-white/10 dark:hover:bg-white/10'
                                }`}
                                style={continuous(999)}
                            >
                                全部
                            </button>
                            {tags.map((tag) => {
                                const active = query.tagId === tag.id;
                                return (
                                    <span
                                        key={tag.id}
                                        className="inline-flex min-h-10 items-center border pl-4 pr-1.5 transition-colors"
                                        style={{
                                            ...continuous(999),
                                            borderColor: `${tag.color}88`,
                                            backgroundColor: active ? `${tag.color}26` : `${tag.color}12`
                                        }}
                                    >
                                        <button
                                            type="button"
                                            aria-pressed={active}
                                            onClick={() => setQuery((prev) => ({ ...prev, tagId: active ? undefined : tag.id }))}
                                            className="pr-2.5 text-sm font-semibold"
                                            style={{ color: tag.color }}
                                        >
                                            #{tag.name}
                                        </button>
                                        <button
                                            type="button"
                                            onClick={() => handleDeleteTag(tag)}
                                            aria-label={`删除标签 ${tag.name}`}
                                            className="flex size-8 shrink-0 items-center justify-center text-slate-400 transition-colors hover:bg-red-500/15 hover:text-red-500"
                                            style={continuous(999)}
                                        >
                                            <Trash2 size={15} />
                                        </button>
                                    </span>
                                );
                            })}
                        </div>
                    </div>
                </section>

                <section aria-labelledby="todo-list-heading" className="w-full min-w-0 pt-1">
                    <div className="mb-5 flex flex-wrap items-center justify-between gap-4">
                        <div className="flex items-center gap-3">
                            <h3 id="todo-list-heading" className="text-xl font-bold text-slate-900 dark:text-white">任务列表</h3>
                            <span className="inline-flex min-h-7 items-center bg-slate-200/80 px-3 text-sm font-bold text-slate-600 dark:bg-white/10 dark:text-slate-300" style={continuous(999)}>{tasks.length}</span>
                        </div>
                        <AppleCheckbox
                            checked={allVisibleSelected}
                            indeterminate={someVisibleSelected}
                            ariaLabel="全选可见任务"
                            label="全选"
                            onChange={(checked) => setSelectedTaskIds(checked ? tasks.map((task) => task.id) : [])}
                        />
                    </div>

                    {selectedTaskIds.length > 0 && (
                        <div
                            className="mb-4 flex flex-wrap items-center gap-3 border border-primary/20 bg-primary/[0.07] p-3 sm:px-5 sm:py-3.5 dark:border-primary/25 dark:bg-primary/10"
                            style={continuous(22)}
                        >
                            <span className="mr-auto text-sm font-bold text-slate-700 dark:text-white">
                                已选 {selectedTaskIds.length} 项
                            </span>
                            <button
                                type="button"
                                onClick={() => runBatchAction('complete')}
                                className={`${btnBase} min-h-11 bg-emerald-500/12 px-5 text-sm text-emerald-600 hover:bg-emerald-500/20 dark:text-emerald-400`}
                                style={continuous(999)}
                            >
                                <Check size={17} strokeWidth={2.6} />
                                标记完成
                            </button>
                            <button
                                type="button"
                                onClick={() => runBatchAction('uncomplete')}
                                className={`${btnBase} min-h-11 bg-blue-500/12 px-5 text-sm text-blue-600 hover:bg-blue-500/20 dark:text-blue-400`}
                                style={continuous(999)}
                            >
                                恢复待办
                            </button>
                            <button
                                type="button"
                                onClick={() => runBatchAction('delete')}
                                className={btnDanger}
                                style={continuous(999)}
                            >
                                <Trash2 size={16} />
                                删除
                            </button>
                            <button
                                type="button"
                                onClick={() => setSelectedTaskIds([])}
                                className={btnGhost}
                                style={continuous(999)}
                            >
                                取消选择
                            </button>
                        </div>
                    )}

                    <div className="-m-3 flex max-h-[70vh] flex-col gap-3 overflow-y-auto p-3">
                        {tasksLoading || tagsLoading ? (
                            <div className="border border-slate-200 bg-white/70 py-14 text-center text-sm text-slate-500 dark:border-white/10 dark:bg-white/[0.03]" style={continuous(24)}>加载中...</div>
                        ) : tasks.length === 0 ? (
                            <div className="flex flex-col items-center border border-dashed border-slate-300 bg-white/50 px-6 py-16 text-center dark:border-white/15 dark:bg-white/[0.02]" style={continuous(28)}>
                                <span className="mb-4 flex size-14 items-center justify-center bg-slate-100 text-slate-400 dark:bg-white/10" style={continuous(20)}><ListTodo size={26} /></span>
                                <p className="text-base font-bold text-slate-700 dark:text-slate-200">没有符合条件的任务</p>
                                <p className="mt-1.5 text-sm text-slate-400">新建一个任务，或调整上方筛选条件。</p>
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
                                        className={`group cursor-pointer p-4 shadow-[0_5px_16px_rgba(15,23,42,0.08),0_1px_3px_rgba(15,23,42,0.04)] transition-shadow hover:shadow-[0_10px_28px_rgba(15,23,42,0.12),0_2px_6px_rgba(15,23,42,0.06)] dark:shadow-[0_7px_20px_rgba(0,0,0,0.24),0_1px_3px_rgba(0,0,0,0.16)] sm:p-5 ${
                                            done
                                                ? 'bg-slate-50/75 dark:bg-white/[0.025]'
                                                : 'bg-white dark:bg-[#101725]'
                                        }`}
                                        style={continuous(26)}
                                        onClick={() => openDrawer(task)}
                                    >
                                        <div className="flex items-start gap-3.5">
                                            {canDragSort && <GripVertical className="mt-3 hidden shrink-0 cursor-grab text-slate-300 transition-colors group-hover:text-slate-400 sm:block" size={19} aria-hidden="true" />}
                                            <AppleCheckbox
                                                checked={selectedTaskIds.includes(task.id)}
                                                ariaLabel={`选择任务 ${task.title}`}
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
                                                className={`group/check relative mt-1.5 size-8 shrink-0 border-2 transition-[border-color,background-color,transform] active:scale-90 ${
                                                    done
                                                        ? 'bg-emerald-500 border-emerald-500'
                                                        : 'bg-white/80 dark:bg-[#0F172A] border-slate-300 dark:border-slate-500 hover:border-emerald-400'
                                                }`}
                                                style={continuous(999)}
                                                aria-label={done ? '标记为未完成' : '标记为完成'}
                                            >
                                                <Check className={`absolute inset-0 m-auto size-[18px] transition-opacity ${done ? 'opacity-100 text-white' : 'opacity-0 text-emerald-500 group-hover/check:opacity-100'}`} strokeWidth={2.8} />
                                            </button>
                                            <div className="min-w-0 flex-1 pt-1">
                                                <div className="flex flex-wrap items-center gap-2">
                                                    <p className={`min-w-0 truncate text-base font-bold ${done ? 'line-through text-slate-400' : 'text-slate-900 dark:text-white'}`}>{task.title}</p>
                                                    <span className={`inline-flex min-h-6 items-center border px-2.5 text-xs font-bold ${PRIORITY_CLASS[task.priority]}`} style={continuous(999)}>{PRIORITY_LABEL[task.priority]}</span>
                                                    {task.recurring && (
                                                        <span
                                                            className="inline-flex min-h-6 items-center gap-1.5 border border-primary/25 bg-primary/10 px-2.5 text-xs font-bold text-primary"
                                                            style={continuous(999)}
                                                            title={task.nextDueDate ? `下一次：${toDateInput(task.nextDueDate)}` : undefined}
                                                        >
                                                            <Repeat size={12} strokeWidth={2.6} />
                                                            {task.recurrenceLabel || '循环'}
                                                        </span>
                                                    )}
                                                </div>
                                                {!!task.descriptionMd && <p className="mt-2 line-clamp-1 text-sm text-slate-500 dark:text-text-secondary">{compactMarkdown(task.descriptionMd)}</p>}
                                                <div className="mt-3.5 flex flex-wrap items-center gap-x-5 gap-y-2 text-sm font-medium text-slate-400 dark:text-slate-500">
                                                    <span className="inline-flex items-center gap-1.5"><CalendarDays size={16} />{buildDueLabel(task)}</span>
                                                    {!!task.dueTime && <span className="inline-flex items-center gap-1.5"><Clock3 size={16} />{toTimeInput(task.dueTime)}</span>}
                                                    {(task.subtaskTotal || 0) > 0 && <span className="inline-flex items-center gap-1.5"><Check size={16} />子任务 {task.subtaskCompleted || 0}/{task.subtaskTotal || 0}</span>}
                                                </div>
                                                {!!task.tags?.length && (
                                                    <div className="mt-3 flex flex-wrap gap-2">
                                                        {task.tags.slice(0, 4).map((tag) => (
                                                            <span key={tag.id} className="inline-flex min-h-7 items-center px-3 text-xs font-semibold" style={{ ...continuous(999), color: tag.color, backgroundColor: `${tag.color}18` }}>#{tag.name}</span>
                                                        ))}
                                                    </div>
                                                )}
                                            </div>
                                            <div className="flex shrink-0 items-center gap-1.5 pt-0.5">
                                                {task.recurring && !done && (
                                                    <button
                                                        type="button"
                                                        onClick={(e) => { e.stopPropagation(); handleSkipOccurrence(task); }}
                                                        aria-label={`跳过本次 ${task.title}`}
                                                        title="跳过本次，顺延到下一个周期"
                                                        className={`${iconBtnClass} hover:bg-primary/10 hover:text-primary`}
                                                        style={continuous(999)}
                                                    >
                                                        <SkipForward size={19} />
                                                    </button>
                                                )}
                                                <button
                                                    type="button"
                                                    onClick={(e) => { e.stopPropagation(); handleDeleteTask(task); }}
                                                    aria-label={`删除任务 ${task.title}`}
                                                    className={`${iconBtnClass} hover:bg-red-500/10 hover:text-red-500 dark:hover:bg-red-500/15 dark:hover:text-red-400`}
                                                    style={continuous(999)}
                                                >
                                                    <Trash2 size={19} />
                                                </button>
                                                <ChevronRight className="ml-0.5 shrink-0 text-slate-300 transition-transform group-hover:translate-x-0.5 group-hover:text-slate-500" size={21} aria-hidden="true" />
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
                        className={`absolute right-0 top-0 h-full w-full max-w-[480px] overflow-y-auto border-l border-slate-200 bg-slate-50 p-6 transition-all duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] dark:border-white/10 dark:bg-background-dark ${
                            isDrawerVisible ? 'translate-x-0 opacity-100' : 'translate-x-8 opacity-0'
                        }`}
                        style={continuousLeft(36)}
                    >
                        <div className="mb-6 flex items-center justify-between gap-3">
                            <h3 className="text-xl font-bold text-slate-900 dark:text-white">编辑任务</h3>
                            <div className="flex items-center gap-2">
                                <button
                                    type="button"
                                    onClick={handleSaveDrawer}
                                    disabled={saving}
                                    className={`${btnBase} min-h-11 bg-primary px-6 text-sm text-white shadow-[0_6px_16px_rgba(0, 100, 225,0.24)] hover:bg-primary-hover`}
                                    style={continuous(999)}
                                >
                                    保存
                                </button>
                                <button
                                    type="button"
                                    onClick={closeDrawer}
                                    aria-label="关闭"
                                    className={iconBtnClass}
                                    style={continuous(999)}
                                >
                                    <span className="material-symbols-outlined text-[22px]">close</span>
                                </button>
                            </div>
                        </div>

                        <div className="flex flex-col gap-5">
                            <div>
                                <span className={fieldLabelClass}>标题</span>
                                <input
                                    value={drawerDraft.title}
                                    onChange={(e) => setDrawerDraft((prev) => (prev ? { ...prev, title: e.target.value } : prev))}
                                    className={`${inputClass} min-h-[52px] text-[15px]`}
                                    style={continuous(18)}
                                    placeholder="任务标题"
                                />
                            </div>
                            <div>
                                <span className={fieldLabelClass}>优先级</span>
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
                            <RecurrencePicker
                                value={drawerDraft.recurrence}
                                hint={drawerRecurrenceHint}
                                onChange={(next) =>
                                    setDrawerDraft((prev) =>
                                        prev
                                            ? {
                                                  ...prev,
                                                  recurrence: next,
                                                  dueDate:
                                                      next.freq !== 'none' && !prev.dueDate
                                                          ? todayInput()
                                                          : prev.dueDate
                                              }
                                            : prev
                                    )
                                }
                            />

                            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                                <div>
                                    <span className={fieldLabelClass}>{drawerLabels.date}</span>
                                    <ProjectNativePicker
                                        type="date"
                                        value={drawerDraft.dueDate}
                                        placeholder={drawerLabels.datePlaceholder}
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
                                </div>
                                <div>
                                    <span className={fieldLabelClass}>{drawerLabels.time}</span>
                                    <ProjectNativePicker
                                        type="time"
                                        value={drawerDraft.dueTime}
                                        placeholder={drawerDraft.dueDate ? drawerLabels.timePlaceholder : '请先选择日期'}
                                        disabled={!drawerDraft.dueDate}
                                        onChange={(nextValue) =>
                                            setDrawerDraft((prev) =>
                                                prev ? { ...prev, dueTime: nextValue } : prev
                                            )
                                        }
                                    />
                                </div>
                            </div>
                            {drawerTask.recurring && (
                                <button
                                    type="button"
                                    onClick={() => handleSkipOccurrence(drawerTask)}
                                    className={`${btnBase} min-h-12 w-full border border-primary/25 bg-primary/[0.08] px-5 text-[15px] text-primary hover:bg-primary/15`}
                                    style={continuous(18)}
                                >
                                    <SkipForward size={18} />
                                    跳过本次，顺延到下一个周期
                                </button>
                            )}
                            <div>
                                <span className={fieldLabelClass}>标签</span>
                                {tags.length === 0 ? (
                                    <p className="text-sm text-slate-400 dark:text-text-secondary/80">还没有标签。</p>
                                ) : (
                                    <div className="flex flex-wrap gap-2.5">
                                        {tags.map((tag) => {
                                            const active = drawerDraft.tagIds.includes(tag.id);
                                            return (
                                                <button
                                                    key={tag.id}
                                                    type="button"
                                                    aria-pressed={active}
                                                    onClick={() => toggleDrawerTag(tag.id)}
                                                    className="min-h-10 border px-4 text-sm font-semibold transition-[background-color,box-shadow,transform] active:scale-[0.97]"
                                                    style={{
                                                        ...continuous(999),
                                                        color: tag.color,
                                                        borderColor: `${tag.color}88`,
                                                        backgroundColor: active ? `${tag.color}26` : `${tag.color}12`,
                                                        ...(active ? { boxShadow: `0 0 0 2px ${tag.color}55` } : {})
                                                    }}
                                                >
                                                    #{tag.name}
                                                </button>
                                            );
                                        })}
                                    </div>
                                )}
                            </div>
                            <div>
                                <span className={fieldLabelClass}>任务描述</span>
                                <textarea
                                    value={drawerDraft.descriptionMd}
                                    onChange={(e) => setDrawerDraft((prev) => (prev ? { ...prev, descriptionMd: e.target.value } : prev))}
                                    rows={5}
                                    placeholder="可编辑任务描述"
                                    className={`${inputClass} resize-y text-[15px] leading-relaxed`}
                                    style={continuous(18)}
                                />
                            </div>

                            <div className={`${panelClass} p-4`} style={continuous(24)}>
                                <div className="mb-2.5 flex items-center justify-between text-sm font-semibold text-slate-500 dark:text-text-secondary">
                                    <span>子任务 {drawerTask.subtaskCompleted || 0}/{drawerTask.subtaskTotal || 0}</span>
                                    <span>{drawerTask.subtaskProgress || 0}%</span>
                                </div>
                                <div className="mb-4 h-2 overflow-hidden rounded-full bg-slate-200 dark:bg-white/10">
                                    <div className="h-full rounded-full bg-primary transition-[width] duration-300" style={{ width: `${drawerTask.subtaskProgress || 0}%` }} />
                                </div>
                                <div className="flex flex-col gap-2">
                                    {(drawerTask.subtasks || []).map((subtask) => {
                                        const done = subtask.status === 'completed';
                                        return (
                                            <div key={subtask.id} className={`${softClass} flex min-h-12 items-center gap-3 pl-3 pr-1.5`} style={continuous(16)}>
                                                <button
                                                    type="button"
                                                    onClick={() => handleToggleSubtask(subtask.id, done)}
                                                    aria-label={done ? '标记子任务未完成' : '标记子任务完成'}
                                                    className={`relative flex size-6 shrink-0 items-center justify-center rounded-full border-2 transition-[background-color,border-color,transform] active:scale-90 ${
                                                        done ? 'border-emerald-500 bg-emerald-500 text-white' : 'border-slate-300 text-transparent hover:border-emerald-400 dark:border-slate-500'
                                                    }`}
                                                >
                                                    <Check size={14} strokeWidth={3} />
                                                </button>
                                                <span className={`flex-1 text-sm ${done ? 'text-slate-400 line-through' : 'text-slate-700 dark:text-white'}`}>{subtask.title}</span>
                                                <button
                                                    type="button"
                                                    onClick={() => handleDeleteSubtask(subtask.id)}
                                                    aria-label={`删除子任务 ${subtask.title}`}
                                                    className={`${btnBase} size-9 shrink-0 text-slate-400 hover:bg-red-500/10 hover:text-red-500`}
                                                    style={continuous(999)}
                                                >
                                                    <Trash2 size={16} />
                                                </button>
                                            </div>
                                        );
                                    })}
                                </div>
                                <div className="mt-3 flex gap-2.5">
                                    <input
                                        value={newSubtaskTitle}
                                        onChange={(e) => setNewSubtaskTitle(e.target.value)}
                                        onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), handleCreateSubtask())}
                                        className={`${inputClass} min-h-11 py-2 text-sm`}
                                        style={continuous(16)}
                                        placeholder="输入子任务并回车"
                                    />
                                    <button type="button" onClick={handleCreateSubtask} className={`${btnSecondary} shrink-0`} style={continuous(16)}>
                                        添加
                                    </button>
                                </div>
                            </div>

                            <button
                                type="button"
                                onClick={() => handleDeleteTask(drawerTask)}
                                className={`${btnBase} min-h-12 w-full bg-red-500 px-5 text-[15px] text-white shadow-[0_6px_16px_rgba(239,68,68,0.24)] hover:bg-red-600`}
                                style={continuous(18)}
                            >
                                <Trash2 size={18} />
                                删除任务
                            </button>
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
