import React, { useState, useEffect, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import request from '../utils/request';
import logo from '../assets/logo.png';

// Spring configuration for container
const containerSpring: any = {
    type: "spring",
    stiffness: 280,
    damping: 30,
    mass: 1.2,
};

// SQUIRCLE SMOOTHNESS CONFIGURATION
// 3.5: Very round (接近圆形)
// 4.0: Balanced (平衡，像 iOS App 图标)
// 4.8: Sleek/Modern (更接近 iOS 灵动岛的硬朗感，默认推荐)
const SQUIRCLE_SMOOTHNESS = 2.25; // 修改此处数值以调整圆角平滑度

// --- 状态 1: 静止/空闲态 (Idle/Empty) ---
// 只有小胶囊，无任何活动时
const EAR_TENSION_IDLE = 0.6;       // 张力较小
const EAR_BLEND_HEIGHT_IDLE = 14;    // 融合高度最小 (e.g. 4-8px)

// --- 状态 2: 活动/音乐态 (Activity/Music) ---
// 胶囊变宽显示波形或封面时
const EAR_TENSION_ACTIVITY = 0.2;   // 张力适中
const EAR_BLEND_HEIGHT_ACTIVITY = 26; // 融合高度中等 (e.g. 10-16px)

// --- 状态 3: 展开态 (Expanded) ---
// 完整的大卡片面板
const EAR_TENSION_EXPANDED = 0.7;   // 张力最大 (液态感最强)
const EAR_BLEND_HEIGHT_EXPANDED = 32; // 融合高度最大，消除大转角的夹角感 (e.g. 20-30px)

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

// Electric Current Animation Component - Internal Right Side
const ElectricCurrent = () => {
    return (
        <div className="relative w-full h-full flex items-center justify-center overflow-hidden">
            <motion.svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                xmlns="http://www.w3.org/2000/svg"
                className="drop-shadow-[0_0_8px_rgba(34,211,238,0.8)]"
            >
                <motion.path
                    d="M13 2L3 14H12L11 22L21 10H12L13 2Z"
                    stroke="#22d3ee"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    initial={{ pathLength: 0, opacity: 0 }}
                    animate={{
                        pathLength: [0, 1, 1, 0],
                        opacity: [0, 1, 1, 0],
                        strokeWidth: [2, 3, 2]
                    }}
                    transition={{
                        duration: 1.5,
                        repeat: Infinity,
                        ease: "easeInOut",
                        times: [0, 0.4, 0.6, 1]
                    }}
                />
            </motion.svg>
        </div>
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

// Format time in mm:ss
const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
};

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

const DynamicIslandWidget: React.FC = () => {
    const [isExpanded, setIsExpanded] = useState(false);
    const [isLoggedIn, setIsLoggedIn] = useState(false);
    const [forceCompactMode, setForceCompactMode] = useState(false);
    const [isReminderActive, setIsReminderActive] = useState(false);
    const [isHovered, setIsHovered] = useState(false);

    // Music state
    const [mode, setMode] = useState<'app' | 'music'>('app');
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
    const musicTimeoutRef = useRef<NodeJS.Timeout | null>(null);

    // Track when playback started (for simulating progress when server doesn't provide it)
    const playStartTimeRef = useRef<number | null>(null);
    const playStartPositionRef = useRef<number>(0);

    const startX = useRef(0);
    const [data, setData] = useState<WidgetData>({
        totalPendingReviews: 0,
        totalCompletedToday: 0,
        subjects: []
    });

    // Handle music IPC events
    useEffect(() => {
        let ipcRenderer: any = null;
        try {
            ipcRenderer = (window as any).require('electron').ipcRenderer;

            const handleMusicUpdate = (_event: any, data: MusicData) => {
                console.log('[DynamicIsland] 🎵 Received music data:', data);
                console.log('[DynamicIsland] 📊 Data breakdown:', {
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
                        console.log('[DynamicIsland] 🔒 Music detected but user not logged in, ignoring.');
                        return;
                    }

                    setMusicData(data);
                    // Position sync is handled by the dedicated sync useEffect
                    // Do NOT set localPosition here — for apps like NetEase Cloud Music
                    // where data.position is always 0, this would reset the local timer every 500ms
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
                console.log('[DynamicIsland] 🎼 Title changed, syncing position to:', serverPos);
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
                console.log('[DynamicIsland] 🆕 Initial sync, setting position to:', serverPos);
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
                    console.log('[DynamicIsland] ⏩ Server position changed, syncing:', serverPos, '(drift:', drift, ')');
                    setLocalPosition(serverPos);
                    playStartTimeRef.current = Date.now();
                    playStartPositionRef.current = serverPos;
                }
            } else if (!musicData.isPlaying) {
                // 暂停状态 + 服务端位置未变 → 但如果跟本地差太多也同步 (处理暂停后拖动)
                const drift = Math.abs(serverPos - localPosition);
                if (drift > 1) {
                    console.log('[DynamicIsland] ⏸️ Paused drift detected, syncing:', serverPos);
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

    // Handle gestures
    const handlePointerDown = (e: React.PointerEvent) => {
        // Prevent interaction if clicking on a button
        if ((e.target as HTMLElement).closest('button')) return;
        startX.current = e.clientX;
    };

    const handlePointerUp = (e: React.PointerEvent) => {
        // Prevent interaction if clicking on a button
        if ((e.target as HTMLElement).closest('button')) return;

        const diff = e.clientX - startX.current;
        if (Math.abs(diff) < 10) {
            toggleExpand();
        } else if (diff > 50) {
            if (hasPendingReviews && !forceCompactMode) {
                setForceCompactMode(true);
            }
        } else if (diff < -50) {
            if (hasPendingReviews && forceCompactMode) {
                setForceCompactMode(false);
            }
        }
    };

    // Helper to open login
    const openLogin = () => {
        try {
            const { shell } = (window as any).require('electron');
            shell.openExternal('http://localhost:3000/#/login?callback=desktop');
        } catch (e) {
            console.error('Cannot open external link', e);
        }
    };

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

        const fetchData = async () => {
            try {
                const res: any = await request({
                    url: '/widget/summary',
                    method: 'get'
                });

                if (res.code === 200) {
                    setData(res.data);
                } else {
                    localStorage.removeItem('token');
                    setIsLoggedIn(false);
                }
            } catch (error: any) {
                console.error("Widget fetch error", error);
                localStorage.removeItem('token');
                setIsLoggedIn(false);
            }
        };

        const token = localStorage.getItem('token');
        if (token) {
            setIsLoggedIn(true);
            fetchData();
        }

        let ipcRenderer: any = null;
        try {
            ipcRenderer = (window as any).require('electron').ipcRenderer;
            ipcRenderer.on('auth-token', (_event: any, token: string) => {
                console.log('Received token via IPC');
                localStorage.setItem('token', token);
                setIsLoggedIn(true);
                fetchData();
            });
        } catch (e) {
            console.warn('Electron IPC not available');
        }

        const timer = setInterval(() => {
            if (localStorage.getItem('token')) fetchData();
        }, 60000);

        return () => {
            clearInterval(timer);
            if (ipcRenderer) {
                ipcRenderer.removeAllListeners('auth-token');
            }
        };
    }, []);

    // Time check for reminder
    useEffect(() => {
        const checkTime = () => {
            if (!data.reminderTime) return;

            const now = new Date();
            const [hours, minutes] = data.reminderTime.split(':').map(Number);
            const reminderDate = new Date();
            reminderDate.setHours(hours, minutes, 0, 0);

            if (now >= reminderDate) {
                setIsReminderActive(true);
            } else {
                setIsReminderActive(false);
            }
        };

        checkTime();
        const interval = setInterval(checkTime, 10000);
        return () => clearInterval(interval);
    }, [data.reminderTime]);

    // Dynamic dimensions
    const expandedWidth = 460;
    const expandedMusicHeight = 210;
    const expandedAppHeight = 328; // Fixed height for App mode (fits 4 items + stats)
    const hasPendingReviews = data.totalPendingReviews > 0;
    const showReminder = hasPendingReviews && isReminderActive && !forceCompactMode && mode === 'app';

    // Determine collapsed width based on mode
    const getCollapsedWidth = () => {
        if (mode === 'music' && musicData) {
            return 210; // Wider for music mode (Cover + Space + Waveform)
        }
        return isLoggedIn ? (showReminder ? 240 : 160) : 180;
    };
    const collapsedWidth = getCollapsedWidth();

    // Get theme color for music
    const themeColor = musicData?.themeColor || '#22d3ee';

    // Base width for animation (standard collapsed state)
    const baseWidth = isLoggedIn ? 160 : 180;

    // 固定窗口大小以避免动画时的闪烁问题 (Canvas Strategy)
    // 窗口始终保持最大尺寸，通过忽略鼠标事件(setIgnoreMouseEvents)来实现点击穿透
    const WINDOW_WIDTH = 520;
    const SHADOW_BUFFER = 40; // Buffer for shadow (24px blur + 4px offset + safety)

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
                style={{ transform: 'translateZ(0)' }}
                initial={false}
                animate={isExpanded ? "expanded" : "collapsed"}
                variants={{
                    collapsed: {
                        width: mode === 'music' ? [null, 155, 155, collapsedWidth] : collapsedWidth,
                        height: mode === 'music' ? [null, 36, 36, 36] : 36,
                        scale: isHovered ? 1.06 : 1,
                        originY: 0,
                        transition: mode === 'music' ? {
                            width: { times: [0, 0.45, 0.55, 1], duration: 0.85, ease: "easeInOut" },
                            height: { times: [0, 0.45, 0.55, 1], duration: 0.85, ease: "easeInOut" },
                            scale: { ...containerSpring }
                        } : undefined
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
                                        d: mode === 'music'
                                            ? [null, generateLeftCapPath(36, 18), generateLeftCapPath(36, 18), generateLeftCapPath(36, 18)]
                                            : generateLeftCapPath(36, 18),
                                        transition: mode === 'music' ? {
                                            d: { times: [0, 0.45, 0.55, 1], duration: 0.85, ease: "easeInOut" }
                                        } : undefined
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
                                        d: mode === 'music'
                                            ? [null, generateRightCapPath(36, 18), generateRightCapPath(36, 18), generateRightCapPath(36, 18)]
                                            : generateRightCapPath(36, 18),
                                        transition: mode === 'music' ? {
                                            d: { times: [0, 0.45, 0.55, 1], duration: 0.85, ease: "easeInOut" }
                                        } : undefined
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

                    if (isExpanded) {
                        currentTension = EAR_TENSION_EXPANDED;
                        currentBlendHeight = EAR_BLEND_HEIGHT_EXPANDED;
                    } else if (mode === 'music' && musicData) {
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
                    onPointerDown={handlePointerDown}
                    onPointerUp={handlePointerUp}
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
                        try {
                            const { ipcRenderer } = (window as any).require('electron');
                            ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
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
                                        d: mode === 'music'
                                            ? [null, generateSquirclePath(155, 36, 18, SQUIRCLE_SMOOTHNESS), generateSquirclePath(155, 36, 18, SQUIRCLE_SMOOTHNESS), generateSquirclePath(collapsedWidth, 36, 18, SQUIRCLE_SMOOTHNESS)]
                                            : generateSquirclePath(collapsedWidth, 36, 18, SQUIRCLE_SMOOTHNESS),
                                        transition: mode === 'music' ? {
                                            d: { times: [0, 0.45, 0.55, 1], duration: 0.85, ease: "easeInOut" }
                                        } : undefined
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
                                        d: mode === 'music'
                                            ? [null, generateOpenSquirclePath(155, 36, 18, SQUIRCLE_SMOOTHNESS), generateOpenSquirclePath(155, 36, 18, SQUIRCLE_SMOOTHNESS), generateOpenSquirclePath(collapsedWidth, 36, 18, SQUIRCLE_SMOOTHNESS)]
                                            : generateOpenSquirclePath(collapsedWidth, 36, 18, SQUIRCLE_SMOOTHNESS),
                                        transition: mode === 'music' ? {
                                            d: { times: [0, 0.45, 0.55, 1], duration: 0.85, ease: "easeInOut" }
                                        } : undefined
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
                                duration: 0.38, // Match the expansion duration (0.45s to 0.85s is 0.38s)
                                delay: (!isExpanded && mode === 'music') ? 0.47 : 0
                            }}
                            className="absolute inset-0 w-full h-full z-20"
                        >
                            {mode === 'music' && musicData ? (
                                // MUSIC COLLAPSED STATE
                                <div className="flex items-center justify-between w-full h-full px-2">
                                    {/* Left: Album Cover */}
                                    <div className="flex items-center pl-1">
                                        <div className="w-7 h-7 rounded-lg overflow-hidden bg-white/10 flex-shrink-0">
                                            {musicData.coverUrl ? (
                                                <img
                                                    src={musicData.coverUrl}
                                                    alt="Album"
                                                    className="w-full h-full object-cover"
                                                />
                                            ) : (
                                                <div className="w-full h-full flex items-center justify-center">
                                                    <span className="material-symbols-outlined text-sm text-white/50">music_note</span>
                                                </div>
                                            )}
                                        </div>
                                    </div>

                                    {/* Right: Waveform */}
                                    <div className="pr-1">
                                        <MusicWaveform color={themeColor} isPlaying={musicData.isPlaying} count={4} />
                                    </div>
                                </div>
                            ) : !isLoggedIn ? (
                                <div className="flex items-center justify-center w-full h-full gap-2 px-3">
                                    <span className="material-symbols-outlined text-sm">login</span>
                                    <span className="text-sm font-bold">点击登录</span>
                                </div>
                            ) : showReminder ? (
                                // REMINDER STATE
                                <>
                                    <div className="absolute left-0 top-0 h-full flex items-center justify-center w-[40px] pl-1.5">
                                        <div className="bg-white rounded-[6px] p-[2px] w-6 h-6 flex items-center justify-center shadow-lg">
                                            <img
                                                src={logo}
                                                alt="MemoryFlow"
                                                className="w-full h-full object-contain"
                                            />
                                        </div>
                                    </div>
                                    <div className="absolute right-0 top-0 h-full flex items-center justify-center w-[40px] pr-1.5">
                                        <ElectricCurrent />
                                    </div>
                                </>
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
                            transition={{ duration: isExpanded ? 0.3 : 0.15 }}
                            className="flex flex-col w-full px-9 py-5 pb-5 z-10 overflow-hidden"
                            style={{ width: expandedWidth, minWidth: expandedWidth }}
                        >
                            {mode === 'music' && musicData ? (
                                // MUSIC EXPANDED UI
                                <div className="flex flex-col gap-2">
                                    {/* Layer 1: Top Metadata Section */}
                                    <div className="flex gap-4">
                                        {/* Album Art */}
                                        {/* Album Art - Squircle-like smooth corners + Soft diffuse shadow */}
                                        <div className="w-20 h-20 rounded-[18px] overflow-hidden bg-white/10 flex-shrink-0 shadow-[0_8px_24px_rgba(0,0,0,0.5)]">
                                            {musicData.coverUrl ? (
                                                <img
                                                    src={musicData.coverUrl}
                                                    alt="Album"
                                                    className="w-full h-full object-cover"
                                                />
                                            ) : (
                                                <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-white/20 to-white/5">
                                                    <span className="material-symbols-outlined text-3xl text-white/50">music_note</span>
                                                </div>
                                            )}
                                        </div>

                                        {/* Info + Waveform */}
                                        <div className="flex-1 flex flex-col justify-end min-w-0 pb-0.5">
                                            <div className="flex items-start justify-between gap-2">
                                                <div className="flex flex-col min-w-0 flex-1">
                                                    <span className="text-base text-white truncate" style={{ fontFamily: '"Noto Sans SC", sans-serif' }}>
                                                        {musicData.title}
                                                    </span>
                                                    <span className="text-sm text-white/50 truncate" style={{ fontFamily: '"Noto Sans SC", sans-serif' }}>
                                                        {musicData.artist}
                                                    </span>
                                                </div>
                                                {/* Waveform on the right */}
                                                <div className="flex-shrink-0 pt-1">
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
                            ) : (
                                // APP MODE EXPANDED UI (Original Reminder UI)
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
