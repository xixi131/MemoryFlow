import React, { useState } from 'react';
import { motion } from 'framer-motion';
import type { TodoPreviewData, TodoPreviewTask } from '../useIslandState';

// Accent color aligned with mac-island IslandTodoVisualStyle.accent (system orange).
const ACCENT = 'rgb(255,149,0)';

// Number of task rows shown before scrolling — matches Mac maximumVisibleTasks.
const MAX_VISIBLE_TASKS = 6;

// Scroll distance (px) over which the header collapses into the compact pinned header.
const HEADER_COLLAPSE_DISTANCE = 60;

// Priority labels + colors — mirrors mac-island IslandTodoPriority.title / .color.
const PRIORITY_STYLE: Record<TodoPreviewTask['priority'], { label: string; color: string }> = {
    high: { label: '紧急', color: 'rgba(255,59,48,0.94)' },
    medium: { label: '重要', color: 'rgba(255,149,0,0.92)' },
    low: { label: '普通', color: 'rgba(255,255,255,0.72)' },
    none: { label: '', color: 'rgba(255,255,255,0.42)' },
};

// Due text formatter — mirrors mac-island IslandExpandedTodoContentLayout.dueText.
const formatTodoDue = (task: TodoPreviewTask): string => {
    if (task.status === 'completed') return '已完成';
    if (task.overdue) return '已逾期';
    if (!task.dueDate) return '未设置日期';

    const time = task.dueTime ? String(task.dueTime).slice(0, 5) : '';

    const parts = String(task.dueDate).split('-');
    const year = Number(parts[0]);
    const month = Number(parts[1]);
    const day = Number(parts[2]);

    let diffDays: number | null = null;
    if (parts.length === 3 && !Number.isNaN(year) && !Number.isNaN(month) && !Number.isNaN(day)) {
        const now = new Date();
        const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const dueDay = new Date(year, month - 1, day);
        diffDays = Math.round((dueDay.getTime() - startToday.getTime()) / 86400000);
    }

    if (task.dueToday || diffDays === 0) {
        return time ? `今日 ${time}` : '今日到期';
    }
    if (diffDays === 1) {
        return time ? `明日 ${time}` : '明日到期';
    }

    if (!Number.isNaN(month) && !Number.isNaN(day)) {
        const dateText = `${month}月${day}日`;
        return time ? `${dateText} ${time}` : dateText;
    }
    return '未设置日期';
};

// Framer-motion entrance variants — staggered opacity + 5px y offset per row.
const containerVariants = {
    hidden: { opacity: 0 },
    visible: { opacity: 1, transition: { staggerChildren: 0.05, delayChildren: 0.1 } },
};
const itemVariants = {
    hidden: { opacity: 0, y: 5 },
    visible: {
        opacity: 1,
        y: 0,
        transition: { type: 'spring' as const, stiffness: 300, damping: 24 },
    },
};

interface ExpandedTodoCardProps {
    todoPreview: TodoPreviewData;
    todoPendingOps: Record<number, boolean>;
    onToggleTask: (e: React.MouseEvent, taskId: number) => void;
}

const CounterCell: React.FC<{
    value: number;
    label: string;
    accent?: boolean;
    urgent?: boolean;
    compact?: boolean;
}> = ({ value, label, accent = false, urgent = false, compact = false }) => (
    <div className={`flex-1 min-w-0 ${compact ? 'flex items-baseline gap-1.5' : 'flex flex-col items-start gap-0.5'}`}>
        <span
            className={`${compact ? 'text-[18px]' : 'text-[34px]'} font-bold leading-none tracking-tight`}
            style={{ color: urgent ? 'rgba(255,59,48,0.92)' : '#ffffff' }}
        >
            {value}
        </span>
        <span
            className={`${compact ? 'text-[11px]' : 'text-[13px]'} font-semibold leading-none truncate`}
            style={{ color: accent ? ACCENT : 'rgba(255,255,255,0.68)' }}
        >
            {label}
        </span>
    </div>
);

