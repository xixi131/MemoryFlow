import React, { useMemo } from 'react';
import {
    CartesianGrid,
    Legend,
    Line,
    LineChart,
    ResponsiveContainer,
    Tooltip,
    XAxis,
    YAxis
} from 'recharts';
import { TodoTrendDays, TodoTrendPointDTO, TodoTrendsDTO } from '../../services/todoApis';

type TrendLoadState = 'loading' | 'ready' | 'error';

const RANGE_OPTIONS: Array<{ value: TodoTrendDays; label: string }> = [
    { value: 7, label: '近 7 天' },
    { value: 30, label: '近 30 天' }
];

const formatAxisDate = (value: string) => {
    const [, month, day] = value.split('-');
    return month && day ? `${month}/${day}` : value;
};

const formatFullDate = (value: string) => value.replace(/-/g, '/');

type TodoTrendChartProps = {
    days: TodoTrendDays;
    trend: TodoTrendsDTO | null;
    loadState: TrendLoadState;
    errorMessage: string;
    onDaysChange: (days: TodoTrendDays) => void;
    onRetry: () => void;
};

const TodoTrendChart: React.FC<TodoTrendChartProps> = ({
    days,
    trend,
    loadState,
    errorMessage,
    onDaysChange,
    onRetry
}) => {

    const points = trend?.points ?? [];
    const isEmpty = loadState === 'ready' && points.length === 0;
    const isAllZero = useMemo(
        () =>
            points.length > 0 &&
            points.every((point) => point.createdTasks === 0 && point.completedTasks === 0),
        [points]
    );

    const renderChart = (data: TodoTrendPointDTO[]) => (
        <ResponsiveContainer width="100%" height="100%" minWidth={0} minHeight={260}>
            <LineChart data={data} margin={{ top: 16, right: 12, bottom: 4, left: -12 }} accessibilityLayer>
                <CartesianGrid strokeDasharray="3 3" stroke="currentColor" className="text-slate-200 dark:text-white/10" />
                <XAxis
                    dataKey="date"
                    tickFormatter={formatAxisDate}
                    tick={{ fill: '#64748b', fontSize: 12 }}
                    axisLine={{ stroke: '#cbd5e1' }}
                    tickLine={false}
                    minTickGap={22}
                />
                <YAxis
                    allowDecimals={false}
                    domain={[0, (dataMax: number) => Math.max(1, dataMax)]}
                    tick={{ fill: '#64748b', fontSize: 12 }}
                    axisLine={false}
                    tickLine={false}
                    width={42}
                />
                <Tooltip
                    labelFormatter={(label) => formatFullDate(String(label))}
                    formatter={(value, name) => [Number(value), name === 'createdTasks' ? '创建任务' : '完成任务']}
                    contentStyle={{
                        borderRadius: 8,
                        border: '1px solid rgb(203 213 225)',
                        backgroundColor: 'rgba(255, 255, 255, 0.96)',
                        color: '#0f172a'
                    }}
                />
                <Legend
                    verticalAlign="top"
                    align="right"
                    formatter={(value) => (value === 'createdTasks' ? '创建任务' : '完成任务')}
                    wrapperStyle={{ fontSize: 12, paddingBottom: 8 }}
                />
                <Line
                    type="monotone"
                    dataKey="createdTasks"
                    name="createdTasks"
                    stroke="#2563eb"
                    strokeWidth={2.5}
                    dot={data.length <= 7 ? { r: 3 } : false}
                    activeDot={{ r: 5 }}
                    isAnimationActive={false}
                />
                <Line
                    type="monotone"
                    dataKey="completedTasks"
                    name="completedTasks"
                    stroke="#10b981"
                    strokeWidth={2.5}
                    dot={data.length <= 7 ? { r: 3 } : false}
                    activeDot={{ r: 5 }}
                    isAnimationActive={false}
                />
            </LineChart>
        </ResponsiveContainer>
    );

    return (
        <section
            aria-labelledby="todo-trend-heading"
            className="rounded-lg border border-slate-200 bg-white/70 p-4 dark:border-white/10 dark:bg-white/5 sm:p-5"
        >
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h3 id="todo-trend-heading" className="text-lg font-bold text-slate-900 dark:text-white">任务趋势</h3>
                    <p className="mt-1 text-sm text-slate-500 dark:text-text-secondary">每日创建与完成任务数量</p>
                </div>
                <div
                    aria-label="趋势日期范围"
                    className="grid w-full grid-cols-2 gap-1 rounded-lg bg-slate-200/70 p-1 dark:bg-white/10 sm:w-[220px]"
                >
                    {RANGE_OPTIONS.map((option) => (
                        <button
                            key={option.value}
                            type="button"
                            aria-pressed={days === option.value}
                            onClick={() => onDaysChange(option.value)}
                            className={`min-h-9 rounded-md px-3 py-1.5 text-sm font-bold transition-colors ${
                                days === option.value
                                    ? 'bg-white text-slate-900 shadow-sm dark:bg-surface-dark dark:text-white'
                                    : 'text-slate-500 hover:text-slate-900 dark:text-text-secondary dark:hover:text-white'
                            }`}
                        >
                            {option.label}
                        </button>
                    ))}
                </div>
            </div>

            <div className="relative mt-4 h-[320px] min-w-0" aria-live="polite" aria-busy={loadState === 'loading'}>
                {loadState === 'loading' && (
                    <div className="flex h-full items-center justify-center text-sm text-slate-500 dark:text-text-secondary">
                        趋势加载中...
                    </div>
                )}
                {loadState === 'error' && (
                    <div className="flex h-full flex-col items-center justify-center gap-3 text-center">
                        <div>
                            <p className="font-bold text-slate-800 dark:text-white">趋势暂时无法加载</p>
                            <p className="mt-1 text-sm text-slate-500 dark:text-text-secondary">{errorMessage}</p>
                        </div>
                        <button
                            type="button"
                            onClick={onRetry}
                            className="rounded-lg bg-primary px-4 py-2 text-sm font-bold text-white hover:bg-blue-600"
                        >
                            重试
                        </button>
                    </div>
                )}
                {isEmpty && (
                    <div className="flex h-full items-center justify-center text-sm text-slate-500 dark:text-text-secondary">
                        当前范围暂无趋势数据
                    </div>
                )}
                {loadState === 'ready' && points.length > 0 && (
                    <>
                        {renderChart(points)}
                        {isAllZero && (
                            <p className="pointer-events-none absolute bottom-8 left-1/2 -translate-x-1/2 rounded-md bg-white/90 px-3 py-1.5 text-xs font-medium text-slate-500 shadow-sm dark:bg-surface-dark/90 dark:text-text-secondary">
                                当前范围暂无任务变化
                            </p>
                        )}
                    </>
                )}
            </div>
        </section>
    );
};

export default TodoTrendChart;
