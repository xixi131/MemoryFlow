import { useReducer, useRef, useEffect, useCallback } from 'react';
import request from '../utils/request';
import {
    ACTIVITY_COLLAPSE_DURATION_SECONDS,
    ACTIVITY_OPEN_DURATION_SECONDS,
} from './islandGeometry';
import type { IslandTransitionKind } from './islandMotionTokens';

// ============================================================
// Types
// ============================================================

export interface MusicData {
    title: string;
    artist: string;
    coverUrl: string;
    themeColor: string;
    isPlaying: boolean;
    position: number;
    duration: number;
    status: string;
    lastUpdate: number;
}

export interface SubjectLight {
    id: number;
    title: string;
    icon: string;
    colorClass: string;
    progress: number;
    pendingReviewCount: number;
    lightStatus: 'green' | 'yellow' | 'red';
    goalTitle: string;
}

export interface WidgetData {
    totalPendingReviews: number;
    totalCompletedToday: number;
    subjects: SubjectLight[];
    lightStatus?: 'GREEN' | 'YELLOW' | 'RED';
    reminderTime?: string;
}

export interface TodoPreviewTask {
    id: number;
    title: string;
    status: 'todo' | 'completed';
    priority: 'high' | 'medium' | 'low' | 'none';
    dueDate?: string;
    dueTime?: string;
    overdue?: boolean;
    dueToday?: boolean;
}

export interface TodoPreviewData {
    pending: number;
    dueToday: number;
    overdue: number;
    tasks: TodoPreviewTask[];
}

const createEmptyTodoPreview = (): TodoPreviewData => ({
    pending: 0,
    dueToday: 0,
    overdue: 0,
    tasks: [],
});

// ============================================================
// State shape
// ============================================================

interface IslandState {
    isExpanded: boolean;
    isLoggedIn: boolean;
    forceCompactMode: boolean;
    isReminderActive: boolean;
    isHovered: boolean;
    greetingText: string | null;
    isGreetingActive: boolean;
    mode: 'app' | 'music';
    appDisplayMode: 'review' | 'todo';
    musicData: MusicData | null;
    localPosition: number;
    data: WidgetData;
    todoPreview: TodoPreviewData;
    todoPendingOps: Record<number, boolean>;
    isReminderCollapsing: boolean;
    isModeSwitchAnimating: boolean;
    isForceCompactTransitioning: boolean;
    activityOpenAnimToken: number;
}

const initialState: IslandState = {
    isExpanded: false,
    isLoggedIn: false,
    forceCompactMode: true,
    isReminderActive: false,
    isHovered: false,
    greetingText: null,
    isGreetingActive: false,
    mode: 'app',
    appDisplayMode: 'review',
    musicData: null,
    localPosition: 0,
    data: { totalPendingReviews: 0, totalCompletedToday: 0, subjects: [] },
    todoPreview: createEmptyTodoPreview(),
    todoPendingOps: {},
    isReminderCollapsing: false,
    isModeSwitchAnimating: false,
    isForceCompactTransitioning: false,
    activityOpenAnimToken: 0,
};

// ============================================================
// Action types
// ============================================================

type IslandAction =
    | { type: 'SET_EXPANDED'; payload: boolean }
    | { type: 'SET_LOGGED_IN'; payload: boolean }
    | { type: 'SET_FORCE_COMPACT'; payload: boolean }
    | { type: 'SET_REMINDER_ACTIVE'; payload: boolean }
    | { type: 'SET_HOVERED'; payload: boolean }
    | { type: 'SET_GREETING'; payload: { text: string | null; active: boolean } }
    | { type: 'SET_MODE'; payload: 'app' | 'music' }
    | { type: 'SET_APP_DISPLAY_MODE'; payload: 'review' | 'todo' }
    | { type: 'SET_MUSIC_DATA'; payload: MusicData | null }
    | { type: 'SET_LOCAL_POSITION'; payload: number }
    | { type: 'SET_DATA'; payload: WidgetData }
    | { type: 'SET_TODO_PREVIEW'; payload: TodoPreviewData }
    | { type: 'SET_TODO_PENDING_OP'; payload: { id: number; pending: boolean } }
    | { type: 'SET_REMINDER_COLLAPSING'; payload: boolean }
    | { type: 'SET_MODE_SWITCH_ANIMATING'; payload: boolean }
    | { type: 'SET_FORCE_COMPACT_TRANSITIONING'; payload: boolean }
    | { type: 'BUMP_ACTIVITY_ANIM_TOKEN' }
    | { type: 'LOGOUT' };

