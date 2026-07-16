import { Dispatch, SetStateAction, useCallback, useEffect, useRef, useState } from 'react';
import todoApis, {
    TodoApiResponse,
    TodoStatsDTO,
    TodoTaskDTO,
    TodoTaskQuery,
    TodoTrendDays,
    TodoTrendsDTO
} from '../services/todoApis';

export const TODO_SYNC_VISIBLE_INTERVAL_MS = 10_000;
export const TODO_SYNC_HIDDEN_INTERVAL_MS = 60_000;

type SyncLoadState = 'loading' | 'ready' | 'error';

type TodoSynchronizationOptions = {
    routeKey: string;
    taskQuery: TodoTaskQuery;
    trendDays: TodoTrendDays;
    initialStats: TodoStatsDTO;
};

type TodoSynchronizationResult = {
    tasks: TodoTaskDTO[];
    setTasks: Dispatch<SetStateAction<TodoTaskDTO[]>>;
    stats: TodoStatsDTO;
    statsLoadState: SyncLoadState;
    trend: TodoTrendsDTO | null;
    trendLoadState: SyncLoadState;
    trendError: string;
    tasksLoading: boolean;
    refreshNow: () => Promise<void>;
};

const isSuccessful = <T,>(response: TodoApiResponse<T> | undefined): response is TodoApiResponse<T> =>
    response?.code === 200 && response.data !== undefined && response.data !== null;

const errorMessage = (error: unknown, fallback: string) =>
    error instanceof Error && error.message ? error.message : fallback;

const isCanceled = (error: unknown) => {
    if (!error || typeof error !== 'object') return false;
    const candidate = error as { name?: string; code?: string };
    return candidate.name === 'CanceledError' || candidate.name === 'AbortError' || candidate.code === 'ERR_CANCELED';
};

export const useTodoSynchronization = ({
    routeKey,
    taskQuery,
    trendDays,
    initialStats
}: TodoSynchronizationOptions): TodoSynchronizationResult => {
    const [tasks, setTasks] = useState<TodoTaskDTO[]>([]);
    const [stats, setStats] = useState<TodoStatsDTO>(initialStats);
    const [trend, setTrend] = useState<TodoTrendsDTO | null>(null);
    const [tasksLoading, setTasksLoading] = useState(true);
    const [statsLoadState, setStatsLoadState] = useState<SyncLoadState>('loading');
    const [trendLoadState, setTrendLoadState] = useState<SyncLoadState>('loading');
    const [trendError, setTrendError] = useState('');
    const refreshRef = useRef<(supersede?: boolean) => Promise<void>>(() => Promise.resolve());

    const refreshNow = useCallback(() => refreshRef.current(true), []);
    const taskQueryKey = JSON.stringify(taskQuery);

    useEffect(() => {
        let disposed = false;
        let timer: number | null = null;
        let requestSequence = 0;
        let activeController: AbortController | null = null;
        let inFlight: Promise<void> | null = null;
        let queuedPromise: Promise<void> | null = null;
        let resolveQueued: (() => void) | null = null;

        const clearTimer = () => {
            if (timer !== null) {
                window.clearTimeout(timer);
                timer = null;
            }
        };

        const scheduleNext = () => {
            if (disposed || inFlight || queuedPromise) return;
            clearTimer();
            const delay = document.visibilityState === 'hidden'
                ? TODO_SYNC_HIDDEN_INTERVAL_MS
                : TODO_SYNC_VISIBLE_INTERVAL_MS;
            timer = window.setTimeout(() => {
                timer = null;
                void requestRefresh();
            }, delay);
        };

        const executeRefresh = () => {
            clearTimer();
            const sequence = ++requestSequence;
            const controller = new AbortController();
            activeController = controller;

            const taskRequest = todoApis
                .getTasks(taskQuery, controller.signal)
                .then((response) => {
                    if (disposed || sequence !== requestSequence) return;
                    if (!isSuccessful(response)) throw new Error(response?.message || '任务加载失败');
                    setTasks(Array.isArray(response.data) ? response.data : []);
                    setTasksLoading(false);
                })
                .catch((error) => {
                    if (!isCanceled(error) && !disposed && sequence === requestSequence) {
                        console.warn('Todo task synchronization failed', error);
                        setTasksLoading(false);
                    }
                });

            const statsRequest = todoApis
                .getStats(controller.signal)
                .then((response) => {
                    if (disposed || sequence !== requestSequence) return;
                    if (!isSuccessful(response)) throw new Error(response?.message || '任务统计加载失败');
                    setStats(response.data);
                    setStatsLoadState('ready');
                })
                .catch((error) => {
                    if (!isCanceled(error) && !disposed && sequence === requestSequence) {
                        console.warn('Todo summary synchronization failed', error);
                        setStatsLoadState((current) => (current === 'ready' ? current : 'error'));
                    }
                });

            const trendRequest = todoApis
                .getTrends({ days: trendDays }, controller.signal)
                .then((response) => {
                    if (disposed || sequence !== requestSequence) return;
                    if (!isSuccessful(response)) throw new Error(response?.message || '趋势加载失败');
                    setTrend(response.data);
                    setTrendError('');
                    setTrendLoadState('ready');
                })
                .catch((error) => {
                    if (!isCanceled(error) && !disposed && sequence === requestSequence) {
                        console.warn('Todo trend synchronization failed', error);
                        setTrendError(errorMessage(error, '趋势加载失败'));
                        setTrendLoadState((current) => (current === 'ready' ? current : 'error'));
                    }
                });

            const current = Promise.allSettled([taskRequest, statsRequest, trendRequest]).then(() => undefined);
            inFlight = current;
            current.finally(() => {
                if (inFlight === current) inFlight = null;
                if (activeController === controller) activeController = null;
                if (disposed) return;

                if (queuedPromise) {
                    const queuedResolver = resolveQueued;
                    queuedPromise = null;
                    resolveQueued = null;
                    executeRefresh().finally(() => queuedResolver?.());
                    return;
                }
                scheduleNext();
            });
            return current;
        };

        const requestRefresh = (supersede = false): Promise<void> => {
            if (disposed) return Promise.resolve();
            clearTimer();
            if (!inFlight) return executeRefresh();
            if (supersede) {
                requestSequence += 1;
                activeController?.abort();
            }
            if (!queuedPromise) {
                queuedPromise = new Promise<void>((resolve) => {
                    resolveQueued = resolve;
                });
            }
            return queuedPromise;
        };

        refreshRef.current = requestRefresh;

        const handleFocus = () => {
            void requestRefresh();
        };
        const handleVisibilityChange = () => {
            if (document.visibilityState === 'visible') {
                void requestRefresh();
            } else {
                scheduleNext();
            }
        };

        window.addEventListener('focus', handleFocus);
        document.addEventListener('visibilitychange', handleVisibilityChange);
        void requestRefresh();

        return () => {
            disposed = true;
            requestSequence += 1;
            clearTimer();
            activeController?.abort();
            resolveQueued?.();
            refreshRef.current = () => Promise.resolve();
            window.removeEventListener('focus', handleFocus);
            document.removeEventListener('visibilitychange', handleVisibilityChange);
        };
    }, [routeKey, taskQueryKey, trendDays]);

    return {
        tasks,
        setTasks,
        stats,
        statsLoadState,
        trend,
        trendLoadState,
        trendError,
        tasksLoading,
        refreshNow
    };
};
