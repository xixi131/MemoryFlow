import React, { useState, useEffect, useRef, useCallback, useMemo, useId } from 'react';
import { motion } from 'framer-motion';
import request from '../utils/request';

// 过渡弹簧参数（控制整体动画速度/回弹感）
const containerSpring: any = {
    type: "spring",
    stiffness: 280,
    damping: 30,
    mass: 1.2,
};

// ==========================
// 灵动岛形态控制参数（可手动调节）
// ==========================
// 连续曲率（superellipse smoothness）：
// 数值越小越圆润，数值越大越“硬朗”
const SQUIRCLE_SMOOTHNESS = 3.5; // 普通态底部连续曲率
const SQUIRCLE_SMOOTHNESS_ACTIVITY = 2.3; // 活动态（音乐/复习/待办）底部连续曲率

// --- 状态 1: 静止/空闲态 (Idle/Empty) ---
// 只有小胶囊，无任何活动时
const EAR_TENSION_IDLE = 0.4;       // 张力较小
const EAR_BLEND_HEIGHT_IDLE = 11;    // 融合高度最小 (e.g. 4-8px)

// --- 状态 2: 活动/音乐态 (Activity/Music) ---
// 胶囊变宽显示活动信息时（音乐/提醒都归活动态）
const EAR_TENSION_ACTIVITY = 0.3;   // 左上/右上液态连接“开口角度”强度（越大越外张）
const EAR_BLEND_HEIGHT_ACTIVITY = 22; // 左上/右上液态连接“下垂融合高度”（越大越圆润）

// --- 状态 3: 展开态 (Expanded) ---
// 完整的大卡片面板
const EAR_TENSION_EXPANDED = 0.7;   // 张力最大 (液态感最强)
const EAR_BLEND_HEIGHT_EXPANDED = 32; // 融合高度最大，消除大转角的夹角感 (e.g. 20-30px)

// 底部圆角半径（左下/右下）
const COLLAPSED_RADIUS_DEFAULT = 22; // 普通态底部圆角半径
const COLLAPSED_RADIUS_ACTIVITY = 50; // 活动态底部圆角半径（音乐/复习/待办）

// 已停用（提醒态独立形态参数）：提醒态已并入活动态统一控制，保留作备用
// const EAR_TENSION_REMINDER = 0.2;
// const EAR_BLEND_HEIGHT_REMINDER = 18;
// const COLLAPSED_RADIUS_REMINDER = 22;

// 活动态（音乐/复习/待办）统一收起动画参数
// 后续新增活动态时，只需要纳入 hasAnyActivitySource/showAnyActivity 判定即可复用
const ACTIVITY_COLLAPSE_DURATION_SECONDS = 0.85;
const ACTIVITY_COLLAPSE_CONTENT_DELAY_SECONDS = 0.47;
const ACTIVITY_SEGMENTED_TIMES = [0, 0.45, 0.55, 1];
const ACTIVITY_OPEN_DURATION_SECONDS = 0.56; // 活动态开启（普通态 -> 活动态）时长
const ACTIVITY_OPEN_CONTENT_DELAY_SECONDS = 0.1; // 活动态内容出现延迟（先扩展后显内容）
const ACTIVITY_OPEN_CONTENT_DURATION_SECONDS = 0.26; // 活动态内容淡入时长
const ACTIVITY_COLLAPSED_WIDTH = 240; // 活动态统一宽度（音乐/复习/待办/未来新增活动态）
const COLLAPSED_MUSIC_COVER_WIDTH = 24;
const COLLAPSED_MUSIC_COVER_HEIGHT = 27;
const COLLAPSED_MUSIC_COVER_RADIUS = 6.4;
const COLLAPSED_MUSIC_COVER_SMOOTHNESS = 1.92;
const EXPANDED_MUSIC_COVER_WIDTH = 72;
const EXPANDED_MUSIC_COVER_HEIGHT = 80;
const EXPANDED_MUSIC_COVER_RADIUS = 16;
const EXPANDED_MUSIC_COVER_SMOOTHNESS = 1.85;
const DEBUG_MUSIC_PIPELINE = false;

const musicDebugLog = (...args: any[]) => {
    if (DEBUG_MUSIC_PIPELINE) {
        console.log(...args);
    }
};

// Path generation function for liquid ears
const generateEarPath = (isLeft: boolean, tension: number, blendHeight: number) => {
    const width = 40; // Fixed large width to accommodate expansion
    
    // Visual width of the curve based on tension and height
    const curveWidth = blendHeight * tension;
    
    if (!isLeft) {
        // Right Ear (Island is on Left)
        // We use -1 as startX to ensure 1px overlap into the island body (gap fix)
        const startX = -1;
        
        // C command: CP1, CP2, EndPoint
        // CP1: (startX, 0) -> Vertical tangent at the connection
        // CP2: (startX + curveWidth, 0) -> Horizontal tangent at the top (y=0)
        // End: (startX + curveWidth + 4, 0) -> Slight extension to ensure smoothness
        return `M ${startX} ${blendHeight} 
                C ${startX} 0, ${startX + curveWidth} 0, ${startX + curveWidth + 4} 0 
                L ${startX} 0 Z`;
    } else {
        // Left Ear (Island is on Right)
        // We use width + 1 as startX to ensure 1px overlap into the island body (gap fix)
        const startX = width + 1;
        
        // Mirror logic for left side
        return `M ${startX} ${blendHeight} 
                C ${startX} 0, ${startX - curveWidth} 0, ${startX - curveWidth - 4} 0 
                L ${startX} 0 Z`;
    }
};


// Music data interface
interface MusicData {
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

// Music Waveform Component - Animated bars with Gradient
const MusicWaveform: React.FC<{ color: string; isPlaying: boolean; count?: number }> = ({ color, isPlaying, count = 5 }) => {
    const bars = Array.from({ length: count }, (_, i) => i);

    // Helper to ensure we have a valid hex for gradient manipulation
    const safeColor = /^#[0-9A-F]{6}$/i.test(color) ? color : '#22d3ee';

    return (
        <div className="flex items-center justify-center gap-[2px] h-6">
            {bars.map((i) => (
                <motion.div
                    key={i}
                    className="w-[3px] rounded-full"
                    style={{
                        background: `linear-gradient(180deg, ${safeColor} 0%, ${safeColor}33 100%)`,
                        transition: 'background 0.5s ease'
                    }}
                    initial={{ height: 4 }}
                    animate={isPlaying ? {
                        height: [4, 16, 8, 20, 6, 12, 4],
                    } : { height: 4 }}
                    transition={isPlaying ? {
                        duration: 2.2,
                        repeat: Infinity,
                        delay: i * 0.2,
                        ease: "easeInOut"
                    } : {
                        duration: 0.3,
                        ease: "easeOut"
                    }}
                />
            ))}
        </div>
    );
};

// Review Mode Icon (line style)
const ReviewModeIcon = () => {
    return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M6.5 4.5H17.5C18.3284 4.5 19 5.17157 19 6V18C19 18.8284 18.3284 19.5 17.5 19.5H6.5C5.67157 19.5 5 18.8284 5 18V6C5 5.17157 5.67157 4.5 6.5 4.5Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M9.5 4.5V19.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M13 8H16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M13 11H16" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
    );
};

// Interface for backend data
interface SubjectLight {
    id: number;
    title: string;
    icon: string;
    colorClass: string;
    progress: number;
    pendingReviewCount: number;
    lightStatus: 'green' | 'yellow' | 'red';
    goalTitle: string;
}

interface WidgetData {
    totalPendingReviews: number;
    totalCompletedToday: number;
    subjects: SubjectLight[];
    lightStatus?: 'GREEN' | 'YELLOW' | 'RED';
    reminderTime?: string;
}

interface TodoPreviewTask {
    id: number;
    title: string;
    status: 'todo' | 'completed';
    priority: 'high' | 'medium' | 'low' | 'none';
    dueDate?: string;
    dueTime?: string;
    overdue?: boolean;
    dueToday?: boolean;
}

interface TodoPreviewData {
    pending: number;
    dueToday: number;
    overdue: number;
    tasks: TodoPreviewTask[];
}

// Format time in mm:ss
const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
};

const formatTodoDue = (task: TodoPreviewTask): string => {
    if (task.status === 'completed') return '已完成';
    if (!task.dueDate) return '无截止日期';
    const date = String(task.dueDate).slice(5, 10);
    const time = task.dueTime ? String(task.dueTime).slice(0, 5) : '';
    return time ? `${date} ${time}` : date;
};

const createEmptyTodoPreview = (): TodoPreviewData => ({
    pending: 0,
    dueToday: 0,
    overdue: 0,
    tasks: []
});

// Helper to generate squircle path (bottom corners only, top flat)
// Using Superellipse Parametric Equation for iOS-like "Straight-to-Squircle" smoothness
// Formula: |x/a|^n + |y/b|^n = 1 with n=4.8 (approx)
const generateSquirclePath = (width: number, height: number, radius: number, smoothness: number) => {
    const r = Math.min(radius, width / 2, height / 2);
    const steps = 30; // Increased sampling for better precision

    // Start Top-Left -> Top-Right (Flat Top)
    let path = `M 0 0 L ${width} 0 L ${width} ${height - r}`;

    // Bottom-Right Corner (Superellipse 0 to 90 deg)
    const cx1 = width - r;
    const cy1 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        // x = cx + r * |cos t|^(2/n)
        // y = cy + r * |sin t|^(2/n)
        const x = cx1 + Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy1 + Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }

    // Bottom Edge
    path += ` L ${r} ${height}`;

    // Bottom-Left Corner (Superellipse 90 to 180 deg)
    const cx2 = r;
    const cy2 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI / 2 + (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx2 + Math.sign(cosT) * Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy2 + Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }

    // Left Edge -> Close
    path += ` L 0 0 Z`;
    return path;
};

// Helper for border stroke - OPEN at the top (U-shape)
const generateOpenSquirclePath = (width: number, height: number, radius: number, smoothness: number) => {
    const r = Math.min(radius, width / 2, height / 2);
    const steps = 30;

    // Start Top-Right -> Right Side
    let path = `M ${width} 0 L ${width} ${height - r}`;

    // Bottom-Right Corner
    const cx1 = width - r;
    const cy1 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx1 + Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy1 + Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }

    // Bottom Edge
    path += ` L ${r} ${height}`;

    // Bottom-Left Corner
    const cx2 = r;
    const cy2 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI / 2 + (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx2 + Math.sign(cosT) * Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy2 + Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }

    // Left Edge -> Top-Left
    path += ` L 0 0`;
    return path;
};

// Helper for Left Cap Background
const generateLeftCapPath = (height: number, radius: number, smoothness: number = SQUIRCLE_SMOOTHNESS) => {
    const w = 60;
    const r = radius;
    const steps = 30;
    
    // Rect Top-Right & Bottom-Right, Round Bottom-Left
    let path = `M 0 0 L ${w} 0 L ${w} ${height} L ${r} ${height}`;
    
    // Bottom-Left Corner
    const cx = r;
    const cy = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI / 2 + (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx + Math.sign(cosT) * Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy + Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }
    
    path += ` L 0 0 Z`;
    return path;
};

// Helper for Right Cap Background
const generateRightCapPath = (height: number, radius: number, smoothness: number = SQUIRCLE_SMOOTHNESS) => {
    const w = 60;
    const r = radius;
    const steps = 30;
    
    // Rect Top-Left, Round Bottom-Right
    let path = `M 0 0 L ${w} 0 L ${w} ${height - r}`;
    
    // Bottom-Right Corner
    const cx = w - r;
    const cy = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx + Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy + Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }
    
    path += ` L 0 ${height} Z`;
    return path;
};

// Full squircle path (4 rounded corners) for small cover/thumb visuals.
const generateFullSquirclePath = (width: number, height: number, radius: number, smoothness: number = 2.8) => {
    const r = Math.min(radius, width / 2, height / 2);
    const steps = 24;

    let path = `M ${r} 0 L ${width - r} 0`;

    // Top-right
    const cx1 = width - r;
    const cy1 = r;
    for (let i = 1; i <= steps; i++) {
        const t = -Math.PI / 2 + (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx1 + Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy1 + Math.sign(sinT) * Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }

    path += ` L ${width} ${height - r}`;

    // Bottom-right
    const cx2 = width - r;
    const cy2 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx2 + Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy2 + Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }

    path += ` L ${r} ${height}`;

    // Bottom-left
    const cx3 = r;
    const cy3 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI / 2 + (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx3 + Math.sign(cosT) * Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy3 + Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }

    path += ` L 0 ${r}`;

    // Top-left
    const cx4 = r;
    const cy4 = r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI + (Math.PI / 2) * (i / steps);
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx4 + Math.sign(cosT) * Math.pow(Math.abs(cosT), 2 / smoothness) * r;
        const y = cy4 + Math.sign(sinT) * Math.pow(Math.abs(sinT), 2 / smoothness) * r;
        path += ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }

    path += ` Z`;
    return path;
};