// ============================================================
// Reducer — all state transitions in one pure function
// ============================================================

function islandReducer(state: IslandState, action: IslandAction): IslandState {
    switch (action.type) {
        case 'SET_EXPANDED':
            return {
                ...state,
                isExpanded: action.payload,
                isHovered: action.payload ? false : state.isHovered,
            };
        case 'SET_LOGGED_IN':
            return { ...state, isLoggedIn: action.payload };
        case 'SET_FORCE_COMPACT':
            return { ...state, forceCompactMode: action.payload };
        case 'SET_REMINDER_ACTIVE':
            return { ...state, isReminderActive: action.payload };
        case 'SET_HOVERED':
            return { ...state, isHovered: action.payload };
        case 'SET_GREETING':
            return {
                ...state,
                greetingText: action.payload.text,
                isGreetingActive: action.payload.active,
            };
        case 'SET_MODE':
            return {
                ...state,
                mode: action.payload,
                isGreetingActive: action.payload === 'music' ? false : state.isGreetingActive,
                greetingText: action.payload === 'music' ? null : state.greetingText,
            };
        case 'SET_APP_DISPLAY_MODE':
            return { ...state, appDisplayMode: action.payload };
        case 'SET_MUSIC_DATA':
            return { ...state, musicData: action.payload };
        case 'SET_LOCAL_POSITION':
            return { ...state, localPosition: action.payload };
        case 'SET_DATA':
            return { ...state, data: action.payload };
        case 'SET_TODO_PREVIEW':
            return { ...state, todoPreview: action.payload };
        case 'SET_TODO_PENDING_OP': {
            const { id, pending } = action.payload;
            if (pending) {
                return { ...state, todoPendingOps: { ...state.todoPendingOps, [id]: true } };
            }
            const next = { ...state.todoPendingOps };
            delete next[id];
            return { ...state, todoPendingOps: next };
        }
        case 'SET_REMINDER_COLLAPSING':
            return { ...state, isReminderCollapsing: action.payload };
        case 'SET_MODE_SWITCH_ANIMATING':
            return { ...state, isModeSwitchAnimating: action.payload };
        case 'SET_FORCE_COMPACT_TRANSITIONING':
            return { ...state, isForceCompactTransitioning: action.payload };
        case 'BUMP_ACTIVITY_ANIM_TOKEN':
            return { ...state, activityOpenAnimToken: state.activityOpenAnimToken + 1 };
        case 'LOGOUT':
            return {
                ...state,
                isLoggedIn: false,
                isExpanded: false,
                mode: 'app',
                forceCompactMode: false,
                isModeSwitchAnimating: false,
                isForceCompactTransitioning: false,
                todoPreview: createEmptyTodoPreview(),
                todoPendingOps: {},
            };
        default:
            return state;
    }
}

// ============================================================
// Visual-state → transition-kind resolution
// ============================================================

// The three shell "shapes" the island can rest in. Kept in sync with the
// widget's `showAnyActivity` derivation (activity ⇔ an activity source is
// present AND we are not force-compacted).
type VisualState = 'compact' | 'activity' | 'expanded';

/**
 * Resolve the framer-motion transition kind from the (previous → next) visual
 * state pair. Same-state renders fall through to hover enter/leave (only
 * meaningful in the compact pill) and finally to a benign default so callers
 * always receive a concrete kind.
 */
function resolveTransitionKind(
    prev: VisualState,
    next: VisualState,
    prevHovered: boolean,
    nextHovered: boolean,
): IslandTransitionKind {
    if (prev !== next) {
        if (prev === 'compact' && next === 'activity') return 'compactToActivity';
        if (prev === 'compact' && next === 'expanded') return 'compactToExpanded';
        if (prev === 'activity' && next === 'compact') return 'activityToCompact';
        if (prev === 'activity' && next === 'expanded') return 'activityToExpanded';
        if (prev === 'expanded' && next === 'compact') return 'expandedToCompact';
        if (prev === 'expanded' && next === 'activity') return 'expandedToActivity';
    } else if (next === 'compact') {
        if (!prevHovered && nextHovered) return 'hoverEnter';
        if (prevHovered && !nextHovered) return 'hoverLeave';
    }
    // No directional pair matched (steady state) — a harmless default; at rest
    // the animation targets do not change so the profile is never applied.
    return 'compactToActivity';
}

