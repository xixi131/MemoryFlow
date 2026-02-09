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

// Music Waveform Component - Animated bars
const MusicWaveform: React.FC<{ color: string; isPlaying: boolean }> = ({ color, isPlaying }) => {
    const bars = [0, 1, 2, 3, 4];

    return (
        <div className="flex items-center justify-center gap-[2px] h-6">
            {bars.map((i) => (
                <motion.div
                    key={i}
                    className="w-[3px] rounded-full"
                    style={{ backgroundColor: color }}
                    initial={{ height: 4 }}
                    animate={isPlaying ? {
                        height: [4, 16, 8, 20, 6, 12, 4],
                    } : { height: 4 }}
                    transition={{
                        duration: 0.8,
                        repeat: Infinity,
                        delay: i * 0.12,
                        ease: "easeInOut"
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
// Using a slightly adjusted cubic bezier control point for smoother corners
const generateSquirclePath = (width: number, height: number, radius: number) => {
    // 0.6 is a common approximation for squircle-like smoothing (standard circle is ~0.55)
    // For iOS super-ellipse look, we can push it slightly further, e.g., 0.62
    const k = 0.62;
    const r = radius;
    const ctrl = r * k;

    // Top-left (0,0) -> Top-Right (w, 0) -> Right Side (w, h-r)
    // Curve to Bottom-Right (w-r, h)
    // Bottom Side (r, h)
    // Curve to Bottom-Left (0, h-r)
    // Left Side (0, 0)

    return `
        M 0 0
        L ${width} 0
        L ${width} ${height - r}
        C ${width} ${height - r + ctrl} ${width - r + ctrl} ${height} ${width - r} ${height}
        L ${r} ${height}
        C ${r - ctrl} ${height} 0 ${height - r + ctrl} 0 ${height - r}
        Z
    `.replace(/\s+/g, ' ').trim();
};

// Helper for border stroke - OPEN at the top (U-shape) to prevent double border at top edge
const generateOpenSquirclePath = (width: number, height: number, radius: number) => {
    const k = 0.62;
    const r = radius;
    const ctrl = r * k;

    // Start Top-Right (w, 0) -> Right Side -> Bottom -> Left Side -> Top-Left (0,0)
    // Do NOT close path (Z) and do NOT draw top line
    return `
        M ${width} 0
        L ${width} ${height - r}
        C ${width} ${height - r + ctrl} ${width - r + ctrl} ${height} ${width - r} ${height}
        L ${r} ${height}
        C ${r - ctrl} ${height} 0 ${height - r + ctrl} 0 ${height - r}
        L 0 0
    `.replace(/\s+/g, ' ').trim();
};

const DynamicIslandWidget: React.FC = () => {
    const [isExpanded, setIsExpanded] = useState(false);
    const [isLoggedIn, setIsLoggedIn] = useState(false);
    const [forceCompactMode, setForceCompactMode] = useState(false);
    const [isReminderActive, setIsReminderActive] = useState(false);

    // Music state
    const [mode, setMode] = useState<'app' | 'music'>('app');
    const [musicData, setMusicData] = useState<MusicData | null>(null);
    const [localPosition, setLocalPosition] = useState(0);
    const musicTimeoutRef = useRef<NodeJS.Timeout | null>(null);

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
                console.log('[DynamicIsland] Received music data:', data);

                // Clear timeout for switching back to app mode
                if (musicTimeoutRef.current) {
                    clearTimeout(musicTimeoutRef.current);
                    musicTimeoutRef.current = null;
                }

                if (data && (data.status === 'Playing' || data.status === 'Paused')) {
                    setMusicData(data);
                    setLocalPosition(data.position);
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

    // Local position update for smooth progress bar - only when playing
    useEffect(() => {
        if (!musicData?.isPlaying) return;

        const interval = setInterval(() => {
            setLocalPosition(prev => {
                const newPos = prev + 1;
                return newPos <= (musicData?.duration || 0) ? newPos : prev;
            });
        }, 1000);

        return () => clearInterval(interval);
    }, [musicData?.isPlaying, musicData?.duration]);

    // Sync local position when music data updates - with smart anti-flicker logic
    const lastTitleRef = useRef<string>('');
    const initialSyncDoneRef = useRef<boolean>(false);
    useEffect(() => {
        if (musicData) {
            const serverPos = musicData.position;
            const diff = Math.abs(serverPos - localPosition);
            const titleChanged = musicData.title !== lastTitleRef.current;

            // Always sync on song change
            if (titleChanged) {
                setLocalPosition(serverPos);
                lastTitleRef.current = musicData.title;
                initialSyncDoneRef.current = true;
                return;
            }

            // Initial sync for first load
            if (!initialSyncDoneRef.current) {
                setLocalPosition(serverPos);
                initialSyncDoneRef.current = true;
                return;
            }

            // When playing: only sync if drift > 2 seconds
            // When paused: only sync if user seeked (diff > 5 seconds, indicating manual seek)
            if (musicData.isPlaying && diff > 2) {
                setLocalPosition(serverPos);
            } else if (!musicData.isPlaying && diff > 5) {
                // Large jump while paused = user seeked
                setLocalPosition(serverPos);
            }
            // Otherwise: ignore server updates to prevent flickering
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
        startX.current = e.clientX;
    };

    const handlePointerUp = (e: React.PointerEvent) => {
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
    const expandedMusicHeight = 228;
    const hasPendingReviews = data.totalPendingReviews > 0;
    const showReminder = hasPendingReviews && isReminderActive && !forceCompactMode && mode === 'app';

    // Determine collapsed width based on mode
    const getCollapsedWidth = () => {
        if (mode === 'music' && musicData) {
            return 200; // Wider for music mode
        }
        return isLoggedIn ? (showReminder ? 240 : 160) : 180;
    };
    const collapsedWidth = getCollapsedWidth();

    // Get theme color for music
    const themeColor = musicData?.themeColor || '#22d3ee';

    return (
        <div className="flex items-start justify-center w-full h-auto bg-transparent pointer-events-none" style={{ background: 'transparent' }}>
            {/* Inject Font Style */}
            <style>
                {`@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;700&display=swap');`}
            </style>
            <motion.div
                className="relative pointer-events-none"
                style={{ transform: 'translateZ(0)' }}
                initial={false}
                animate={isExpanded ? "expanded" : "collapsed"}
                variants={{
                    collapsed: {
                        width: collapsedWidth,
                        height: 36,
                    },
                    expanded: {
                        width: expandedWidth,
                        height: mode === 'music' ? expandedMusicHeight : 200,
                    }
                }}
                transition={containerSpring}
            >
                {/* Ears - Smoother, larger liquid transition with 1px overlap to prevent cracks */}
                {/* Left ear - Static left positioning works fine */}
                <div className="absolute top-0 w-[22px] h-[22px] z-50 pointer-events-none" style={{ left: '-21px' }}>
                    <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
                        {/* Enhanced liquid curve: Starts vertical, eases to horizontal with surface tension */}
                        <path d="M22 22 C 22 8 14 0 0 0 H 22 V 22 Z" fill="#000000" />
                    </svg>
                </div>
                {/* Right ear - Mirror left ear positioning with right instead of left */}
                {/* Fixed: Adjusted right offset to -20px (2px overlap) to prevent separation gap during animation */}
                <div className="absolute top-0 w-[22px] h-[22px] z-50 pointer-events-none" style={{ right: '-20px' }}>
                    <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
                        <path d="M0 22 C 0 8 8 0 22 0 H 0 V 22 Z" fill="#000000" />
                    </svg>
                </div>

                <motion.div
                    onPointerDown={handlePointerDown}
                    onPointerUp={handlePointerUp}
                    className="w-full h-full flex flex-col items-center justify-start text-white select-none drag-region group pointer-events-auto"
                    variants={{
                        collapsed: {
                            clipPath: `path('${generateSquirclePath(collapsedWidth, 36, 18)}')`
                        },
                        expanded: {
                            clipPath: `path('${generateSquirclePath(expandedWidth, mode === 'music' ? expandedMusicHeight : 200, 48)}')`
                        }
                    }}
                    style={{
                        backgroundColor: '#000000',
                        cursor: 'pointer',
                        position: 'relative',
                        zIndex: 9999,
                        // Add deep shadow filter here since clip-path clips standard box-shadow
                        filter: 'drop-shadow(0px 4px 24px rgba(0, 0, 0, 0.25))',
                    }}

                    onMouseEnter={() => {
                        try {
                            const { ipcRenderer } = (window as any).require('electron');
                            ipcRenderer.send('set-ignore-mouse-events', false);
                        } catch (e) { }
                    }}
                    onMouseLeave={() => {
                        try {
                            const { ipcRenderer } = (window as any).require('electron');
                            ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
                        } catch (e) { }
                    }}
                >
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
                                        d: generateOpenSquirclePath(collapsedWidth, 36, 18)
                                    },
                                    expanded: {
                                        d: generateOpenSquirclePath(expandedWidth, mode === 'music' ? expandedMusicHeight : 200, 48)
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
                            transition={{ duration: 0.2 }}
                            className="absolute inset-0 w-full h-full z-20"
                        >
                            {mode === 'music' && musicData ? (
                                // MUSIC COLLAPSED STATE
                                <div className="flex items-center justify-between w-full h-full px-2">
                                    {/* Left: Album Cover */}
                                    <div className="flex items-center gap-2">
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
                                        {/* Title - truncated */}
                                        <span className="text-xs font-medium text-white truncate max-w-[80px]">
                                            {musicData.title}
                                        </span>
                                    </div>

                                    {/* Right: Waveform */}
                                    <div className="pr-1">
                                        <MusicWaveform color={themeColor} isPlaying={musicData.isPlaying} />
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
                            transition={{ duration: 0.3 }}
                            className="flex flex-col w-full px-9 py-5 z-10 overflow-hidden"
                            style={{ width: expandedWidth, minWidth: expandedWidth }}
                        >
                            {mode === 'music' && musicData ? (
                                // MUSIC EXPANDED UI
                                <div className="flex flex-col gap-2.5">
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
                                    <div className="flex items-center justify-center gap-6 mt-2" style={{ marginBottom: '5px' }}>
                                        {/* Star/Favorite Icon */}
                                        <motion.button
                                            whileTap={{ scale: 0.9 }}
                                            className="p-2 text-white/40 hover:text-white transition-colors"
                                        >
                                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                                                <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                                            </svg>
                                        </motion.button>

                                        {/* Previous */}
                                        <motion.button
                                            onClick={handlePrev}
                                            onPointerUp={(e) => e.stopPropagation()}
                                            whileTap={{ scale: 0.9 }}
                                            className="p-1 text-white hover:text-white/80 transition-colors"
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
                                            onPointerUp={(e) => e.stopPropagation()}
                                            whileTap={{ scale: 0.9 }}
                                            className="p-1 text-white hover:text-white/80 transition-colors"
                                        >
                                            {musicData.isPlaying ? (
                                                <svg width="52" height="52" viewBox="0 0 24 24" fill="currentColor">
                                                    <rect x="6" y="5" width="4" height="14" rx="1.5" />
                                                    <rect x="14" y="5" width="4" height="14" rx="1.5" />
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
                                            onPointerUp={(e) => e.stopPropagation()}
                                            whileTap={{ scale: 0.9 }}
                                            className="p-1 text-white hover:text-white/80 transition-colors"
                                        >
                                            <svg width="36" height="36" viewBox="0 0 28 28" fill="currentColor">
                                                {/* First triangle pointing right (Left one) - Shifted left */}
                                                <path d="M 5.5 6.5 C 4.8 6.5 4.5 7 4.5 7.8 L 4.5 20.2 C 4.5 21 4.8 21.5 5.5 21.5 C 6 21.5 6.4 21.3 7 20.8 L 14 15.6 C 14.5 15.2 15 14.7 15 14 C 15 13.3 14.5 12.8 14 12.4 L 7 7.2 C 6.4 6.7 6 6.5 5.5 6.5 Z" />
                                                {/* Second triangle pointing right (Right one) - Shifted right */}
                                                <path d="M 15.5 6.5 C 14.8 6.5 14.5 7 14.5 7.8 L 14.5 20.2 C 14.5 21 14.8 21.5 15.5 21.5 C 16 21.5 16.4 21.3 17 20.8 L 24 15.6 C 24.5 15.2 25 14.7 25 14 C 25 13.3 24.5 12.8 24 12.4 L 17 7.2 C 16.4 6.7 16 6.5 15.5 6.5 Z" />
                                            </svg>
                                        </motion.button>

                                        {/* AirPlay/Output Icon */}
                                        <motion.button
                                            whileTap={{ scale: 0.9 }}
                                            className="p-2 text-white/40 hover:text-white transition-colors"
                                        >
                                            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                                                <rect x="2" y="3" width="20" height="14" rx="2" />
                                                <polygon points="12 17 17 22 7 22 12 17" fill="currentColor" stroke="none" />
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
                                            const displaySubjects = activeSubjects.slice(0, 6);
                                            const hasMore = activeSubjects.length > 6;

                                            return displaySubjects.length > 0 ? (
                                                <>
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

                                                    {hasMore && (
                                                        <motion.div
                                                            variants={{
                                                                hidden: { opacity: 0 },
                                                                visible: { opacity: 1 }
                                                            }}
                                                            className="col-span-2 flex items-center justify-center py-2"
                                                        >
                                                            <span className="text-[10px] text-white/30 font-medium">
                                                                +还有 {activeSubjects.length - 6} 个待复习科目
                                                            </span>
                                                        </motion.div>
                                                    )}
                                                </>
                                            ) : (
                                                <div className="col-span-2 flex flex-col items-center justify-center py-10 text-white/30 gap-3">
                                                    <div className="size-12 rounded-full bg-green-500/10 flex items-center justify-center">
                                                        <span className="material-symbols-outlined text-2xl text-green-400">check_circle</span>
                                                    </div>
                                                    <div className="flex flex-col items-center">
                                                        <span className="text-sm font-bold text-white/60">全部完成！</span>
                                                        <span className="text-[10px]">当前没有待复习的内容</span>
                                                    </div>
                                                </div>
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