// Puffy cover path: all four edges participate in the curve, so the sides feel slightly "inflated".
const generatePuffyCoverPath = (width: number, height: number, radius: number, smoothness: number = 2) => {
    const steps = 72;
    const cx = width / 2;
    const cy = height / 2;
    const minSide = Math.min(width, height);
    const normalizedRadius = Math.max(0.1, Math.min(0.34, radius / minSide));
    const superellipseN = Math.max(
        3.8,
        Math.min(7.2, 3.9 + normalizedRadius * 8.5 + (2.4 - smoothness) * 2.2)
    );
    const exponent = 2 / superellipseN;

    let path = '';
    for (let i = 0; i <= steps; i++) {
        const t = -Math.PI / 2 + (Math.PI * 2 * i) / steps;
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx + (width / 2) * Math.sign(cosT) * Math.pow(Math.abs(cosT), exponent);
        const y = cy + (height / 2) * Math.sign(sinT) * Math.pow(Math.abs(sinT), exponent);
        path += `${i === 0 ? 'M' : 'L'} ${x.toFixed(2)} ${y.toFixed(2)} `;
    }
    path += 'Z';
    return path;
};

const SquircleCoverThumb: React.FC<{
    src?: string;
    width?: number;
    height?: number;
    radius?: number;
    smoothness?: number;
    shapeVariant?: 'rounded' | 'puffy';
    showGloss?: boolean;
    showRim?: boolean;
    className?: string;
    style?: React.CSSProperties;
    backgroundFill?: string;
    stroke?: string;
    strokeWidth?: number;
    placeholderIconClassName?: string;
}> = ({
    src,
    width = 22,
    height = 26,
    radius = 8.6,
    smoothness = 2.35,
    shapeVariant = 'rounded',
    showGloss = false,
    showRim = false,
    className,
    style,
    backgroundFill = 'rgba(255,255,255,0.1)',
    stroke = 'transparent',
    strokeWidth = 0.9,
    placeholderIconClassName = 'material-symbols-outlined text-[13px] text-white/50'
}) => {
    const rawId = useId();
    const clipId = useMemo(() => `cover-squircle-${rawId.replace(/:/g, '')}`, [rawId]);
    const glossId = useMemo(() => `cover-gloss-${rawId.replace(/:/g, '')}`, [rawId]);
    const shadeId = useMemo(() => `cover-shade-${rawId.replace(/:/g, '')}`, [rawId]);
    const rimId = useMemo(() => `cover-rim-${rawId.replace(/:/g, '')}`, [rawId]);
    const squirclePath = useMemo(
        () => shapeVariant === 'puffy'
            ? generatePuffyCoverPath(width, height, radius, smoothness)
            : generateFullSquirclePath(width, height, radius, smoothness),
        [width, height, radius, smoothness, shapeVariant]
    );

    return (
        <div
            className={`relative shrink-0 ${className || ''}`.trim()}
            style={{ width, height, ...style }}
        >
            <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="block">
                <defs>
                    <clipPath id={clipId}>
                        <path d={squirclePath} />
                    </clipPath>
                    <linearGradient id={glossId} x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="rgba(255,255,255,0.34)" />
                        <stop offset="22%" stopColor="rgba(255,255,255,0.14)" />
                        <stop offset="48%" stopColor="rgba(255,255,255,0.03)" />
                        <stop offset="70%" stopColor="rgba(255,255,255,0)" />
                    </linearGradient>
                    <linearGradient id={shadeId} x1="100%" y1="100%" x2="0%" y2="0%">
                        <stop offset="0%" stopColor="rgba(0,0,0,0.22)" />
                        <stop offset="28%" stopColor="rgba(0,0,0,0.1)" />
                        <stop offset="58%" stopColor="rgba(0,0,0,0)" />
                    </linearGradient>
                    <linearGradient id={rimId} x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="rgba(255,255,255,0.36)" />
                        <stop offset="35%" stopColor="rgba(255,255,255,0.12)" />
                        <stop offset="70%" stopColor="rgba(255,255,255,0.06)" />
                        <stop offset="100%" stopColor="rgba(255,255,255,0.14)" />
                    </linearGradient>
                </defs>

                <path d={squirclePath} fill={backgroundFill} />

                {src ? (
                    <image
                        href={src}
                        width={width}
                        height={height}
                        preserveAspectRatio="xMidYMid slice"
                        clipPath={`url(#${clipId})`}
                    />
                ) : null}

                {showGloss ? (
                    <>
                        <rect width={width} height={height} fill={`url(#${glossId})`} clipPath={`url(#${clipId})`} />
                        <rect width={width} height={height} fill={`url(#${shadeId})`} clipPath={`url(#${clipId})`} />
                    </>
                ) : null}

                <path
                    d={squirclePath}
                    fill="none"
                    stroke={showGloss && showRim ? `url(#${rimId})` : stroke}
                    strokeWidth={strokeWidth}
                    vectorEffect="non-scaling-stroke"
                />

            </svg>

            {!src ? (
                <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                    <span className={placeholderIconClassName}>music_note</span>
                </div>
            ) : null}
        </div>
    );
};