// ============================================================
// Hook
// ============================================================

export function useIslandState() {
    const [state, dispatch] = useReducer(islandReducer, initialState);

    // ── Refs that must stay in sync with state for use inside closures ──
    const isLoggedInRef = useRef(state.isLoggedIn);
    const modeRef = useRef(state.mode);
    const isExpandedRef = useRef(state.isExpanded);
    const forceCompactModeRef = useRef(state.forceCompactMode);
    const prevIsExpandedRef = useRef(false);
    const isModeSwitchAnimatingRef = useRef(false);

    // ── Previous VISUAL state (compact | activity | expanded) + hover, tracked
    //    across renders so we can resolve a per-transition motion kind. ──
    const prevVisualStateRef = useRef<VisualState>('compact');
    const prevHoveredRef = useRef(false);

    useEffect(() => { isLoggedInRef.current = state.isLoggedIn; }, [state.isLoggedIn]);
    useEffect(() => { modeRef.current = state.mode; }, [state.mode]);
    useEffect(() => { isExpandedRef.current = state.isExpanded; }, [state.isExpanded]);
    useEffect(() => { forceCompactModeRef.current = state.forceCompactMode; }, [state.forceCompactMode]);

    // ── Timer refs ───────────────────────────────────────────────────────
    const greetingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const reminderCollapseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const modeSwitchLongPressTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const modeSwitchCompactTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const modeSwitchExpandTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const modeSwitchUnlockTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const forceCompactTransitionTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const musicTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

    // ── Music position tracking refs ─────────────────────────────────────
    const lastTitleRef = useRef('');
    const initialSyncDoneRef = useRef(false);
    const lastServerPosRef = useRef(0);
    const reminderAutoOpenKeyRef = useRef<string | null>(null);
    const reminderDueRef = useRef(false);
    const reminderCheckInitializedRef = useRef(false);

    // ── IPC helper ───────────────────────────────────────────────────────
    const getIpc = () => {
        try { return (window as any).require('electron').ipcRenderer; } catch { return null; }
    };

    // ── Click-through helpers ────────────────────────────────────────────
    const enableClickThrough = useCallback(() => {
        getIpc()?.send('set-ignore-mouse-events', true, { forward: true });
    }, []);

    const disableClickThrough = useCallback(() => {
        getIpc()?.send('set-ignore-mouse-events', false);
    }, []);

    // ── Timer clear helpers ──────────────────────────────────────────────
    const clearModeSwitchLongPressTimer = useCallback(() => {
        if (modeSwitchLongPressTimerRef.current) {
            clearTimeout(modeSwitchLongPressTimerRef.current);
            modeSwitchLongPressTimerRef.current = null;
        }
    }, []);

    const clearModeSwitchSequenceTimers = useCallback(() => {
        [modeSwitchCompactTimerRef, modeSwitchExpandTimerRef, modeSwitchUnlockTimerRef].forEach(ref => {
            if (ref.current) { clearTimeout(ref.current); ref.current = null; }
        });
    }, []);

    const clearForceCompactTransitionTimer = useCallback(() => {
        if (forceCompactTransitionTimerRef.current) {
            clearTimeout(forceCompactTransitionTimerRef.current);
            forceCompactTransitionTimerRef.current = null;
        }
    }, []);

    // ── Force-compact with animated transition ───────────────────────────
    const setForceCompactModeWithTransition = useCallback((nextCompact: boolean) => {
        if (forceCompactModeRef.current === nextCompact) return;
        if (!nextCompact) dispatch({ type: 'BUMP_ACTIVITY_ANIM_TOKEN' });
        dispatch({ type: 'SET_FORCE_COMPACT_TRANSITIONING', payload: true });
        forceCompactModeRef.current = nextCompact;
        dispatch({ type: 'SET_FORCE_COMPACT', payload: nextCompact });
        clearForceCompactTransitionTimer();
        const ms = (nextCompact
            ? ACTIVITY_COLLAPSE_DURATION_SECONDS
            : ACTIVITY_OPEN_DURATION_SECONDS) * 1000 + (nextCompact ? 0 : 80);
        forceCompactTransitionTimerRef.current = setTimeout(() => {
            dispatch({ type: 'SET_FORCE_COMPACT_TRANSITIONING', payload: false });
            forceCompactTransitionTimerRef.current = null;
        }, ms);
    }, [clearForceCompactTransitionTimer]);

    // ── Collapse expanded ────────────────────────────────────────────────
    const collapseExpanded = useCallback((options?: { preserveHoverFocus?: boolean }) => {
        dispatch({ type: 'SET_EXPANDED', payload: false });
        if (options?.preserveHoverFocus) {
            dispatch({ type: 'SET_HOVERED', payload: true });
            disableClickThrough();
        } else {
            enableClickThrough();
        }
    }, [disableClickThrough, enableClickThrough]);

    // ── Data fetching ────────────────────────────────────────────────────
    const fetchData = useCallback(async () => {
        try {
            const [summaryRes, todoStatsRes, todoTasksRes] = await Promise.all([
                request({ url: '/widget/summary', method: 'get' }),
                request({ url: '/todos/stats', method: 'get' }),
                request({ url: '/todos/tasks', method: 'get', params: { status: 'todo', sortBy: 'due', sortOrder: 'asc' } }),
            ]);

            if (summaryRes?.code === 200) {
                dispatch({ type: 'SET_DATA', payload: summaryRes.data });
            } else if (summaryRes?.code === 401 || summaryRes?.code === 403) {
                localStorage.removeItem('token');
                localStorage.removeItem('refreshToken');
                localStorage.removeItem('tokenExpiresAt');
                dispatch({ type: 'SET_LOGGED_IN', payload: false });
            }

            if (todoStatsRes?.code === 200 || todoTasksRes?.code === 200) {
                const stats = todoStatsRes?.data || {};
                const todoTasks = Array.isArray(todoTasksRes?.data) ? todoTasksRes.data : [];
                dispatch({
                    type: 'SET_TODO_PREVIEW',
                    payload: {
                        pending: Number(stats.pendingTasks || 0),
                        dueToday: Number(stats.dueToday || 0),
                        overdue: Number(stats.overdueTasks || 0),
                        tasks: todoTasks.slice(0, 6).map((task: any) => ({
                            id: Number(task.id),
                            title: String(task.title || ''),
                            status: task.status === 'completed' ? 'completed' : 'todo',
                            priority: task.priority || 'none',
                            dueDate: task.dueDate,
                            dueTime: task.dueTime,
                            overdue: !!task.overdue,
                            dueToday: !!task.dueToday,
                        })),
                    },
                });
            }
        } catch (error) {
            console.error('Widget fetch error', error);
        }
    }, []);

    const getTimeGreeting = () => {
        const hour = new Date().getHours();
        const pick = (items: string[]) => items[Math.floor(Math.random() * items.length)];
        if (hour >= 5 && hour <= 8) return pick(['晨光微露', '破晓啦', '早安', '新的一天']);
        if (hour >= 9 && hour <= 11) return pick(['上午好', '阳光正好', '专注时刻', '展信佳']);
        if (hour >= 12 && hour <= 13) return pick(['午安', '小憩时间', '正午好']);
        if (hour >= 14 && hour <= 17) return pick(['下午好', '微风不燥', '日渐西斜']);
        if (hour >= 18 && hour <= 19) return pick(['傍晚好', '暮色降临', '黄昏好']);
        if (hour >= 20 && hour <= 23) return pick(['晚上好', '夜幕低垂', '星光亮起']);
        return pick(['夜深了', '万籁俱寂', '还在熬夜吗']);
    };

    const startGreeting = useCallback((name: string) => {
        if (!name) return;
        if (greetingTimeoutRef.current) clearTimeout(greetingTimeoutRef.current);
        dispatch({ type: 'SET_GREETING', payload: { text: `${getTimeGreeting()}，${name}`, active: true } });
        greetingTimeoutRef.current = setTimeout(() => {
            dispatch({ type: 'SET_GREETING', payload: { text: null, active: false } });
        }, 10000);
    }, []);

    const fetchUserName = useCallback(async () => {
        try {
            const res: any = await request({ url: '/auth/me', method: 'get' });
            if (res?.code === 200 && res.data) {
                const name = String(res.data.nickname || res.data.email || '').trim();
                if (name) startGreeting(name);
            }
        } catch (error) {
            console.error('User fetch error', error);
        }
    }, [startGreeting]);

    const handleLogout = useCallback(() => {
        localStorage.removeItem('token');
        localStorage.removeItem('refreshToken');
        localStorage.removeItem('tokenExpiresAt');
        clearModeSwitchLongPressTimer();
        clearModeSwitchSequenceTimers();
        clearForceCompactTransitionTimer();
        forceCompactModeRef.current = false;
        isModeSwitchAnimatingRef.current = false;
        dispatch({ type: 'LOGOUT' });
    }, [clearModeSwitchLongPressTimer, clearModeSwitchSequenceTimers, clearForceCompactTransitionTimer]);

    // ── IPC: auth + widget init ──────────────────────────────────────────
    useEffect(() => {
        const ipc = getIpc();
        ipc?.send('set-ignore-mouse-events', true, { forward: true });

        window.addEventListener('auth:logout', handleLogout);

        const token = localStorage.getItem('token');
        const refreshToken = localStorage.getItem('refreshToken');
        if (token || refreshToken) {
            dispatch({ type: 'SET_LOGGED_IN', payload: true });
            fetchData();
            fetchUserName();
        }

        ipc?.on('auth-token', (_event: any, auth: any) => {
            if (typeof auth === 'string') {
                localStorage.setItem('token', auth);
            } else if (auth && typeof auth === 'object') {
                if (auth.accessToken) localStorage.setItem('token', String(auth.accessToken));
                if (auth.refreshToken) localStorage.setItem('refreshToken', String(auth.refreshToken));
                if (typeof auth.expiresIn === 'number' && auth.expiresIn > 0) {
                    localStorage.setItem('tokenExpiresAt', String(Date.now() + auth.expiresIn * 1000));
                }
            }
            if (modeRef.current === 'app') {
                forceCompactModeRef.current = true;
                dispatch({ type: 'SET_FORCE_COMPACT_TRANSITIONING', payload: false });
                dispatch({ type: 'SET_FORCE_COMPACT', payload: true });
            }
            dispatch({ type: 'SET_LOGGED_IN', payload: true });
            fetchData();
            fetchUserName();
        });

        ipc?.on('auth-logout', handleLogout);

        const timer = setInterval(() => {
            if (localStorage.getItem('token')) fetchData();
        }, 60000);

        return () => {
            clearInterval(timer);
            window.removeEventListener('auth:logout', handleLogout);
            if (greetingTimeoutRef.current) clearTimeout(greetingTimeoutRef.current);
            ipc?.removeAllListeners('auth-token');
            ipc?.removeAllListeners('auth-logout');
        };
    }, [fetchData, fetchUserName, handleLogout]);

    // ── IPC: music data ──────────────────────────────────────────────────
    useEffect(() => {
        const ipc = getIpc();
        if (!ipc) return;

        const handleMusicUpdate = (_event: any, data: MusicData) => {
            if (musicTimeoutRef.current) { clearTimeout(musicTimeoutRef.current); musicTimeoutRef.current = null; }

            if (data && (data.status === 'Playing' || data.status === 'Paused')) {
                if (!isLoggedInRef.current && modeRef.current !== 'music') return;
                dispatch({ type: 'SET_MUSIC_DATA', payload: data });
                if (modeRef.current !== 'music') {
                    forceCompactModeRef.current = false;
                    dispatch({ type: 'SET_FORCE_COMPACT', payload: false });
                    dispatch({ type: 'SET_FORCE_COMPACT_TRANSITIONING', payload: false });
                    clearForceCompactTransitionTimer();
                }
                dispatch({ type: 'SET_MODE', payload: 'music' });
                if (data.status === 'Paused') {
                    musicTimeoutRef.current = setTimeout(() => {
                        dispatch({ type: 'SET_MODE', payload: 'app' });
                        dispatch({ type: 'SET_MUSIC_DATA', payload: null });
                    }, 30000);
                }
            } else if (data?.status === 'Stopped') {
                dispatch({ type: 'SET_MODE', payload: 'app' });
                dispatch({ type: 'SET_MUSIC_DATA', payload: null });
            }
        };

        ipc.on('music-data-update', handleMusicUpdate);
        return () => {
            ipc.removeListener('music-data-update', handleMusicUpdate);
            if (musicTimeoutRef.current) clearTimeout(musicTimeoutRef.current);
        };
    }, [clearForceCompactTransitionTimer]);

    // ── IPC: display mode from main process ──────────────────────────────
    useEffect(() => {
        const ipc = getIpc();
        if (!ipc) return;

        const handleDisplayModeChange = (_event: any, nextMode: 'review' | 'todo') => {
            dispatch({ type: 'SET_APP_DISPLAY_MODE', payload: nextMode === 'todo' ? 'todo' : 'review' });
            dispatch({ type: 'SET_EXPANDED', payload: false });
            if (!isModeSwitchAnimatingRef.current) {
                forceCompactModeRef.current = false;
                dispatch({ type: 'SET_FORCE_COMPACT', payload: false });
            }
        };

        ipc.on('widget-display-mode-changed', handleDisplayModeChange);
        ipc.send('get-widget-display-mode');
        return () => ipc.removeListener('widget-display-mode-changed', handleDisplayModeChange);
    }, []);

    // ── IPC: external collapse signal ────────────────────────────────────
    useEffect(() => {
        const ipc = getIpc();
        if (!ipc) return;
        const handleCollapse = () => { if (isExpandedRef.current) collapseExpanded(); };
        ipc.on('widget-collapse', handleCollapse);
        return () => ipc.removeListener('widget-collapse', handleCollapse);
    }, [collapseExpanded]);

    // ── Music position: local tick ───────────────────────────────────────
    useEffect(() => {
        if (!state.musicData?.isPlaying) return;
        const interval = setInterval(() => {
            dispatch(prev => ({
                type: 'SET_LOCAL_POSITION',
                payload: Math.min(state.localPosition + 1, state.musicData?.duration ?? Infinity),
            } as any));
        }, 1000);
        return () => clearInterval(interval);
    }, [state.musicData?.isPlaying, state.musicData?.duration]);

    // ── Music position: server sync ──────────────────────────────────────
    useEffect(() => {
        if (!state.musicData) return;
        const { position: serverPos, title, isPlaying } = state.musicData;
        const titleChanged = title !== lastTitleRef.current;

        if (titleChanged) {
            dispatch({ type: 'SET_LOCAL_POSITION', payload: serverPos });
            lastTitleRef.current = title;
            initialSyncDoneRef.current = true;
            lastServerPosRef.current = serverPos;
            return;
        }
        if (!initialSyncDoneRef.current) {
            dispatch({ type: 'SET_LOCAL_POSITION', payload: serverPos });
            initialSyncDoneRef.current = true;
            lastServerPosRef.current = serverPos;
            return;
        }
        const serverPosChanged = Math.abs(serverPos - lastServerPosRef.current) > 0.5;
        lastServerPosRef.current = serverPos;

        if (serverPosChanged) {
            if (Math.abs(serverPos - state.localPosition) > 2) {
                dispatch({ type: 'SET_LOCAL_POSITION', payload: serverPos });
            }
        } else if (!isPlaying && Math.abs(serverPos - state.localPosition) > 1) {
            dispatch({ type: 'SET_LOCAL_POSITION', payload: serverPos });
        }
    }, [state.musicData?.position, state.musicData?.title, state.musicData?.isPlaying]);

    // ── Reminder time check ──────────────────────────────────────────────
    useEffect(() => {
        const checkTime = () => {
            if (!state.data.reminderTime) {
                reminderDueRef.current = false;
                dispatch({ type: 'SET_REMINDER_ACTIVE', payload: false });
                return;
            }
            const [hours, minutes] = state.data.reminderTime.split(':').map(Number);
            if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return;

            const now = new Date();
            const reminderDate = new Date(now);
            reminderDate.setHours(hours, minutes, 0, 0);
            const isDueToday = now >= reminderDate;
            const reminderKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}-${state.data.reminderTime}`;
            const justReached = reminderCheckInitializedRef.current && isDueToday && !reminderDueRef.current;

            dispatch({ type: 'SET_REMINDER_ACTIVE', payload: isDueToday });

            if (
                justReached
                && reminderAutoOpenKeyRef.current !== reminderKey
                && modeRef.current === 'app'
                && forceCompactModeRef.current
                && !isExpandedRef.current
            ) {
                reminderAutoOpenKeyRef.current = reminderKey;
                setForceCompactModeWithTransition(false);
            }

            reminderDueRef.current = isDueToday;
            reminderCheckInitializedRef.current = true;
        };

        checkTime();
        const interval = setInterval(checkTime, 10000);
        return () => clearInterval(interval);
    }, [state.data.reminderTime, setForceCompactModeWithTransition]);

    // ── Reminder collapse animation ──────────────────────────────────────
    useEffect(() => {
        const startedFromExpanded = prevIsExpandedRef.current && !state.isExpanded;
        const hasActivity = state.mode === 'music'
            ? !!state.musicData
            : state.isLoggedIn;

        if (startedFromExpanded && hasActivity) {
            dispatch({ type: 'SET_REMINDER_COLLAPSING', payload: true });
            if (reminderCollapseTimerRef.current) clearTimeout(reminderCollapseTimerRef.current);
            reminderCollapseTimerRef.current = setTimeout(() => {
                dispatch({ type: 'SET_REMINDER_COLLAPSING', payload: false });
                reminderCollapseTimerRef.current = null;
            }, ACTIVITY_COLLAPSE_DURATION_SECONDS * 1000);
        } else if (state.isExpanded || !hasActivity) {
            if (reminderCollapseTimerRef.current) { clearTimeout(reminderCollapseTimerRef.current); reminderCollapseTimerRef.current = null; }
            dispatch({ type: 'SET_REMINDER_COLLAPSING', payload: false });
        }

        prevIsExpandedRef.current = state.isExpanded;
    }, [state.isExpanded, state.mode, state.musicData, state.isLoggedIn]);

    // ── Cleanup all timers on unmount ────────────────────────────────────
    useEffect(() => {
        return () => {
            [greetingTimeoutRef, reminderCollapseTimerRef, modeSwitchLongPressTimerRef,
             modeSwitchCompactTimerRef, modeSwitchExpandTimerRef, modeSwitchUnlockTimerRef,
             forceCompactTransitionTimerRef, musicTimeoutRef].forEach(ref => {
                if (ref.current) { clearTimeout(ref.current); ref.current = null; }
            });
        };
    }, []);

    // ── Mode switch (long press) ─────────────────────────────────────────
    const MODE_SWITCH_LONG_PRESS_MS = 420;
    const MODE_SWITCH_COMPACT_PHASE_MS = 320;
    const MODE_SWITCH_REOPEN_DELAY_MS = 70;

    const syncDisplayModeToMain = useCallback((nextMode: 'review' | 'todo') => {
        const ipc = getIpc();
        if (ipc) {
            ipc.send('set-widget-display-mode', nextMode);
        } else {
            dispatch({ type: 'SET_APP_DISPLAY_MODE', payload: nextMode });
        }
    }, []);

    const triggerActivityModeSwitch = useCallback((
        currentMode: 'review' | 'todo',
        showAppActivity: boolean
    ) => {
        if (state.mode !== 'app') return;
        if (!showAppActivity) return;
        if (isExpandedRef.current) return;
        if (isModeSwitchAnimatingRef.current) return;

        const nextMode: 'review' | 'todo' = currentMode === 'review' ? 'todo' : 'review';
        isModeSwitchAnimatingRef.current = true;
        dispatch({ type: 'SET_MODE_SWITCH_ANIMATING', payload: true });
        setForceCompactModeWithTransition(true);
        clearModeSwitchSequenceTimers();

        modeSwitchCompactTimerRef.current = setTimeout(() => {
            dispatch({ type: 'SET_APP_DISPLAY_MODE', payload: nextMode });
            syncDisplayModeToMain(nextMode);
            modeSwitchExpandTimerRef.current = setTimeout(() => {
                setForceCompactModeWithTransition(false);
            }, MODE_SWITCH_REOPEN_DELAY_MS);
        }, MODE_SWITCH_COMPACT_PHASE_MS);

        const unlockDelay = MODE_SWITCH_COMPACT_PHASE_MS + MODE_SWITCH_REOPEN_DELAY_MS
            + Math.round(ACTIVITY_COLLAPSE_DURATION_SECONDS * 1000);
        modeSwitchUnlockTimerRef.current = setTimeout(() => {
            isModeSwitchAnimatingRef.current = false;
            dispatch({ type: 'SET_MODE_SWITCH_ANIMATING', payload: false });
        }, unlockDelay);
    }, [state.mode, clearModeSwitchSequenceTimers, setForceCompactModeWithTransition, syncDisplayModeToMain]);

    // ── Media controls ───────────────────────────────────────────────────
    const sendMediaControl = useCallback((command: string) => {
        getIpc()?.send('media-control', command);
    }, []);

    // ── Todo toggle ──────────────────────────────────────────────────────
    const applyTodoTaskStatus = useCallback((
        preview: TodoPreviewData,
        taskId: number,
        completed: boolean
    ): TodoPreviewData => {
        const target = preview.tasks.find(t => t.id === taskId);
        if (!target) return preview;
        if ((target.status === 'completed') === completed) return preview;
        const delta = completed ? -1 : 1;
        return {
            ...preview,
            pending: Math.max(0, preview.pending + delta),
            dueToday: Math.max(0, preview.dueToday + (target.dueToday ? delta : 0)),
            overdue: Math.max(0, preview.overdue + (target.overdue ? delta : 0)),
            tasks: preview.tasks.map(t =>
                t.id === taskId ? { ...t, status: completed ? 'completed' : 'todo' } : t
            ),
        };
    }, []);

    const handleToggleTodoTask = useCallback(async (
        e: React.MouseEvent,
        taskId: number
    ) => {
        e.stopPropagation();
        if (state.todoPendingOps[taskId]) return;
        const target = state.todoPreview.tasks.find(t => t.id === taskId);
        if (!target) return;
        const willComplete = target.status !== 'completed';

        dispatch({ type: 'SET_TODO_PENDING_OP', payload: { id: taskId, pending: true } });
        dispatch({ type: 'SET_TODO_PREVIEW', payload: applyTodoTaskStatus(state.todoPreview, taskId, willComplete) });

        try {
            await request({ url: `/todos/tasks/${taskId}/status`, method: 'patch', data: { completed: willComplete } });
        } catch {
            dispatch({ type: 'SET_TODO_PREVIEW', payload: applyTodoTaskStatus(state.todoPreview, taskId, !willComplete) });
        } finally {
            dispatch({ type: 'SET_TODO_PENDING_OP', payload: { id: taskId, pending: false } });
        }
    }, [state.todoPendingOps, state.todoPreview, applyTodoTaskStatus]);

    // ── Resolve the current visual state + per-transition motion kind ─────
    // `hasAnyActivitySource` mirrors the widget's own derivation so the hook
    // and the widget always agree on what "activity" means.
    const hasAnyActivitySource =
        (state.mode === 'music' && !!state.musicData) ||
        (state.mode === 'app' && state.isLoggedIn);
    const currentVisualState: VisualState = state.isExpanded
        ? 'expanded'
        : (hasAnyActivitySource && !state.forceCompactMode)
            ? 'activity'
            : 'compact';
    const transitionKind = resolveTransitionKind(
        prevVisualStateRef.current,
        currentVisualState,
        prevHoveredRef.current,
        state.isHovered,
    );

    // Commit the resolved visual state AFTER render (mirrors prevIsExpandedRef),
    // so the next render can diff against it.
    useEffect(() => {
        prevVisualStateRef.current = currentVisualState;
        prevHoveredRef.current = state.isHovered;
    });

    return {
        state,
        dispatch,
        // resolved per-transition motion kind (drives shell timing in the widget)
        transitionKind,
        // refs needed by parent gesture handlers
        isExpandedRef,
        forceCompactModeRef,
        isLoggedInRef,
        modeRef,
        // actions
        enableClickThrough,
        disableClickThrough,
        collapseExpanded,
        setForceCompactModeWithTransition,
        clearModeSwitchLongPressTimer,
        clearModeSwitchSequenceTimers,
        clearForceCompactTransitionTimer,
        triggerActivityModeSwitch,
        sendMediaControl,
        handleToggleTodoTask,
        // timer refs needed by gesture handlers
        modeSwitchLongPressTimerRef,
        MODE_SWITCH_LONG_PRESS_MS,
    };
}