const ExpandedTodoCard: React.FC<ExpandedTodoCardProps> = ({
    todoPreview,
    todoPendingOps,
    onToggleTask,
}) => {
    const [scrollTop, setScrollTop] = useState(0);
    const collapseProgress = Math.min(Math.max(scrollTop / HEADER_COLLAPSE_DISTANCE, 0), 1);

    const tasks = todoPreview.tasks.slice(0, MAX_VISIBLE_TASKS);

    return (
        <div className="relative flex flex-col h-full">
            {/* Scrollable content */}
            <div
                className="flex-1 min-h-0 overflow-y-auto pr-1"
                style={{ scrollbarWidth: 'none' }}
                onScroll={(e) => setScrollTop(e.currentTarget.scrollTop)}
            >
                <motion.div variants={containerVariants} initial="hidden" animate="visible">
                    {/* Stacked counter row */}
                    <motion.div variants={itemVariants} className="mb-4">
                        <div
                            className="flex gap-2"
                            style={{
                                transform: `scale(${1 - collapseProgress * 0.18})`,
                                transformOrigin: 'top left',
                                opacity: 1 - collapseProgress * 0.5,
                            }}
                        >
                            <CounterCell value={Math.max(todoPreview.pending, 0)} label="待完成" accent />
                            <CounterCell value={Math.max(todoPreview.dueToday, 0)} label="今日到期" />
                            <CounterCell
                                value={Math.max(todoPreview.overdue, 0)}
                                label="已逾期"
                                urgent={todoPreview.overdue > 0}
                            />
                        </div>
                    </motion.div>

                    {/* Task rows or empty state */}
                    {tasks.length === 0 ? (
                        <motion.div
                            variants={itemVariants}
                            className="flex flex-col items-center justify-center gap-[5px] py-7"
                        >
                            <span className="material-symbols-outlined text-[17px]" style={{ color: ACCENT }}>
                                check_circle
                            </span>
                            <span className="text-[12px] font-semibold" style={{ color: 'rgba(255,255,255,0.66)' }}>
                                暂无待办
                            </span>
                            <span className="text-[10px] font-medium" style={{ color: 'rgba(255,255,255,0.42)' }}>
                                新的待办会显示在这里
                            </span>
                        </motion.div>
                    ) : (
                        <div className="flex flex-col gap-[7px]">
                            {tasks.map((task) => {
                                const completed = task.status === 'completed';
                                const priority = PRIORITY_STYLE[task.priority] ?? PRIORITY_STYLE.none;
                                return (
                                    <motion.div
                                        key={task.id}
                                        variants={itemVariants}
                                        className="flex items-center gap-[7px] px-0.5"
                                        style={{ height: 38, opacity: completed ? 0.64 : 1 }}
                                    >
                                        <button
                                            onClick={(e) => onToggleTask(e, task.id)}
                                            disabled={!!todoPendingOps[task.id]}
                                            className="flex items-center justify-center shrink-0 disabled:opacity-50 disabled:cursor-not-allowed"
                                        >
                                            <motion.span
                                                animate={{ scale: completed ? 1.08 : 1 }}
                                                transition={{ type: 'spring', stiffness: 320, damping: 22 }}
                                                className="material-symbols-outlined text-[20px] leading-none"
                                                style={{ color: completed ? ACCENT : 'rgba(255,255,255,0.42)' }}
                                            >
                                                {completed ? 'check_circle' : 'radio_button_unchecked'}
                                            </motion.span>
                                        </button>

                                        <div className="flex items-center gap-[7px] flex-1 min-w-0">
                                            <div className="flex flex-col flex-1 min-w-0 gap-px">
                                                <span
                                                    className={`text-[13px] font-semibold truncate ${completed ? 'line-through' : ''}`}
                                                    style={{ color: completed ? 'rgba(255,255,255,0.42)' : 'rgba(255,255,255,0.9)' }}
                                                >
                                                    {task.title || '未命名任务'}
                                                </span>
                                                <span
                                                    className="text-[10px] font-medium truncate"
                                                    style={{ color: task.overdue ? 'rgba(255,59,48,0.92)' : 'rgba(255,255,255,0.48)' }}
                                                >
                                                    {formatTodoDue(task)}
                                                </span>
                                            </div>
                                            {priority.label && (
                                                <span
                                                    className="text-[10px] font-bold shrink-0"
                                                    style={{ color: priority.color }}
                                                >
                                                    {priority.label}
                                                </span>
                                            )}
                                        </div>
                                    </motion.div>
                                );
                            })}
                        </div>
                    )}
                </motion.div>
            </div>

            {/* Scroll-collapse compact header + top glass fade */}
            {collapseProgress > 0.01 && (
                <div
                    className="absolute top-0 left-0 right-0 pointer-events-none"
                    style={{ opacity: collapseProgress }}
                >
                    <div
                        className="absolute top-0 left-0 right-0 h-[90px]"
                        style={{
                            background:
                                'linear-gradient(to bottom, rgba(0,0,0,0.98) 0%, rgba(0,0,0,0.85) 34%, rgba(0,0,0,0.45) 62%, rgba(0,0,0,0) 100%)',
                        }}
                    />
                    <div className="relative flex gap-2 px-0.5 pt-1 pb-2">
                        <CounterCell value={Math.max(todoPreview.pending, 0)} label="待完成" accent compact />
                        <CounterCell value={Math.max(todoPreview.dueToday, 0)} label="今日到期" compact />
                        <CounterCell
                            value={Math.max(todoPreview.overdue, 0)}
                            label="已逾期"
                            urgent={todoPreview.overdue > 0}
                            compact
                        />
                    </div>
                </div>
            )}

            {/* Bottom glass fade */}
            <div
                className="absolute bottom-0 left-0 right-0 h-[20px] pointer-events-none"
                style={{ background: 'linear-gradient(to top, rgba(0,0,0,0.98) 0%, rgba(0,0,0,0) 100%)' }}
            />
        </div>
    );
};

export default ExpandedTodoCard;