const DynamicIslandWidget: React.FC = () => {
    const [isExpanded, setIsExpanded] = useState(false);
    const [isLoggedIn, setIsLoggedIn] = useState(false);
    const [forceCompactMode, setForceCompactMode] = useState(true);
    const [isReminderActive, setIsReminderActive] = useState(false);
    const [isHovered, setIsHovered] = useState(false);
    const [greetingText, setGreetingText] = useState<string | null>(null);
    const [isGreetingActive, setIsGreetingActive] = useState(false);
    const islandHitRef = useRef<HTMLDivElement | null>(null);
    const forceCompactModeRef = useRef<boolean>(true);
    const isExpandedRef = useRef<boolean>(false);
    const prevIsExpandedRef = useRef<boolean>(false);
    const isModeSwitchAnimatingRef = useRef<boolean>(false);
    const greetingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
    const reminderCollapseTimerRef = useRef<NodeJS.Timeout | null>(null);
    const reminderAutoOpenKeyRef = useRef<string | null>(null);
    const reminderDueRef = useRef<boolean>(false);
    const reminderCheckInitializedRef = useRef<boolean>(false);
    const modeSwitchLongPressTimerRef = useRef<NodeJS.Timeout | null>(null);
    const modeSwitchCompactTimerRef = useRef<NodeJS.Timeout | null>(null);
    const modeSwitchExpandTimerRef = useRef<NodeJS.Timeout | null>(null);
    const modeSwitchUnlockTimerRef = useRef<NodeJS.Timeout | null>(null);
    const forceCompactTransitionTimerRef = useRef<NodeJS.Timeout | null>(null);
    const trackpadGestureResetTimerRef = useRef<NodeJS.Timeout | null>(null);
    const trackpadGestureCooldownTimerRef = useRef<NodeJS.Timeout | null>(null);
    const trackpadDeltaXRef = useRef(0);
    const trackpadDeltaYRef = useRef(0);
    const trackpadGestureLockedRef = useRef(false);

    // Music state
    const [mode, setMode] = useState<'app' | 'music'>('app');
    const [appDisplayMode, setAppDisplayMode] = useState<'review' | 'todo'>('review');
    const [musicData, setMusicData] = useState<MusicData | null>(null);
    const [localPosition, setLocalPosition] = useState(0);

    // Ref to track latest login state for use in IPC callbacks (avoids stale closure)
    const isLoggedInRef = useRef(isLoggedIn);
    const modeRef = useRef(mode);
    useEffect(() => {
        isLoggedInRef.current = isLoggedIn;
    }, [isLoggedIn]);
    useEffect(() => {
        modeRef.current = mode;
    }, [mode]);

    useEffect(() => {
        if (isExpanded) {
            setIsHovered(false);
        }
    }, [isExpanded]);

    useEffect(() => {
        isExpandedRef.current = isExpanded;
    }, [isExpanded]);

    useEffect(() => {
        forceCompactModeRef.current = forceCompactMode;
    }, [forceCompactMode]);

    const enableClickThrough = useCallback(() => {
        try {
            const { ipcRenderer } = (window as any).require('electron');
            ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
        } catch (e) { }
    }, []);

    const disableClickThrough = useCallback(() => {
        try {
            const { ipcRenderer } = (window as any).require('electron');
            ipcRenderer.send('set-ignore-mouse-events', false);
        } catch (e) { }
    }, []);

    const collapseExpanded = useCallback((options?: { preserveHoverFocus?: boolean }) => {
        setIsExpanded(false);
        if (options?.preserveHoverFocus) {
            setIsHovered(true);
            disableClickThrough();
            return;
        }
        enableClickThrough();
    }, [disableClickThrough, enableClickThrough]);
    const musicTimeoutRef = useRef<NodeJS.Timeout | null>(null);

    // Track when playback started (for simulating progress when server doesn't provide it)
    const playStartTimeRef = useRef<number | null>(null);
    const playStartPositionRef = useRef<number>(0);

    const startX = useRef<number | null>(null);
    const lastPointerXRef = useRef<number | null>(null);
    const activePointerIdRef = useRef<number | null>(null);
    const isGestureTrackingRef = useRef(false);
    const [data, setData] = useState<WidgetData>({
        totalPendingReviews: 0,
        totalCompletedToday: 0,
        subjects: []
    });
    const [todoPreview, setTodoPreview] = useState<TodoPreviewData>(createEmptyTodoPreview());
    const [todoPendingOps, setTodoPendingOps] = useState<Record<number, boolean>>({});
    const [isReminderCollapsing, setIsReminderCollapsing] = useState(false);
    const [isModeSwitchAnimating, setIsModeSwitchAnimating] = useState(false);
    const [isForceCompactTransitioning, setIsForceCompactTransitioning] = useState(false);
    const [activityOpenAnimToken, setActivityOpenAnimToken] = useState(0);
    // Handle music IPC events
    useEffect(() => {
        let ipcRenderer: any = null;
        try {
            ipcRenderer = (window as any).require('electron').ipcRenderer;

            const handleMusicUpdate = (_event: any, data: MusicData) => {
                musicDebugLog('[DynamicIsland] 🎵 Received music data:', data);
                musicDebugLog('[DynamicIsland] 📊 Data breakdown:', {
                    title: data.title,
                    position: data.position,
                    duration: data.duration,
                    status: data.status,
                    isPlaying: data.isPlaying
                });

                // Clear timeout for switching back to app mode
                if (musicTimeoutRef.current) {
                    clearTimeout(musicTimeoutRef.current);
                    musicTimeoutRef.current = null;
                }

                if (data && (data.status === 'Playing' || data.status === 'Paused')) {
                    // 只有登录状态才允许首次接管音乐（从 app 模式切换到 music 模式）
                    // 如果已经在 music 模式，则始终允许数据更新（保持歌曲切换、播放状态、进度同步）
                    if (!isLoggedInRef.current && modeRef.current !== 'music') {
                        musicDebugLog('[DynamicIsland] 🔒 Music detected but user not logged in, ignoring.');
                        return;
                    }

                    setMusicData(data);
                    // Position sync is handled by the dedicated sync useEffect
                    // Do NOT set localPosition here — for apps like NetEase Cloud Music
                    // where data.position is always 0, this would reset the local timer every 500ms
                    if (modeRef.current !== 'music') {
                        forceCompactModeRef.current = false;
                        setForceCompactMode(false);
                        setIsForceCompactTransitioning(false);
                        if (forceCompactTransitionTimerRef.current) {
                            clearTimeout(forceCompactTransitionTimerRef.current);
                            forceCompactTransitionTimerRef.current = null;
                        }
                    }
                    setMode('music');

                    // If paused, set a timeout to switch back to app mode after 30 seconds
                    if (data.status === 'Paused') {
                        musicTimeoutRef.current = setTimeout(() => {
                            setMode('app');
                            setMusicData(null);
                        }, 30000);
                    }
                } else if (data && data.status === 'Stopped') {
                    // Music stopped, switch back to app mode
                    setMode('app');
                    setMusicData(null);
                }
            };

            ipcRenderer.on('music-data-update', handleMusicUpdate);

            return () => {
                ipcRenderer.removeListener('music-data-update', handleMusicUpdate);
                if (musicTimeoutRef.current) {
                    clearTimeout(musicTimeoutRef.current);
                }
            };
        } catch (e) {
            console.warn('Electron IPC not available for music');
        }
    }, []);

    useEffect(() => {
        let ipcRenderer: any = null;
        try {
            ipcRenderer = (window as any).require('electron').ipcRenderer;
            const handleDisplayModeChange = (_event: any, nextMode: 'review' | 'todo') => {
                setAppDisplayMode(nextMode === 'todo' ? 'todo' : 'review');
                setIsExpanded(false);
                // 复习/待办模式切换统一规则：
                // 切换后默认回到活动态，不记忆该模式之前的“普通态/活动态”开关状态
                // （长按切换序列中由专用动画控制，避免被这里打断）
                if (!isModeSwitchAnimatingRef.current) {
                    forceCompactModeRef.current = false;
                    setForceCompactMode(false);
                }
            };
            ipcRenderer.on('widget-display-mode-changed', handleDisplayModeChange);
            ipcRenderer.send('get-widget-display-mode');
            return () => {
                ipcRenderer.removeListener('widget-display-mode-changed', handleDisplayModeChange);
            };
        } catch (e) {
            return;
        }
    }, []);

    // Local position update for smooth progress bar
    // For apps that provide timeline (Apple Music): use server position + local increment
    // For apps that DON'T provide timeline (NetEase Cloud Music): simulate based on play start time
    useEffect(() => {
        if (!musicData?.isPlaying) {
            // Not playing, pause the timer
            playStartTimeRef.current = null;
            return;
        }

        const interval = setInterval(() => {
            setLocalPosition(prev => {
                // If server is providing valid position updates (position > 0 or continuously changing)
                // we rely on the sync effect. Here we just do local increment.
                const newPos = prev + 1;
                return newPos <= (musicData?.duration || 0) ? newPos : prev;
            });
        }, 1000);

        return () => clearInterval(interval);
    }, [musicData?.isPlaying, musicData?.duration]);

    // Sync local position when server data updates
    // Uses lastServerPosRef to detect real server position changes vs repeated polls
    const lastTitleRef = useRef<string>('');
    const initialSyncDoneRef = useRef<boolean>(false);
    const lastServerPosRef = useRef<number>(0); // Track last server position to detect real changes

    useEffect(() => {
        if (musicData) {
            const serverPos = musicData.position;
            const titleChanged = musicData.title !== lastTitleRef.current;

            // 歌曲切换 → 直接同步 (处理网易云进度记忆：切歌回来从上次位置继续)
            if (titleChanged) {
                musicDebugLog('[DynamicIsland] 🎼 Title changed, syncing position to:', serverPos);
                setLocalPosition(serverPos);
                lastTitleRef.current = musicData.title;
                initialSyncDoneRef.current = true;
                lastServerPosRef.current = serverPos;

                // Initialize play start time if playing
                if (musicData.isPlaying) {
                    playStartTimeRef.current = Date.now();
                    playStartPositionRef.current = serverPos;
                }
                return;
            }

            // 首次加载 → 直接同步
            if (!initialSyncDoneRef.current) {
                musicDebugLog('[DynamicIsland] 🆕 Initial sync, setting position to:', serverPos);
                setLocalPosition(serverPos);
                initialSyncDoneRef.current = true;
                lastServerPosRef.current = serverPos;

                if (musicData.isPlaying) {
                    playStartTimeRef.current = Date.now();
                    playStartPositionRef.current = serverPos;
                }
                return;
            }

            // 检测服务端位置是否真的发生了变化 (用于区分拖动/推进 vs 重复轮询)
            const serverPosChanged = Math.abs(serverPos - lastServerPosRef.current) > 0.5;
            lastServerPosRef.current = serverPos;

            if (serverPosChanged) {
                // 服务端位置变了 → 检查与本地差距，如果大于2秒则同步
                // 这处理了：拖动进度条、正常播放推进、进度记忆恢复
                const drift = Math.abs(serverPos - localPosition);
                if (drift > 2) {
                    musicDebugLog('[DynamicIsland] ⏩ Server position changed, syncing:', serverPos, '(drift:', drift, ')');
                    setLocalPosition(serverPos);
                    playStartTimeRef.current = Date.now();
                    playStartPositionRef.current = serverPos;
                }
            } else if (!musicData.isPlaying) {
                // 暂停状态 + 服务端位置未变 → 但如果跟本地差太多也同步 (处理暂停后拖动)
                const drift = Math.abs(serverPos - localPosition);
                if (drift > 1) {
                    musicDebugLog('[DynamicIsland] ⏸️ Paused drift detected, syncing:', serverPos);
                    setLocalPosition(serverPos);
                }
            }
            // 播放中 + 服务端位置未变 → 靠本地定时器每秒 +1 递增，保持平滑
        }
    }, [musicData?.position, musicData?.title, musicData?.isPlaying]);

    // Media control handlers
    const sendMediaControl = useCallback((command: string) => {
        try {
            const { ipcRenderer } = (window as any).require('electron');
            ipcRenderer.send('media-control', command);
        } catch (e) {
            console.error('Cannot send media control', e);
        }
    }, []);

    const handlePlayPause = useCallback((e: React.MouseEvent) => {
        e.stopPropagation();
        sendMediaControl('play-pause');
    }, [sendMediaControl]);

    const handlePrev = useCallback((e: React.MouseEvent) => {
        e.stopPropagation();
        sendMediaControl('prev');
    }, [sendMediaControl]);

    const handleNext = useCallback((e: React.MouseEvent) => {
        e.stopPropagation();
        sendMediaControl('next');
    }, [sendMediaControl]);

    const applyTodoTaskStatus = useCallback((preview: TodoPreviewData, taskId: number, completed: boolean): TodoPreviewData => {
        const target = preview.tasks.find(t => t.id === taskId);
        if (!target) return preview;

        const prevCompleted = target.status === 'completed';
        if (prevCompleted === completed) return preview;

        const nextTasks = preview.tasks.map(task =>
            task.id === taskId ? { ...task, status: completed ? 'completed' : 'todo' } : task
        );

        const pendingDelta = completed ? -1 : 1;
        const dueTodayDelta = target.dueToday ? pendingDelta : 0;
        const overdueDelta = target.overdue ? pendingDelta : 0;

        return {
            ...preview,
            pending: Math.max(0, preview.pending + pendingDelta),
            dueToday: Math.max(0, preview.dueToday + dueTodayDelta),
            overdue: Math.max(0, preview.overdue + overdueDelta),
            tasks: nextTasks
        };
    }, []);

    const handleToggleTodoTask = useCallback(async (e: React.MouseEvent, taskId: number) => {
        e.stopPropagation();
        if (todoPendingOps[taskId]) return;

        const targetTask = todoPreview.tasks.find(task => task.id === taskId);
        if (!targetTask) return;
        const willComplete = targetTask.status !== 'completed';

        setTodoPendingOps(prev => ({ ...prev, [taskId]: true }));
        setTodoPreview(prev => applyTodoTaskStatus(prev, taskId, willComplete));

        try {
            await request({
                url: `/todos/tasks/${taskId}/status`,
                method: 'patch',
                data: { completed: willComplete }
            });
        } catch (error) {
            console.error('Toggle todo status failed', error);
            setTodoPreview(prev => applyTodoTaskStatus(prev, taskId, !willComplete));
        } finally {
            setTodoPendingOps(prev => {
                const next = { ...prev };
                delete next[taskId];
                return next;
            });
        }
    }, [todoPendingOps, todoPreview.tasks, applyTodoTaskStatus]);

    // Handle gestures
    const GESTURE_SWITCH_THRESHOLD = 26;
    const TAP_THRESHOLD = 10;
    const MODE_SWITCH_LONG_PRESS_MS = 420;
    const MODE_SWITCH_COMPACT_PHASE_MS = 320;
    const MODE_SWITCH_REOPEN_DELAY_MS = 70;
    const TRACKPAD_VERTICAL_THRESHOLD = 70;
    const TRACKPAD_HORIZONTAL_THRESHOLD = 70;
    const TRACKPAD_GESTURE_RESET_MS = 160;
    const TRACKPAD_GESTURE_COOLDOWN_MS = 320;

    const clearModeSwitchLongPressTimer = useCallback(() => {
        if (modeSwitchLongPressTimerRef.current) {
            clearTimeout(modeSwitchLongPressTimerRef.current);
            modeSwitchLongPressTimerRef.current = null;
        }
    }, []);

    const clearModeSwitchSequenceTimers = useCallback(() => {
        if (modeSwitchCompactTimerRef.current) {
            clearTimeout(modeSwitchCompactTimerRef.current);
            modeSwitchCompactTimerRef.current = null;
        }
        if (modeSwitchExpandTimerRef.current) {
            clearTimeout(modeSwitchExpandTimerRef.current);
            modeSwitchExpandTimerRef.current = null;
        }
        if (modeSwitchUnlockTimerRef.current) {
            clearTimeout(modeSwitchUnlockTimerRef.current);
            modeSwitchUnlockTimerRef.current = null;
        }
    }, []);

    const clearForceCompactTransitionTimer = useCallback(() => {
        if (forceCompactTransitionTimerRef.current) {
            clearTimeout(forceCompactTransitionTimerRef.current);
            forceCompactTransitionTimerRef.current = null;
        }
    }, []);

    const clearTrackpadGestureState = useCallback(() => {
        trackpadDeltaXRef.current = 0;
        trackpadDeltaYRef.current = 0;
        if (trackpadGestureResetTimerRef.current) {
            clearTimeout(trackpadGestureResetTimerRef.current);
            trackpadGestureResetTimerRef.current = null;
        }
    }, []);

    const lockTrackpadGesture = useCallback(() => {
        trackpadGestureLockedRef.current = true;
        if (trackpadGestureCooldownTimerRef.current) {
            clearTimeout(trackpadGestureCooldownTimerRef.current);
        }
        trackpadGestureCooldownTimerRef.current = setTimeout(() => {
            trackpadGestureLockedRef.current = false;
            trackpadGestureCooldownTimerRef.current = null;
        }, TRACKPAD_GESTURE_COOLDOWN_MS);
    }, []);

    const setForceCompactModeWithTransition = useCallback((nextCompact: boolean) => {
        if (forceCompactModeRef.current === nextCompact) return;
        if (!nextCompact) {
            // 普通态 -> 活动态时，触发一次内容淡入动画（避免“先出内容再停顿”）
            setActivityOpenAnimToken(prev => prev + 1);
        }
        setIsForceCompactTransitioning(true);
        forceCompactModeRef.current = nextCompact;
        setForceCompactMode(nextCompact);
        clearForceCompactTransitionTimer();
        const transitionDurationMs = (nextCompact ? ACTIVITY_COLLAPSE_DURATION_SECONDS : ACTIVITY_OPEN_DURATION_SECONDS) * 1000;
        const openSettleBufferMs = nextCompact ? 0 : 80; // 给开启动画一个收尾缓冲，避免末尾切状态产生“第二段”错觉
        forceCompactTransitionTimerRef.current = setTimeout(() => {
            setIsForceCompactTransitioning(false);
            forceCompactTransitionTimerRef.current = null;
        }, transitionDurationMs + openSettleBufferMs);
    }, [clearForceCompactTransitionTimer]);

    const syncDisplayModeToMain = useCallback((nextMode: 'review' | 'todo') => {
        try {
            const { ipcRenderer } = (window as any).require('electron');
            ipcRenderer.send('set-widget-display-mode', nextMode);
        } catch (e) {
            // Electron IPC unavailable时退化为本地状态切换
            setAppDisplayMode(nextMode);
        }
    }, []);

    const triggerActivityModeSwitch = () => {
        if (mode !== 'app') return;
        if (!showAppActivity) return;
        if (isExpandedRef.current) return;
        if (isModeSwitchAnimating) return;

        const nextMode: 'review' | 'todo' = appDisplayMode === 'review' ? 'todo' : 'review';
        isModeSwitchAnimatingRef.current = true;
        setIsModeSwitchAnimating(true);
        setForceCompactModeWithTransition(true);
        clearModeSwitchSequenceTimers();

        // 先收起活动态，再切换模式并展开回活动态
        modeSwitchCompactTimerRef.current = setTimeout(() => {
            setAppDisplayMode(nextMode);
            syncDisplayModeToMain(nextMode);

            modeSwitchExpandTimerRef.current = setTimeout(() => {
                setForceCompactModeWithTransition(false);
            }, MODE_SWITCH_REOPEN_DELAY_MS);
        }, MODE_SWITCH_COMPACT_PHASE_MS);

        const unlockDelay = MODE_SWITCH_COMPACT_PHASE_MS + MODE_SWITCH_REOPEN_DELAY_MS + Math.round(ACTIVITY_COLLAPSE_DURATION_SECONDS * 1000);
        modeSwitchUnlockTimerRef.current = setTimeout(() => {
            isModeSwitchAnimatingRef.current = false;
            setIsModeSwitchAnimating(false);
        }, unlockDelay);
    };

    const handleActivityLeftIconPointerDown = (e: React.PointerEvent<HTMLButtonElement>) => {
        e.stopPropagation();
        if (e.button !== 0) return;
        if (!showAppActivity || isExpanded || isModeSwitchAnimating) return;

        clearModeSwitchLongPressTimer();
        modeSwitchLongPressTimerRef.current = setTimeout(() => {
            modeSwitchLongPressTimerRef.current = null;
            triggerActivityModeSwitch();
        }, MODE_SWITCH_LONG_PRESS_MS);
    };

    const handleActivityLeftIconPointerEnd = (e: React.PointerEvent<HTMLButtonElement>) => {
        e.stopPropagation();
        clearModeSwitchLongPressTimer();
    };

    const finalizeGesture = (currentTarget: EventTarget | null) => {
        startX.current = null;
        lastPointerXRef.current = null;
        activePointerIdRef.current = null;
        isGestureTrackingRef.current = false;

        const targetEl = currentTarget as HTMLElement | null;
        const isHovering = !!targetEl && typeof targetEl.matches === 'function' && targetEl.matches(':hover');
        if (!isExpandedRef.current && !isHovering) {
            enableClickThrough();
        }
    };

    const handlePointerDown = (e: React.PointerEvent) => {
        // Prevent interaction if clicking on a button
        if ((e.target as HTMLElement).closest('button')) return;
        activePointerIdRef.current = e.pointerId;
        startX.current = e.clientX;
        lastPointerXRef.current = e.clientX;
        isGestureTrackingRef.current = true;
        try {
            e.currentTarget.setPointerCapture(e.pointerId);
        } catch (error) {
            // Ignore pointer capture failures
        }
    };

    const handlePointerMove = (e: React.PointerEvent) => {
        if (!isGestureTrackingRef.current) return;
        if (activePointerIdRef.current !== null && e.pointerId !== activePointerIdRef.current) return;
        if (startX.current === null) return;
        lastPointerXRef.current = e.clientX;
    };

    const handlePointerUp = (e: React.PointerEvent) => {
        if (!isGestureTrackingRef.current) return;
        if (activePointerIdRef.current !== null && e.pointerId !== activePointerIdRef.current) return;
        if (startX.current === null) {
            finalizeGesture(e.currentTarget);
            return;
        }

        const currentX = lastPointerXRef.current ?? e.clientX;
        const diff = currentX - startX.current;
        try {
            e.currentTarget.releasePointerCapture(e.pointerId);
        } catch (error) {
            // Ignore pointer capture release failures
        }
        finalizeGesture(e.currentTarget);

        // 活动态通用手势：
        // 右滑 -> 收起到普通态；左滑 -> 从普通态展开回活动态
        const canToggleActivityByGesture = hasAnyActivitySource;
        if (canToggleActivityByGesture) {
            if (diff > GESTURE_SWITCH_THRESHOLD && showAnyActivity) {
                setForceCompactModeWithTransition(true);
                return;
            }
            if (diff < -GESTURE_SWITCH_THRESHOLD && forceCompactMode) {
                setForceCompactModeWithTransition(false);
                return;
            }
        }

        if (Math.abs(diff) < TAP_THRESHOLD) {
            toggleExpand();
        }
    };

    const handlePointerCancel = (e: React.PointerEvent) => {
        if (!isGestureTrackingRef.current) return;
        try {
            e.currentTarget.releasePointerCapture(e.pointerId);
        } catch (error) {
            // Ignore pointer capture release failures
        }
        finalizeGesture(e.currentTarget);
    };

    // Helper to open login
    const openLogin = () => {
        try {
            const { shell } = (window as any).require('electron');
            const envUrl = (window as any)?.process?.env?.ELECTRON_START_URL;
            const defaultWebUrl = 'https://memoryflow.tanxhub.com';
            const baseUrl = (envUrl && typeof envUrl === 'string') ? envUrl : defaultWebUrl;
            const normalizedBaseUrl = baseUrl.split('#')[0].replace(/\/$/, '');
            shell.openExternal(`${normalizedBaseUrl}/#/login?callback=desktop`);
        } catch (e) {
            console.error('Cannot open external link', e);
        }
    };

    const getTimeGreeting = () => {
        const hour = new Date().getHours();
        const pick = (items: string[]) => items[Math.floor(Math.random() * items.length)];

        if (hour >= 5 && hour <= 8) return pick(["晨光微露", "破晓啦", "早安", "新的一天"]);
        if (hour >= 9 && hour <= 11) return pick(["上午好", "阳光正好", "专注时刻", "展信佳"]);
        if (hour >= 12 && hour <= 13) return pick(["午安", "小憩时间", "正午好"]);
        if (hour >= 14 && hour <= 17) return pick(["下午好", "微风不燥", "日渐西斜"]);
        if (hour >= 18 && hour <= 19) return pick(["傍晚好", "暮色降临", "黄昏好"]);
        if (hour >= 20 && hour <= 23) return pick(["晚上好", "夜幕低垂", "星光亮起"]);
        return pick(["夜深了", "万籁俱寂", "还在熬夜吗"]);
    };

    const startGreeting = useCallback((name: string) => {
        if (!name) return;
        if (greetingTimeoutRef.current) {
            clearTimeout(greetingTimeoutRef.current);
            greetingTimeoutRef.current = null;
        }

        setGreetingText(`${getTimeGreeting()}，${name}`);
        setIsGreetingActive(true);
        greetingTimeoutRef.current = setTimeout(() => {
            setIsGreetingActive(false);
        }, 10000);
    }, []);

    // Toggle expansion
    const toggleExpand = () => {
        if (!isLoggedIn && mode === 'app') {
            openLogin();
            return;
        }
        setIsExpanded(!isExpanded);
    };

    // Initial data fetch and Token listener
    useEffect(() => {
        try {
            const { ipcRenderer } = (window as any).require('electron');
            ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
        } catch (e) { }

        const handleAuthLogout = () => {
            localStorage.removeItem('token');
            localStorage.removeItem('refreshToken');
            localStorage.removeItem('tokenExpiresAt');
            clearModeSwitchLongPressTimer();
            clearModeSwitchSequenceTimers();
            clearForceCompactTransitionTimer();
            forceCompactModeRef.current = false;
            isModeSwitchAnimatingRef.current = false;
            setIsModeSwitchAnimating(false);
            setIsForceCompactTransitioning(false);
            setForceCompactMode(false);
            setIsLoggedIn(false);
            setIsExpanded(false);
            setMode('app');
            setTodoPreview(createEmptyTodoPreview());
            setTodoPendingOps({});
        };
        window.addEventListener('auth:logout', handleAuthLogout);

        const fetchData = async () => {
            try {
                const [summaryRes, todoStatsRes, todoTasksRes] = await Promise.all([
                    request({
                        url: '/widget/summary',
                        method: 'get'
                    }),
                    request({
                        url: '/todos/stats',
                        method: 'get'
                    }),
                    request({
                        url: '/todos/tasks',
                        method: 'get',
                        params: {
                            status: 'todo',
                            sortBy: 'due',
                            sortOrder: 'asc'
                        }
                    })
                ]);

                if (summaryRes?.code === 200) {
                    setData(summaryRes.data);
                } else if (summaryRes?.code === 401 || summaryRes?.code === 403) {
                    localStorage.removeItem('token');
                    localStorage.removeItem('refreshToken');
                    localStorage.removeItem('tokenExpiresAt');
                    setIsLoggedIn(false);
                }

                if (todoStatsRes?.code === 200 || todoTasksRes?.code === 200) {
                    const stats = todoStatsRes?.data || {};
                    const todoTasks = Array.isArray(todoTasksRes?.data) ? todoTasksRes.data : [];
                    setTodoPreview({
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
                            dueToday: !!task.dueToday
                        }))
                    });
                } else if (todoStatsRes?.code === 401 || todoTasksRes?.code === 401 || todoStatsRes?.code === 403 || todoTasksRes?.code === 403) {
                    if (!summaryRes || (summaryRes.code !== 401 && summaryRes.code !== 403)) {
                        localStorage.removeItem('token');
                        localStorage.removeItem('refreshToken');
                        localStorage.removeItem('tokenExpiresAt');
                        setIsLoggedIn(false);
                    }
                }
            } catch (error: any) {
                console.error("Widget fetch error", error);
            }
        };

        const fetchUserName = async () => {
            try {
                const res: any = await request({
                    url: '/auth/me',
                    method: 'get'
                });
                if (res && res.code === 200 && res.data) {
                    const name = String(res.data.nickname || res.data.email || '').trim();
                    if (name) startGreeting(name);
                }
            } catch (error: any) {
                console.error("User fetch error", error);
            }
        };

        const token = localStorage.getItem('token');
        const refreshToken = localStorage.getItem('refreshToken');
        if (token || refreshToken) {
            setIsLoggedIn(true);
            fetchData();
            fetchUserName();
        }

        let ipcRenderer: any = null;
        try {
            ipcRenderer = (window as any).require('electron').ipcRenderer;
            ipcRenderer.on('auth-token', (_event: any, auth: any) => {
                console.log('Received token via IPC');
                if (typeof auth === 'string') {
                    localStorage.setItem('token', auth);
                } else if (auth && typeof auth === 'object') {
                    if (auth.accessToken) {
                        localStorage.setItem('token', String(auth.accessToken));
                    }
                    if (auth.refreshToken) {
                        localStorage.setItem('refreshToken', String(auth.refreshToken));
                    }
                    if (typeof auth.expiresIn === 'number' && Number.isFinite(auth.expiresIn) && auth.expiresIn > 0) {
                        localStorage.setItem('tokenExpiresAt', String(Date.now() + auth.expiresIn * 1000));
                    }
                }
                if (modeRef.current === 'app') {
                    forceCompactModeRef.current = true;
                    setIsForceCompactTransitioning(false);
                    setForceCompactMode(true);
                }
                setIsLoggedIn(true);
                fetchData();
                fetchUserName();
            });
            ipcRenderer.on('auth-logout', () => {
                localStorage.removeItem('token');
                localStorage.removeItem('refreshToken');
                localStorage.removeItem('tokenExpiresAt');
                clearModeSwitchLongPressTimer();
                clearModeSwitchSequenceTimers();
                clearForceCompactTransitionTimer();
                forceCompactModeRef.current = false;
                isModeSwitchAnimatingRef.current = false;
                setIsModeSwitchAnimating(false);
                setIsForceCompactTransitioning(false);
                setForceCompactMode(false);
                setIsLoggedIn(false);
                setIsExpanded(false);
                setMode('app');
                setTodoPreview(createEmptyTodoPreview());
                setTodoPendingOps({});
            });
        } catch (e) {
            console.warn('Electron IPC not available');
        }

        const timer = setInterval(() => {
            if (localStorage.getItem('token')) fetchData();
        }, 60000);

        return () => {
            clearInterval(timer);
            window.removeEventListener('auth:logout', handleAuthLogout);
            if (greetingTimeoutRef.current) {
                clearTimeout(greetingTimeoutRef.current);
                greetingTimeoutRef.current = null;
            }
            if (ipcRenderer) {
                ipcRenderer.removeAllListeners('auth-token');
                ipcRenderer.removeAllListeners('auth-logout');
            }
        };
    }, [clearModeSwitchLongPressTimer, clearModeSwitchSequenceTimers, clearForceCompactTransitionTimer]);

    useEffect(() => {
        if (mode === 'music' && isGreetingActive) {
            if (greetingTimeoutRef.current) {
                clearTimeout(greetingTimeoutRef.current);
                greetingTimeoutRef.current = null;
            }
            setIsGreetingActive(false);
        }
    }, [mode, isGreetingActive]);

    useEffect(() => {
        let ipcRenderer: any = null;
        try {
            ipcRenderer = (window as any).require('electron').ipcRenderer;
            const handleCollapse = () => {
                if (isExpandedRef.current) {
                    collapseExpanded();
                }
            };
            ipcRenderer.on('widget-collapse', handleCollapse);
            return () => {
                ipcRenderer.removeListener('widget-collapse', handleCollapse);
            };
        } catch (e) {
            return;
        }
    }, [collapseExpanded]);

    useEffect(() => {
        const handlePointerDownCapture = (event: PointerEvent) => {
            if (!isExpandedRef.current) return;
            const targetNode = event.target as Node | null;
            if (!targetNode) return;
            const hitEl = islandHitRef.current;
            if (hitEl && hitEl.contains(targetNode)) return;
            collapseExpanded();
        };

        document.addEventListener('pointerdown', handlePointerDownCapture, true);
        return () => {
            document.removeEventListener('pointerdown', handlePointerDownCapture, true);
        };
    }, [collapseExpanded]);

    // Time check for reminder:
    // 1. 保留每日提醒时间概念
    // 2. 到点时如果用户还停留在普通态，则自动展开一次活动态
    // 3. App 模式的手动活动态开关不再受时间限制
    useEffect(() => {
        const checkTime = () => {
            if (!data.reminderTime) {
                reminderDueRef.current = false;
                setIsReminderActive(false);
                return;
            }

            const [hours, minutes] = data.reminderTime.split(':').map(Number);
            if (!Number.isFinite(hours) || !Number.isFinite(minutes)) {
                reminderDueRef.current = false;
                setIsReminderActive(false);
                return;
            }

            const now = new Date();
            const reminderDate = new Date(now);
            reminderDate.setHours(hours, minutes, 0, 0);

            const isDueToday = now >= reminderDate;
            const reminderKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}-${data.reminderTime}`;
            const hasInitializedReminderCheck = reminderCheckInitializedRef.current;
            const justReachedReminderTime = hasInitializedReminderCheck && isDueToday && !reminderDueRef.current;

            setIsReminderActive(isDueToday);

            if (
                justReachedReminderTime
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
    }, [data.reminderTime, setForceCompactModeWithTransition]);

    // Dynamic dimensions
    const expandedWidth = 460;
    const expandedMusicHeight = 210;
    const expandedAppHeight = 320; // Fixed height for App mode (review/todo)
    const hasPendingTodos = todoPreview.pending > 0;
    // 活动态来源（不受 forceCompactMode 影响）：用于统一手势开关判定
    const hasMusicActivitySource = mode === 'music' && !!musicData;
    const hasAppActivitySource = mode === 'app' && isLoggedIn;
    const hasAnyActivitySource = hasMusicActivitySource || hasAppActivitySource;
    // 当前是否展示活动态（受 forceCompactMode 影响）
    const showMusicActivity = hasMusicActivitySource && !forceCompactMode;
    const showReminder = appDisplayMode === 'review' && hasAppActivitySource && !forceCompactMode;
    const showTodoActivity = appDisplayMode === 'todo' && hasAppActivitySource && !forceCompactMode;
    const showAppActivity = showReminder || showTodoActivity;
    const showAnyActivity = showMusicActivity || showAppActivity;
    const isActivityVisualState = showAnyActivity;
    // 活动态可独立控制底部圆角与连续曲率
    const collapsedCornerRadius = isActivityVisualState ? COLLAPSED_RADIUS_ACTIVITY : COLLAPSED_RADIUS_DEFAULT;
    const collapsedCornerSmoothness = isActivityVisualState ? SQUIRCLE_SMOOTHNESS_ACTIVITY : SQUIRCLE_SMOOTHNESS;

    // Determine collapsed width based on mode
    const getCollapsedWidth = () => {
        // 活动态统一宽度入口：音乐/复习/待办/未来活动态都复用同一宽度
        if (showAnyActivity) {
            return ACTIVITY_COLLAPSED_WIDTH;
        }
        if (mode === 'app' && isGreetingActive && isLoggedIn && greetingText) {
            const estimated = Math.ceil(greetingText.length * 14 + 40);
            return Math.max(220, Math.min(300, estimated));
        }
        // 待办在“无活动源”时保留原普通态宽度；
        // 若存在活动源但被手势收起(forceCompactMode)，则与复习普通态完全一致（避免视觉像又回到活动态）
        if (mode === 'app' && isLoggedIn && appDisplayMode === 'todo' && !hasAppActivitySource) {
            return 230;
        }
        return isLoggedIn ? 160 : 180;
    };
    const collapsedWidth = getCollapsedWidth();

    // Get theme color for music
    const themeColor = musicData?.themeColor || '#22d3ee';

    const shouldShowShadow = isExpanded || isHovered;

    const handleTrackpadWheel = useCallback((e: React.WheelEvent<HTMLDivElement>) => {
        if (!isHovered && !isExpandedRef.current) return;
        if (trackpadGestureLockedRef.current) return;

        trackpadDeltaXRef.current += e.deltaX;
        trackpadDeltaYRef.current += e.deltaY;

        if (trackpadGestureResetTimerRef.current) {
            clearTimeout(trackpadGestureResetTimerRef.current);
        }
        trackpadGestureResetTimerRef.current = setTimeout(() => {
            clearTrackpadGestureState();
        }, TRACKPAD_GESTURE_RESET_MS);

        const absX = Math.abs(trackpadDeltaXRef.current);
        const absY = Math.abs(trackpadDeltaYRef.current);

        if (absX >= absY && absX >= TRACKPAD_HORIZONTAL_THRESHOLD) {
            if (modeRef.current === 'music' && musicData) {
                e.preventDefault();
                sendMediaControl(trackpadDeltaXRef.current > 0 ? 'next' : 'prev');
                clearTrackpadGestureState();
                lockTrackpadGesture();
            }
            return;
        }

        if (absY > absX && absY >= TRACKPAD_VERTICAL_THRESHOLD) {
            // Windows precision touchpad on this widget reports vertical wheel delta
            // opposite to the intended UX mapping here, so we align with observed behavior:
            // two-finger swipe up => close/collapse, two-finger swipe down => open/expand.
            const swipingUp = trackpadDeltaYRef.current > 0;
            const swipingDown = trackpadDeltaYRef.current < 0;

                if (swipingUp) {
                    if (isExpandedRef.current) {
                        e.preventDefault();
                        collapseExpanded({ preserveHoverFocus: true });
                        clearTrackpadGestureState();
                        lockTrackpadGesture();
                        return;
                    }
                if (hasAnyActivitySource && !forceCompactModeRef.current) {
                    e.preventDefault();
                    setForceCompactModeWithTransition(true);
                    clearTrackpadGestureState();
                    lockTrackpadGesture();
                    return;
                }
            }

            if (swipingDown) {
                if (!isExpandedRef.current && hasAnyActivitySource && forceCompactModeRef.current) {
                    e.preventDefault();
                    setForceCompactModeWithTransition(false);
                    clearTrackpadGestureState();
                    lockTrackpadGesture();
                    return;
                }
                if (!isExpandedRef.current && showAnyActivity) {
                    e.preventDefault();
                    toggleExpand();
                    clearTrackpadGestureState();
                    lockTrackpadGesture();
                }
            }
        }
    }, [
        isHovered,
        musicData,
        sendMediaControl,
        clearTrackpadGestureState,
        lockTrackpadGesture,
        collapseExpanded,
        hasAnyActivitySource,
        showAnyActivity,
        setForceCompactModeWithTransition
    ]);

    // Base width for animation (standard collapsed state)
    const baseWidth = isLoggedIn ? 160 : 180;
    const justCollapsedFromExpanded = !isExpanded && prevIsExpandedRef.current && showAnyActivity;
    const isReminderCollapseTransition = isReminderCollapsing || justCollapsedFromExpanded;
    const isActivityCloseTransition = isForceCompactTransitioning && forceCompactMode && hasAnyActivitySource;
    const isActivityOpenTransition = isForceCompactTransitioning && !forceCompactMode && hasAnyActivitySource;
    // 分段收起动画只在“真正的收起过程”触发，稳定活动态不再重复执行
    const isActivitySegmentedTransition = isReminderCollapseTransition || isActivityCloseTransition;
    const collapseMidWidth = isActivitySegmentedTransition ? 155 : baseWidth;
    const segmentedDuration = isActivitySegmentedTransition ? ACTIVITY_COLLAPSE_DURATION_SECONDS : 0.56;
    const segmentedTimes = isActivitySegmentedTransition ? ACTIVITY_SEGMENTED_TIMES : [0, 0.2, 0.34, 1];
    const segmentedWidthKeyframes = [null, collapseMidWidth, collapseMidWidth, collapsedWidth];
    const segmentedHeightKeyframes = [null, 36, 36, 36];
    const leftCapCollapsedPath = [
        null,
        generateLeftCapPath(36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateLeftCapPath(36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateLeftCapPath(36, collapsedCornerRadius, collapsedCornerSmoothness)
    ];
    const rightCapCollapsedPath = [
        null,
        generateRightCapPath(36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateRightCapPath(36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateRightCapPath(36, collapsedCornerRadius, collapsedCornerSmoothness)
    ];
    const squircleCollapsedPath = [
        null,
        generateSquirclePath(collapseMidWidth, 36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateSquirclePath(collapseMidWidth, 36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateSquirclePath(collapsedWidth, 36, collapsedCornerRadius, collapsedCornerSmoothness)
    ];
    const openSquircleCollapsedPath = [
        null,
        generateOpenSquirclePath(collapseMidWidth, 36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateOpenSquirclePath(collapseMidWidth, 36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateOpenSquirclePath(collapsedWidth, 36, collapsedCornerRadius, collapsedCornerSmoothness)
    ];
    const collapsedContentDelay = (!isExpanded && isActivitySegmentedTransition)
        ? ACTIVITY_COLLAPSE_CONTENT_DELAY_SECONDS
        : 0;
    const expandedContentFadeDuration = isExpanded ? 0.3 : 0.15;

    useEffect(() => {
        const startedFromExpanded = prevIsExpandedRef.current && !isExpanded && showAnyActivity;

        if (startedFromExpanded) {
            setIsReminderCollapsing(true);
            if (reminderCollapseTimerRef.current) {
                clearTimeout(reminderCollapseTimerRef.current);
            }
            reminderCollapseTimerRef.current = setTimeout(() => {
                setIsReminderCollapsing(false);
                reminderCollapseTimerRef.current = null;
            }, ACTIVITY_COLLAPSE_DURATION_SECONDS * 1000);
        } else if (isExpanded || !showAnyActivity) {
            if (reminderCollapseTimerRef.current) {
                clearTimeout(reminderCollapseTimerRef.current);
                reminderCollapseTimerRef.current = null;
            }
            setIsReminderCollapsing(false);
        }

        prevIsExpandedRef.current = isExpanded;
    }, [isExpanded, showAnyActivity]);

    useEffect(() => {
        return () => {
            if (reminderCollapseTimerRef.current) {
                clearTimeout(reminderCollapseTimerRef.current);
                reminderCollapseTimerRef.current = null;
            }
            clearModeSwitchLongPressTimer();
            clearModeSwitchSequenceTimers();
            clearForceCompactTransitionTimer();
            clearTrackpadGestureState();
            if (trackpadGestureCooldownTimerRef.current) {
                clearTimeout(trackpadGestureCooldownTimerRef.current);
                trackpadGestureCooldownTimerRef.current = null;
            }
            trackpadGestureLockedRef.current = false;
        };
    }, [clearModeSwitchLongPressTimer, clearModeSwitchSequenceTimers, clearForceCompactTransitionTimer, clearTrackpadGestureState]);

    // 固定窗口大小以避免动画时的闪烁问题 (Canvas Strategy)
    // 窗口始终保持最大尺寸，通过忽略鼠标事件(setIgnoreMouseEvents)来实现点击穿透
    const WINDOW_WIDTH = 620;
    const SHADOW_BUFFER = 120; // Buffer for shadow (避免 drop-shadow 在窗口底部被裁切出现“硬边”)

    useEffect(() => {
        try {
            const { ipcRenderer } = (window as any).require('electron');
            // 仅在组件挂载时发送一次调整指令，确保窗口居中且尺寸正确
            ipcRenderer.send('resize-widget', {
                width: WINDOW_WIDTH,
                height: 300 // Initial height
            });
        } catch (e) {
            // Electron IPC not available
        }
    }, []);

    // Sync Electron window height with content height
    useEffect(() => {
        try {
            const { ipcRenderer } = (window as any).require('electron');

            // Calculate the visual height of the island
            const visualHeight = isExpanded ? (mode === 'music' ? expandedMusicHeight : expandedAppHeight) : 36;

            // Calculate required window height (visual height + shadow buffer)
            // We only need the buffer when expanded or when the shadow is visible
            const windowHeight = isExpanded ? (visualHeight + SHADOW_BUFFER) : 300;
            // When collapsed, we keep 300 to avoid window resizing during the collapse animation 
            // which might look glitchy. 300 is safe.

            if (isExpanded) {
                ipcRenderer.send('resize-widget', {
                    width: WINDOW_WIDTH,
                    height: Math.ceil(windowHeight)
                });
            } else {
                ipcRenderer.send('resize-widget', {
                    width: WINDOW_WIDTH,
                    height: 300
                });
            }
        } catch (e) {
            // Electron IPC not available
        }
    }, [isExpanded, mode]);

    return (
        <div className="flex items-start justify-center w-full h-auto bg-transparent pointer-events-none" style={{ background: 'transparent' }}>
            {/* Inject Font Style */}
            <style>
                {`@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;700&display=swap');
                  body, html { overflow: hidden !important; }
                  html, body, #root { height: 100% !important; }
                  ::-webkit-scrollbar { display: none !important; }
                `}
            </style>
            <motion.div
                className="relative pointer-events-none"
                style={{
                    transform: 'translateZ(0)',
                    filter: shouldShowShadow
                        ? 'drop-shadow(0px 10px 25px rgba(0, 0, 0, 0.22)) drop-shadow(0px 6px 14px rgba(0, 0, 0, 0.18)) drop-shadow(0px 2px 6px rgba(0, 0, 0, 0.12))'
                        : 'none',
                    transition: 'filter 260ms ease-out',
                    willChange: 'transform, filter',
                }}
                initial={false}
                animate={isExpanded ? "expanded" : "collapsed"}
                variants={{
                    collapsed: {
                        width: isActivitySegmentedTransition ? segmentedWidthKeyframes : collapsedWidth,
                        height: isActivitySegmentedTransition ? segmentedHeightKeyframes : 36,
                        scale: isHovered ? 1.06 : 1,
                        originY: 0,
                        transition: isActivityOpenTransition ? {
                            width: { duration: ACTIVITY_OPEN_DURATION_SECONDS, ease: "easeInOut" },
                            height: { duration: ACTIVITY_OPEN_DURATION_SECONDS, ease: "easeInOut" },
                            scale: { ...containerSpring }
                        } : (isActivitySegmentedTransition ? {
                            width: { times: segmentedTimes, duration: segmentedDuration, ease: "easeInOut" },
                            height: { times: segmentedTimes, duration: segmentedDuration, ease: "easeInOut" },
                            scale: { ...containerSpring }
                        } : undefined)
                    },
                    expanded: {
                        width: expandedWidth,
                        height: mode === 'music' ? expandedMusicHeight : expandedAppHeight,
                        scale: 1,
                        originY: 0,
                    }
                }}
                transition={containerSpring}
            >
                {/* Background Layer - To fix animation gap issue */}
                <div className="absolute inset-0 w-full h-full z-40 pointer-events-none flex">
                    {/* Left Cap */}
                    <div className="relative w-[60px] h-full flex-shrink-0">
                        <motion.svg width="60" height="100%" className="w-full h-full overflow-visible">
                            <motion.path
                                fill="#000000"
                                initial={false}
                                animate={isExpanded ? "expanded" : "collapsed"}
                                variants={{
                                    collapsed: {
                                        d: isActivitySegmentedTransition
                                            ? leftCapCollapsedPath
                                            : generateLeftCapPath(36, collapsedCornerRadius, collapsedCornerSmoothness),
                                        transition: isActivityOpenTransition ? {
                                            d: { duration: ACTIVITY_OPEN_DURATION_SECONDS, ease: "easeInOut" }
                                        } : (isActivitySegmentedTransition ? {
                                            d: { times: segmentedTimes, duration: segmentedDuration, ease: "easeInOut" }
                                        } : undefined)
                                    },
                                    expanded: { d: generateLeftCapPath(mode === 'music' ? expandedMusicHeight : expandedAppHeight, 48) }
                                }}
                                transition={containerSpring}
                            />
                        </motion.svg>
                    </div>

                    {/* Middle */}
                    <div className="flex-1 bg-black h-full"></div>

                    {/* Right Cap */}
                    <div className="relative w-[60px] h-full flex-shrink-0">
                        <motion.svg width="60" height="100%" className="w-full h-full overflow-visible">
                            <motion.path
                                fill="#000000"
                                initial={false}
                                animate={isExpanded ? "expanded" : "collapsed"}
                                variants={{
                                    collapsed: {
                                        d: isActivitySegmentedTransition
                                            ? rightCapCollapsedPath
                                            : generateRightCapPath(36, collapsedCornerRadius, collapsedCornerSmoothness),
                                        transition: isActivityOpenTransition ? {
                                            d: { duration: ACTIVITY_OPEN_DURATION_SECONDS, ease: "easeInOut" }
                                        } : (isActivitySegmentedTransition ? {
                                            d: { times: segmentedTimes, duration: segmentedDuration, ease: "easeInOut" }
                                        } : undefined)
                                    },
                                    expanded: { d: generateRightCapPath(mode === 'music' ? expandedMusicHeight : expandedAppHeight, 48) }
                                }}
                                transition={containerSpring}
                            />
                        </motion.svg>
                    </div>
                </div>

                {/* Ears - Liquid connection with dynamic tension and blend height */}
                {(() => {
                    // Calculate ear parameters based on state
                    let currentTension = EAR_TENSION_IDLE;
                    let currentBlendHeight = EAR_BLEND_HEIGHT_IDLE;
                    const isActivityEarState = showAnyActivity || (isGreetingActive && isLoggedIn);

                    if (isExpanded) {
                        currentTension = EAR_TENSION_EXPANDED;
                        currentBlendHeight = EAR_BLEND_HEIGHT_EXPANDED;
                    } else if (isActivityEarState) {
                        // 活动态（音乐/复习/待办）统一使用同一组液态连接角度参数
                        currentTension = EAR_TENSION_ACTIVITY;
                        currentBlendHeight = EAR_BLEND_HEIGHT_ACTIVITY;
                    }

                    return (
                        <>
                            {/* Left ear */}
                            <div className="absolute top-0 w-[40px] h-[40px] z-50 pointer-events-none" style={{ left: '-40px' }}>
                                <motion.svg width="40" height="40" viewBox="0 0 40 40" fill="none" className="overflow-visible">
                                    <motion.path
                                        fill="#000000"
                                        animate={{
                                            d: generateEarPath(true, currentTension, currentBlendHeight)
                                        }}
                                        transition={{
                                            ...containerSpring,
                                            // Ensure smoother morphing for path
                                            d: { duration: 0.4, ease: "easeInOut" }
                                        }}
                                    />
                                </motion.svg>
                            </div>
                            {/* Right ear */}
                            <div className="absolute top-0 w-[40px] h-[40px] z-50 pointer-events-none" style={{ right: '-40px' }}>
                                <motion.svg width="40" height="40" viewBox="0 0 40 40" fill="none" className="overflow-visible">
                                    <motion.path
                                        fill="#000000"
                                        animate={{
                                            d: generateEarPath(false, currentTension, currentBlendHeight)
                                        }}
                                        transition={{
                                            ...containerSpring,
                                            d: { duration: 0.4, ease: "easeInOut" }
                                        }}
                                    />
                                </motion.svg>
                            </div>
                        </>
                    );
                })()}

                <motion.div
                    ref={islandHitRef}
                    onPointerDown={handlePointerDown}
                    onPointerMove={handlePointerMove}
                    onPointerUp={handlePointerUp}
                    onPointerCancel={handlePointerCancel}
                    onWheel={handleTrackpadWheel}
                    className="w-full h-full flex flex-col items-center justify-start text-white select-none drag-region group pointer-events-auto"
                    variants={{
                        collapsed: {
                            // borderRadius: 18 // REMOVED: Clipping conflicts with Squircle shape
                        },
                        expanded: {
                            // borderRadius: 48 // REMOVED: Clipping conflicts with Squircle shape
                        }
                    }}
                    style={{
                        backgroundColor: 'transparent', // Use SVG for background
                        cursor: 'pointer',
                        position: 'relative',
                        zIndex: 9999,
                        // overflow: 'hidden' // REMOVED: Allow SVG Squircle to dictate shape without clipping
                    }}

                    onMouseEnter={() => {
                        if (!isExpanded) {
                            setIsHovered(true);
                        }
                        try {
                            const { ipcRenderer } = (window as any).require('electron');
                            ipcRenderer.send('set-ignore-mouse-events', false);
                        } catch (e) { }
                    }}
                    onMouseLeave={() => {
                        setIsHovered(false);
                        clearTrackpadGestureState();
                        if (activePointerIdRef.current !== null || isGestureTrackingRef.current) {
                            return;
                        }
                        try {
                            const { ipcRenderer } = (window as any).require('electron');
                            if (!isExpandedRef.current) {
                                ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
                            }
                        } catch (e) { }
                    }}
                >
                    {/* Background SVG Layer - For smooth Squircle animation */}
                    <div className="absolute inset-0 w-full h-full pointer-events-none z-0">
                        <motion.svg
                            className="w-full h-full overflow-visible"
                            width="100%"
                            height="100%"
                        >
                            <motion.path
                                fill="#000000"
                                initial={false}
                                animate={isExpanded ? "expanded" : "collapsed"}
                                variants={{
                                    collapsed: {
                                        d: isActivitySegmentedTransition
                                            ? squircleCollapsedPath
                                            : generateSquirclePath(collapsedWidth, 36, collapsedCornerRadius, collapsedCornerSmoothness),
                                        transition: isActivityOpenTransition ? {
                                            d: { duration: ACTIVITY_OPEN_DURATION_SECONDS, ease: "easeInOut" }
                                        } : (isActivitySegmentedTransition ? {
                                            d: { times: segmentedTimes, duration: segmentedDuration, ease: "easeInOut" }
                                        } : undefined)
                                    },
                                    expanded: {
                                        d: generateSquirclePath(expandedWidth, mode === 'music' ? expandedMusicHeight : expandedAppHeight, 48, SQUIRCLE_SMOOTHNESS)
                                    }
                                }}
                                transition={containerSpring}
                            />
                        </motion.svg>
                    </div>

                    {/* Inner Edge Stroke Overlay */}
                    <div className="absolute inset-0 w-full h-full pointer-events-none z-50">
                        <motion.svg
                            className="w-full h-full overflow-visible"
                            width="100%"
                            height="100%"
                            style={{
                                width: '100%',
                                height: '100%',
                                overflow: 'visible'
                            }}
                        >
                            <defs>
                                <clipPath id="inner-stroke-cut-top">
                                    <rect x="-100" y="21" width="2000" height="2000" />
                                </clipPath>
                            </defs>
                            <motion.path
                                fill="none"
                                stroke="rgba(255, 255, 255, 0.12)"
                                strokeWidth="1"
                                vectorEffect="non-scaling-stroke"
                                clipPath="url(#inner-stroke-cut-top)"
                                initial={false}
                                animate={isExpanded ? "expanded" : "collapsed"}
                                variants={{
                                    collapsed: {
                                        d: isActivitySegmentedTransition
                                            ? openSquircleCollapsedPath
                                            : generateOpenSquirclePath(collapsedWidth, 36, collapsedCornerRadius, collapsedCornerSmoothness),
                                        transition: isActivityOpenTransition ? {
                                            d: { duration: ACTIVITY_OPEN_DURATION_SECONDS, ease: "easeInOut" }
                                        } : (isActivitySegmentedTransition ? {
                                            d: { times: segmentedTimes, duration: segmentedDuration, ease: "easeInOut" }
                                        } : undefined)
                                    },
                                    expanded: {
                                        d: generateOpenSquirclePath(expandedWidth, mode === 'music' ? expandedMusicHeight : expandedAppHeight, 48, SQUIRCLE_SMOOTHNESS)
                                    }
                                }}
                                transition={containerSpring}
                            />
                        </motion.svg>
                    </div>

                    {/* Content Container */}
                    <motion.div
                        layout="position"
                        className="w-full h-full flex flex-col relative overflow-hidden"
                    >
                        {/* COLLAPSED STATE CONTENT */}
                        <motion.div
                            initial={false}
                            animate={{
                                opacity: isExpanded ? 0 : 1,
                                filter: isExpanded ? 'blur(5px)' : 'blur(0px)',
                                pointerEvents: isExpanded ? 'none' : 'auto',
                            }}
                            transition={{
                                duration: 0.38,
                                delay: collapsedContentDelay
                            }}
                            className="absolute inset-0 w-full h-full z-20"
                        >
                            {showMusicActivity ? (
                                // MUSIC COLLAPSED STATE
                                <motion.div
                                    key={`music-activity-${activityOpenAnimToken}`}
                                    initial={isActivityOpenTransition ? { opacity: 0, filter: 'blur(4px)' } : false}
                                    animate={{ opacity: 1, filter: 'blur(0px)' }}
                                    transition={isActivityOpenTransition
                                        ? { duration: ACTIVITY_OPEN_CONTENT_DURATION_SECONDS, delay: ACTIVITY_OPEN_CONTENT_DELAY_SECONDS, ease: "easeOut" }
                                        : { duration: 0.12 }}
                                    className="w-full h-full"
                                >
                                    <div className="flex items-center justify-between w-full h-full px-2">
                                        {/* Left: Album Cover */}
                                        <div className="flex items-center pl-[6px]">
                                            <SquircleCoverThumb
                                                src={musicData.coverUrl}
                                                width={COLLAPSED_MUSIC_COVER_WIDTH}
                                                height={COLLAPSED_MUSIC_COVER_HEIGHT}
                                                radius={COLLAPSED_MUSIC_COVER_RADIUS}
                                                smoothness={COLLAPSED_MUSIC_COVER_SMOOTHNESS}
                                                shapeVariant="puffy"
                                                showGloss
                                                backgroundFill="rgba(255,255,255,0.1)"
                                                placeholderIconClassName="material-symbols-outlined text-[14px] text-white/50"
                                            />
                                        </div>

                                        {/* Right: Waveform */}
                                        <div className="pr-[6px]">
                                            <MusicWaveform color={themeColor} isPlaying={musicData.isPlaying} count={4} />
                                        </div>
                                    </div>
                                </motion.div>
                            ) : !isLoggedIn ? (
                                <div className="flex items-center justify-center w-full h-full gap-2 px-3">
                                    <span className="material-symbols-outlined text-sm">login</span>
                                    <span className="text-sm font-bold">点击登录</span>
                                </div>
                            ) : isGreetingActive && greetingText ? (
                                <div className="flex items-center justify-center w-full h-full px-3">
                                    <motion.div
                                        key={greetingText}
                                        initial={{ opacity: 0, y: 6 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        exit={{ opacity: 0, y: -6 }}
                                        transition={{ duration: 0.35, ease: "easeOut" }}
                                        className="w-full min-w-0"
                                    >
                                        <div className="text-[13px] font-semibold text-white/90 truncate text-center" style={{ fontFamily: '"Noto Sans SC", sans-serif' }}>
                                            {greetingText}
                                        </div>
                                    </motion.div>
                                </div>
                            ) : showAppActivity ? (
                                // APP ACTIVITY STATE（复习/待办融合态）
                                <motion.div
                                    key={`app-activity-${appDisplayMode}-${activityOpenAnimToken}`}
                                    initial={isActivityOpenTransition ? { opacity: 0, filter: 'blur(4px)' } : false}
                                    animate={{ opacity: 1, filter: 'blur(0px)' }}
                                    transition={isActivityOpenTransition
                                        ? { duration: ACTIVITY_OPEN_CONTENT_DURATION_SECONDS, delay: ACTIVITY_OPEN_CONTENT_DELAY_SECONDS, ease: "easeOut" }
                                        : { duration: 0.12 }}
                                    className="w-full h-full"
                                >
                                    <div className="flex items-center justify-between w-full h-full px-3">
                                        <div className="flex items-center gap-2 min-w-0">
                                            <button
                                                type="button"
                                                onPointerDown={handleActivityLeftIconPointerDown}
                                                onPointerUp={handleActivityLeftIconPointerEnd}
                                                onPointerLeave={handleActivityLeftIconPointerEnd}
                                                onPointerCancel={handleActivityLeftIconPointerEnd}
                                                onClick={(e) => e.stopPropagation()}
                                                onContextMenu={(e) => e.preventDefault()}
                                                title={appDisplayMode === 'todo' ? '长按切换到复习模式' : '长按切换到待办模式'}
                                                className="flex items-center justify-center rounded-md text-white/90 active:scale-95 transition-transform"
                                            >
                                                {appDisplayMode === 'todo' ? (
                                                    <span className="material-symbols-outlined text-sm text-cyan-300">checklist</span>
                                                ) : (
                                                    <div className="text-amber-300 flex items-center justify-center">
                                                        <ReviewModeIcon />
                                                    </div>
                                                )}
                                            </button>
                                            <span className="text-xs font-semibold text-white/90 truncate">
                                                {appDisplayMode === 'todo'
                                                    ? `待办 ${todoPreview.pending} 项`
                                                    : `复习 ${data.totalPendingReviews} 项`}
                                            </span>
                                        </div>
                                        <div className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${appDisplayMode === 'todo'
                                            ? (todoPreview.overdue > 0 ? 'bg-red-500/20 text-red-300' : 'bg-cyan-500/20 text-cyan-200')
                                            : 'bg-amber-500/20 text-amber-200'
                                            }`}>
                                            {appDisplayMode === 'todo'
                                                ? (todoPreview.overdue > 0 ? `${todoPreview.overdue} 逾期` : `${todoPreview.pending}`)
                                                : `${data.totalPendingReviews}`}
                                        </div>
                                    </div>
                                </motion.div>
                            ) : mode === 'app' && appDisplayMode === 'todo' && !hasAppActivitySource ? (
                                <div className="flex items-center justify-between w-full h-full px-3">
                                    <div className="flex items-center gap-2 min-w-0">
                                        <span className="material-symbols-outlined text-sm text-cyan-300">checklist</span>
                                        <span className="text-xs font-semibold text-white/90 truncate">
                                            {hasPendingTodos ? `待办 ${todoPreview.pending} 项` : '待办模式'}
                                        </span>
                                    </div>
                                    <div className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${todoPreview.overdue > 0 ? 'bg-red-500/20 text-red-300' : 'bg-cyan-500/20 text-cyan-200'}`}>
                                        {todoPreview.overdue > 0 ? `${todoPreview.overdue} 逾期` : `${todoPreview.pending}`}
                                    </div>
                                </div>
                            ) : (
                                // INITIAL STATE
                                <div className="w-full h-full"></div>
                            )}
                        </motion.div>

                        {/* EXPANDED STATE CONTENT */}
                        <motion.div
                            initial={false}
                            animate={{
                                opacity: isExpanded ? 1 : 0,
                                filter: isExpanded ? 'blur(0px)' : 'blur(5px)',
                                pointerEvents: isExpanded ? 'auto' : 'none',
                            }}
                            transition={{ duration: expandedContentFadeDuration }}
                            className="flex flex-col w-full px-9 py-5 pb-5 z-10 overflow-hidden"
                            style={{ width: expandedWidth, minWidth: expandedWidth }}
                        >
                            {mode === 'music' && musicData ? (
                                // MUSIC EXPANDED UI
                                <div className="flex flex-col gap-2">
                                    {/* Layer 1: Top Metadata Section */}
                                    <div className="flex gap-4">
                                        {/* Album Art - Continuous curvature squircle with taller proportion */}
                                        <SquircleCoverThumb
                                            src={musicData.coverUrl}
                                            width={EXPANDED_MUSIC_COVER_WIDTH}
                                            height={EXPANDED_MUSIC_COVER_HEIGHT}
                                            radius={EXPANDED_MUSIC_COVER_RADIUS}
                                            smoothness={EXPANDED_MUSIC_COVER_SMOOTHNESS}
                                            shapeVariant="puffy"
                                            showGloss
                                            className="flex-shrink-0"
                                            style={{
                                                filter: 'drop-shadow(0 10px 22px rgba(0,0,0,0.46)) drop-shadow(0 3px 10px rgba(0,0,0,0.2))'
                                            }}
                                            backgroundFill="rgba(255,255,255,0.12)"
                                            placeholderIconClassName="material-symbols-outlined text-[30px] text-white/50"
                                        />

                                        {/* Info + Waveform */}
                                        <div className="flex-1 flex flex-col justify-center min-w-0">
                                            <div className="flex items-center justify-between gap-2">
                                                <div className="flex flex-col min-w-0 flex-1">
                                                    <span className="text-base text-white truncate" style={{ fontFamily: '"Noto Sans SC", sans-serif' }}>
                                                        {musicData.title}
                                                    </span>
                                                    <span className="text-sm text-white/50 truncate" style={{ fontFamily: '"Noto Sans SC", sans-serif' }}>
                                                        {musicData.artist}
                                                    </span>
                                                </div>
                                                {/* Waveform on the right */}
                                                <div className="flex-shrink-0">
                                                    <MusicWaveform color={themeColor} isPlaying={musicData.isPlaying} />
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    {/* Layer 2: Progress Bar */}
                                    <div className="flex flex-col gap-2 mt-1">
                                        {/* Timestamps + Progress Track in one row */}
                                        {/* Timestamps + Progress Track in one row - Optimized spacing */}
                                        <div className="flex items-center gap-2">
                                            {/* Current Time - Left Aligned (Align with Album Cover) */}
                                            <span className="text-[14px] font-medium tabular-nums leading-none" style={{ color: '#666666', fontFamily: '"Noto Sans SC", sans-serif' }}>
                                                {formatTime(localPosition)}
                                            </span>

                                            {/* Progress Track - Standard Rounded (Revert Squircle) */}
                                            <div className="flex-1 relative h-[8px] rounded-full overflow-hidden" style={{ backgroundColor: '#222222' }}>
                                                <div
                                                    className="absolute left-0 top-0 h-full transition-[width] duration-300 ease-linear"
                                                    style={{
                                                        backgroundColor: '#747376',
                                                        width: `${(localPosition / (musicData.duration || 1)) * 100}%`
                                                    }}
                                                />
                                            </div>

                                            {/* Remaining Time - Right Aligned (Align with Waveform) */}
                                            <span className="text-[14px] font-medium tabular-nums leading-none" style={{ color: '#666666', fontFamily: '"Noto Sans SC", sans-serif' }}>
                                                -{formatTime(Math.max(0, (musicData.duration || 0) - localPosition))}
                                            </span>
                                        </div>
                                    </div>

                                    {/* Layer 3: Control Buttons */}
                                    {/* Layer 3: Control Buttons - Equal Spacing */}
                                    <div className="flex items-center justify-center gap-6 mt-1" style={{ marginBottom: '5px' }}>
                                        {/* Star/Favorite Icon */}
                                        <motion.button
                                            whileTap={{ scale: 0.9 }}
                                            className="p-2 text-white/40 hover:text-white transition-colors"
                                        >
                                            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                                <path d="M12 2 L15 9 L22 9 L16.5 13 L18.5 21 L12 17 L5.5 21 L7.5 13 L2 9 L9 9 Z" />
                                            </svg>
                                        </motion.button>

                                        {/* Previous */}
                                        <motion.button
                                            onClick={handlePrev}
                                            whileHover={{ scale: 1.1 }}
                                            whileTap={{ scale: 0.9 }}
                                            className="p-1 text-white transition-colors outline-none focus:outline-none"
                                        >
                                            <svg width="36" height="36" viewBox="0 0 28 28" fill="currentColor">
                                                {/* First triangle pointing left (Right one) - Shifted right */}
                                                <path d="M 23 6.5 C 23.7 6.5 24 7 24 7.8 L 24 20.2 C 24 21 23.7 21.5 23 21.5 C 22.5 21.5 22.1 21.3 21.5 20.8 L 14.5 15.6 C 14 15.2 13.5 14.7 13.5 14 C 13.5 13.3 14 12.8 14.5 12.4 L 21.5 7.2 C 22.1 6.7 22.5 6.5 23 6.5 Z" />
                                                {/* Second triangle pointing left (Left one) - Shifted left */}
                                                <path d="M 12.5 6.5 C 13.2 6.5 13.5 7 13.5 7.8 L 13.5 20.2 C 13.5 21 13.2 21.5 12.5 21.5 C 12 21.5 11.6 21.3 11 20.8 L 4 15.6 C 3.5 15.2 3 14.7 3 14 C 3 13.3 3.5 12.8 4 12.4 L 11 7.2 C 11.6 6.7 12 6.5 12.5 6.5 Z" />
                                            </svg>
                                        </motion.button>

                                        {/* Play/Pause */}
                                        <motion.button
                                            onClick={handlePlayPause}
                                            whileHover={{ scale: 1.1 }}
                                            whileTap={{ scale: 0.9 }}
                                            className="p-1 text-white transition-colors outline-none focus:outline-none"
                                        >
                                            {musicData.isPlaying ? (
                                                <svg width="52" height="52" viewBox="0 0 24 24" fill="currentColor">
                                                    <rect x="6" y="5" width="4" height="14" rx="1" />
                                                    <rect x="14" y="5" width="4" height="14" rx="1" />
                                                </svg>
                                            ) : (
                                                <svg width="52" height="52" viewBox="0 0 28 28" fill="currentColor">
                                                    {/* Even softer rounded corners */}
                                                    <path d="M 8.5 6 C 7.5 6 6.5 6.8 6.5 8 L 6.5 20 C 6.5 21.2 7.5 22 8.5 22 C 8.9 22 9.4 21.8 9.8 21.5 L 20.8 15.5 C 21.8 14.8 21.8 13.2 20.8 12.5 L 9.8 6.5 C 9.4 6.2 8.9 6 8.5 6 Z" />
                                                </svg>
                                            )}
                                        </motion.button>

                                        {/* Next */}
                                        <motion.button
                                            onClick={handleNext}
                                            whileHover={{ scale: 1.1 }}
                                            whileTap={{ scale: 0.9 }}
                                            className="p-1 text-white transition-colors outline-none focus:outline-none"
                                        >
                                            <svg width="36" height="36" viewBox="0 0 28 28" fill="currentColor">
                                                {/* First triangle pointing right (Left one) - Shifted left */}
                                                <path d="M 5.5 6.5 C 4.8 6.5 4.5 7 4.5 7.8 L 4.5 20.2 C 4.5 21 4.8 21.5 5.5 21.5 C 6 21.5 6.4 21.3 7 20.8 L 14 15.6 C 14.5 15.2 15 14.7 15 14 C 15 13.3 14.5 12.8 14 12.4 L 7 7.2 C 6.4 6.7 6 6.5 5.5 6.5 Z" />
                                                {/* Second triangle pointing right (Right one) - Shifted right */}
                                                <path d="M 15.5 6.5 C 14.8 6.5 14.5 7 14.5 7.8 L 14.5 20.2 C 14.5 21 14.8 21.5 15.5 21.5 C 16 21.5 16.4 21.3 17 20.8 L 24 15.6 C 24.5 15.2 25 14.7 25 14 C 25 13.3 24.5 12.8 24 12.4 L 17 7.2 C 16.4 6.7 16 6.5 15.5 6.5 Z" />
                                            </svg>
                                        </motion.button>

                                        {/* Computer/Laptop Icon */}
                                        <motion.button
                                            whileTap={{ scale: 0.9 }}
                                            className="p-2 text-white/40 hover:text-white transition-colors"
                                        >
                                            <svg width="28" height="28" viewBox="0 0 26 24" fill="none" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                                <path d="M4 16V5c0-1.1.9-2 2-2h14c1.1 0 2 .9 2 2v11" fill="#1B1B1B" stroke="#6D6D6F" />
                                                <rect x="0" y="15" width="26" height="3" rx="1" fill="#6D6D6F" stroke="none" />
                                            </svg>
                                        </motion.button>
                                    </div>
                                </div>
                            ) : appDisplayMode === 'todo' ? (
                                // TODO MODE EXPANDED UI
                                <div className="flex flex-col h-full">
                                    <div className="grid grid-cols-3 gap-3 mb-4">
                                        <div className="flex flex-col items-start justify-between h-20 rounded-xl bg-white/5 p-3">
                                            <span className="text-[10px] font-bold text-white/40 uppercase tracking-wider">待办中</span>
                                            <div className="flex items-baseline gap-1">
                                                <span className="text-3xl font-bold text-cyan-300 tracking-tight">{todoPreview.pending}</span>
                                                <span className="text-xs text-cyan-200/70 font-medium">项</span>
                                            </div>
                                        </div>
                                        <div className="flex flex-col items-start justify-between h-20 rounded-xl bg-white/5 p-3">
                                            <span className="text-[10px] font-bold text-white/40 uppercase tracking-wider">今日到期</span>
                                            <div className="flex items-baseline gap-1">
                                                <span className="text-3xl font-bold text-amber-300 tracking-tight">{todoPreview.dueToday}</span>
                                                <span className="text-xs text-amber-200/70 font-medium">项</span>
                                            </div>
                                        </div>
                                        <div className="flex flex-col items-start justify-between h-20 rounded-xl bg-white/5 p-3">
                                            <span className="text-[10px] font-bold text-white/40 uppercase tracking-wider">已逾期</span>
                                            <div className="flex items-baseline gap-1">
                                                <span className="text-3xl font-bold text-red-400 tracking-tight">{todoPreview.overdue}</span>
                                                <span className="text-xs text-red-300/70 font-medium">项</span>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="flex items-center justify-between mb-3 px-1">
                                        <span className="text-sm font-bold text-white/80 tracking-wide">待办清单</span>
                                        <span className="text-[10px] font-bold text-white/30 uppercase tracking-widest">{new Date().toLocaleDateString('zh-CN', { weekday: 'long' })}</span>
                                    </div>

                                    <div className="flex flex-col gap-2 flex-1 min-h-0 overflow-y-auto pr-1">
                                        {todoPreview.tasks.length === 0 ? (
                                            <div className="h-full flex items-center justify-center text-xs text-white/35">当前暂无待办任务</div>
                                        ) : (
                                            todoPreview.tasks.map((task) => (
                                                <div
                                                    key={task.id}
                                                    className={`flex items-center gap-3 bg-white/5 p-2 rounded-xl transition-colors ${task.status === 'completed' ? 'opacity-70' : 'hover:bg-white/10'}`}
                                                >
                                                    <button
                                                        onClick={(e) => handleToggleTodoTask(e, task.id)}
                                                        disabled={!!todoPendingOps[task.id]}
                                                        className="size-5 rounded-full border-2 border-white/35 flex items-center justify-center hover:border-cyan-300 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                                                    >
                                                        {task.status === 'completed' ? (
                                                            <span className="material-symbols-outlined text-[14px] text-cyan-300">check</span>
                                                        ) : (
                                                            <div className="size-2 rounded-full bg-cyan-300/70" />
                                                        )}
                                                    </button>

                                                    <div className="flex flex-col flex-1 min-w-0">
                                                        <span className={`text-xs font-bold truncate ${task.status === 'completed' ? 'text-white/45 line-through' : 'text-white'}`}>
                                                            {task.title || '未命名任务'}
                                                        </span>
                                                        <span className="text-[10px] text-white/40 truncate">{formatTodoDue(task)}</span>
                                                    </div>

                                                    <div
                                                        className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${task.priority === 'high'
                                                            ? 'bg-red-500/20 text-red-300'
                                                            : task.priority === 'medium'
                                                            ? 'bg-amber-500/20 text-amber-300'
                                                            : task.priority === 'low'
                                                            ? 'bg-blue-500/20 text-blue-300'
                                                            : 'bg-slate-500/20 text-slate-300'
                                                            }`}
                                                    >
                                                        {task.priority === 'high' ? '高' : task.priority === 'medium' ? '中' : task.priority === 'low' ? '低' : '无'}
                                                    </div>
                                                </div>
                                            ))
                                        )}
                                    </div>
                                </div>
                            ) : (
                                // REVIEW MODE EXPANDED UI
                                <>
                                    {/* Top Row: Overview Cards */}
                                    <div className="flex gap-4 mb-6">
                                        <div className="flex-1 flex flex-col items-start justify-between h-20 group/card">
                                            <span className="text-xs font-bold text-white/40 uppercase tracking-wider mb-1">待复习</span>
                                            <div className="flex items-baseline gap-1">
                                                <span className="text-5xl font-bold text-white tracking-tighter">{data.totalPendingReviews}</span>
                                                <span className="text-sm text-white/40 font-medium">项</span>
                                            </div>
                                        </div>

                                        <div className="flex-1 flex flex-col items-start justify-between h-20 pl-4 border-l border-white/10">
                                            <span className="text-xs font-bold text-white/40 uppercase tracking-wider mb-1">今日完成</span>
                                            <div className="flex items-baseline gap-1">
                                                <span className="text-5xl font-bold text-green-400 tracking-tighter">{data.totalCompletedToday}</span>
                                                <span className="text-sm text-green-400/60 font-medium">项</span>
                                            </div>
                                        </div>
                                    </div>

                                    {/* Header for List */}
                                    <div className="flex items-center justify-between mb-4 px-1">
                                        <span className="text-sm font-bold text-white/80 tracking-wide">复习计划</span>
                                        <span className="text-[10px] font-bold text-white/30 uppercase tracking-widest">{new Date().toLocaleDateString('zh-CN', { weekday: 'long' })}</span>
                                    </div>

                                    {/* List of Subjects */}
                                    <motion.div
                                        className="grid grid-cols-2 gap-2 w-full"
                                        variants={{
                                            hidden: { opacity: 0 },
                                            visible: {
                                                opacity: 1,
                                                transition: { staggerChildren: 0.05, delayChildren: 0.1 }
                                            }
                                        }}
                                        initial="hidden"
                                        animate={isExpanded ? "visible" : "hidden"}
                                    >
                                        {(() => {
                                            const activeSubjects = data.subjects.filter(s => s.pendingReviewCount > 0);
                                            const displaySubjects = activeSubjects.slice(0, 4);
                                            const hasMore = activeSubjects.length > 4;
                                            const emptySlots = Math.max(0, 4 - displaySubjects.length);

                                            return (
                                                <>
                                                    {/* Real Data Items */}
                                                    {displaySubjects.map((subject) => (
                                                        <motion.div
                                                            key={subject.id}
                                                            variants={{
                                                                hidden: { opacity: 0, scale: 0.9 },
                                                                visible: {
                                                                    opacity: 1,
                                                                    scale: 1,
                                                                    transition: { type: "spring", stiffness: 300, damping: 20 }
                                                                }
                                                            }}
                                                            className="flex items-center gap-3 bg-white/5 p-2 rounded-xl hover:bg-white/10 transition-colors group cursor-default"
                                                        >
                                                            <div className="size-8 rounded-lg bg-blue-500/20 text-blue-400 flex items-center justify-center shrink-0 group-hover:bg-blue-500/30 transition-colors">
                                                                <span className="material-symbols-outlined text-base">{subject.icon || 'school'}</span>
                                                            </div>
                                                            <div className="flex flex-col flex-1 min-w-0">
                                                                <span className="text-xs font-bold text-white truncate">{subject.title}</span>
                                                                <span className="text-[9px] text-white/40 truncate">截止</span>
                                                            </div>
                                                            <div className="flex items-center justify-center bg-red-500/20 px-1.5 py-0.5 rounded text-red-400">
                                                                <span className="text-xs font-bold">{subject.pendingReviewCount}</span>
                                                            </div>
                                                        </motion.div>
                                                    ))}

                                                    {/* Empty Slot Placeholders */}
                                                    {emptySlots > 0 && Array.from({ length: emptySlots }).map((_, i) => (
                                                        <motion.div
                                                            key={`empty-${i}`}
                                                            variants={{
                                                                hidden: { opacity: 0 },
                                                                visible: { opacity: 1 }
                                                            }}
                                                            className="flex items-center gap-3 bg-white/5 p-2 rounded-xl opacity-30 cursor-default"
                                                        >
                                                            <div className="size-8 rounded-lg bg-white/10 flex items-center justify-center shrink-0">
                                                                <div className="w-4 h-4 rounded bg-white/20" />
                                                            </div>
                                                            <div className="flex flex-col flex-1 min-w-0 gap-1.5">
                                                                <div className="h-2.5 w-16 bg-white/10 rounded-sm" />
                                                                <div className="h-2 w-8 bg-white/10 rounded-sm" />
                                                            </div>
                                                        </motion.div>
                                                    ))}

                                                    {/* Footer Message */}
                                                    <motion.div
                                                        variants={{
                                                            hidden: { opacity: 0 },
                                                            visible: { opacity: 1 }
                                                        }}
                                                        className="col-span-2 flex items-center justify-center py-2"
                                                    >
                                                        <span className="text-[10px] text-white/30 font-medium">
                                                            {hasMore
                                                                ? `+还有 ${activeSubjects.length - 4} 个待复习科目`
                                                                : '已显示全部'
                                                            }
                                                        </span>
                                                    </motion.div>
                                                </>
                                            );
                                        })()}
                                    </motion.div>
                                </>
                            )}
                        </motion.div>
                    </motion.div>
                </motion.div>
            </motion.div>
        </div>

    );
};

export default DynamicIslandWidget;
