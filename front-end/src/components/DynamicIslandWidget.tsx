import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import request from '../utils/request';
import logo from '../assets/logo.png'; // Import logo

// Spring configuration for container
const containerSpring: any = {
    type: "spring",
    stiffness: 280, 
    damping: 30,    
    mass: 1.2,      
};

// Electric Current Animation Component - Internal Right Side
const ElectricCurrent = () => {
    return (
        <div className="relative w-full h-full flex items-center justify-center overflow-hidden">
            {/* SVG Electric Bolt */}
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
    lightStatus?: 'GREEN' | 'YELLOW' | 'RED'; // Keep for compatibility if needed
    reminderTime?: string;
}

const DynamicIslandWidget: React.FC = () => {
    const [isExpanded, setIsExpanded] = useState(false);
    const [isLoggedIn, setIsLoggedIn] = useState(false);
    const [forceCompactMode, setForceCompactMode] = useState(false);
    const [isReminderActive, setIsReminderActive] = useState(false); // New state for time-based reminder
    const startX = React.useRef(0);
    const [data, setData] = useState<WidgetData>({
        totalPendingReviews: 0,
        totalCompletedToday: 0,
        subjects: []
    });

    // Handle gestures
    const handlePointerDown = (e: React.PointerEvent) => {
        startX.current = e.clientX;
    };

    const handlePointerUp = (e: React.PointerEvent) => {
        const diff = e.clientX - startX.current;
        if (Math.abs(diff) < 10) {
            toggleExpand(); // Treat as click
        } else if (diff > 50) {
            // Swipe Right -> Switch to Normal (Compact)
            if (hasPendingReviews && !forceCompactMode) {
                setForceCompactMode(true);
            }
        } else if (diff < -50) {
            // Swipe Left -> Switch to Reminder (Expanded)
            if (hasPendingReviews && forceCompactMode) {
                setForceCompactMode(false);
            }
        }
    };

    // Helper to open login
    const openLogin = () => {
        try {
            const { shell } = (window as any).require('electron');
            // Use HashRouter format
            shell.openExternal('http://localhost:3000/#/login?callback=desktop');
        } catch (e) {
            console.error('Cannot open external link', e);
        }
    };

    // Toggle expansion
    const toggleExpand = () => {
        if (!isLoggedIn) {
            openLogin();
            return;
        }
        setIsExpanded(!isExpanded);
    };

    // Initial data fetch and Token listener
    useEffect(() => {
        // Set initial ignore mouse events
        try {
            const { ipcRenderer } = (window as any).require('electron');
            ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
        } catch (e) {}

        const fetchData = async () => {
            try {
                // Using configured request utility which handles baseURL and tokens
                const res: any = await request({
                    url: '/widget/summary',
                    method: 'get'
                });
                
                if (res.code === 200) {
                    // Force re-login if token is valid but data fetch failed logically (empty data is not failure)
                    setData(res.data);
                } else {
                    // Any non-200 code (401, 403, 500 etc) -> clear token
                    localStorage.removeItem('token');
                    setIsLoggedIn(false);
                }
            } catch (error: any) {
                console.error("Widget fetch error", error);
                // Force logout on ANY error to ensure clean state
                localStorage.removeItem('token');
                setIsLoggedIn(false);
            }
        };

        // Check login status
        const token = localStorage.getItem('token');
        if (token) {
            setIsLoggedIn(true);
            fetchData();
        }

        // Listen for token from Electron
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
        }, 60000); // Update every minute
        
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
            
            // Check if current time is past reminder time
            if (now >= reminderDate) {
                setIsReminderActive(true);
            } else {
                setIsReminderActive(false);
            }
        };

        checkTime();
        const interval = setInterval(checkTime, 10000); // Check every 10s
        return () => clearInterval(interval);
    }, [data.reminderTime]);

    // Dynamic dimensions
    const expandedWidth = 460; 
    const hasPendingReviews = data.totalPendingReviews > 0;
    const showReminder = hasPendingReviews && isReminderActive && !forceCompactMode;
    const collapsedWidth = isLoggedIn ? (showReminder ? 240 : 160) : 180;

    return (
        <div className="flex items-start justify-center w-full h-auto bg-transparent pointer-events-none" style={{ background: 'transparent' }}>
                {/* Re-implementing Ears with clean SVG for pixel-perfect inverted corners */}
                {/* SVG ears moved outside the clipped container by using absolute positioning on parent or adjusting structure. 
                    However, since we need overflow:hidden on the main pill for content clipping, but visible ears, 
                    we should move the ears OUTSIDE the motion.div that has the background color. 
                    
                    Actually, the motion.div IS the pill. If we set overflow:hidden on it, the ears (which are children with negative position) will be clipped.
                    
                    Solution: Wrap the pill motion.div in a parent div that handles the ears, OR put the ears inside but use a technique to keep them visible? 
                    No, overflow:hidden clips everything.
                    
                    Better Solution: 
                    1. Main Pill (motion.div) -> overflow: hidden (clips internal content)
                    2. Ears -> Absolute positioned OUTSIDE the pill, or on a wrapper.
                    
                    Let's wrap the pill in a container that holds the ears and the pill.
                */}
                
                <div className="relative pointer-events-none">
                    {/* Ears attached to the wrapper, positioned relative to the pill */}
                    <div className="absolute top-0 -left-[10px] w-[10px] h-[10px] z-50 pointer-events-none">
                        <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                            <path d="M10 10C10 4.477 5.523 0 0 0H10V10Z" fill="#000000"/>
                        </svg>
                    </div>
                    <div className="absolute top-0 -right-[10px] w-[10px] h-[10px] z-50 pointer-events-none">
                        <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                            <path d="M0 10C0 4.477 4.477 0 10 0H0V10Z" fill="#000000"/>
                        </svg>
                    </div>

                    <motion.div
                        layout
                        onPointerDown={handlePointerDown}
                        onPointerUp={handlePointerUp}
                        initial={false}
                        animate={isExpanded ? "expanded" : "collapsed"}
                        variants={{
                            collapsed: { 
                                width: collapsedWidth, 
                                height: 36, 
                                borderBottomLeftRadius: 18,
                                borderBottomRightRadius: 18,
                                borderTopLeftRadius: 0,
                                borderTopRightRadius: 0
                            },
                            expanded: { 
                                width: expandedWidth, 
                                height: 'auto', 
                                borderBottomLeftRadius: 32,
                                borderBottomRightRadius: 32,
                                borderTopLeftRadius: 0,
                                borderTopRightRadius: 0
                            }
                        }}
                        transition={containerSpring}
                        style={{
                            backgroundColor: '#000000', // Pure black
                            cursor: 'pointer',
                            position: 'relative',
                            zIndex: 9999,
                            overflow: 'hidden' // Clips content during expansion
                        }}
                        className="flex flex-col items-center justify-start text-white select-none drag-region group pointer-events-auto"
                        onLayoutAnimationComplete={() => {
                            // Optional: Could trigger additional sync logic here if needed
                        }}
                        onMouseEnter={() => {
                            try {
                                const { ipcRenderer } = (window as any).require('electron');
                                ipcRenderer.send('set-ignore-mouse-events', false);
                            } catch (e) {}
                        }}
                        onMouseLeave={() => {
                            try {
                                const { ipcRenderer } = (window as any).require('electron');
                                ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
                            } catch (e) {}
                        }}
                    >
                        {/* Content Container */}
                        <motion.div 
                            layout="position" 
                            className="w-full h-full flex flex-col relative overflow-hidden" // Added overflow-hidden
                        >
                            {/* COLLAPSED STATE CONTENT (Absolute Positioned) */}
                            <motion.div
                                initial={false}
                                animate={{ 
                                    opacity: isExpanded ? 0 : 1, 
                                    filter: isExpanded ? 'blur(5px)' : 'blur(0px)',
                                    pointerEvents: isExpanded ? 'none' : 'auto',
                                }}
                                transition={{ duration: 0.2 }}
                                className="absolute inset-0 w-full h-full z-20" // Higher z-index to stay on top when collapsed
                            >
                                {!isLoggedIn ? (
                                    <div className="flex items-center justify-center w-full h-full gap-2 px-3">
                                        <span className="material-symbols-outlined text-sm">login</span>
                                        <span className="text-sm font-bold">点击登录</span>
                                    </div>
                                ) : showReminder ? (
                                    // REMINDER STATE: Expanded width with Logo and Pulse
                                    <>
                                        {/* Left: MemoryFlow Logo - Positioned in the left expansion zone */}
                                        <div className="absolute left-0 top-0 h-full flex items-center justify-center w-[40px] pl-1.5">
                                            <div className="bg-white rounded-[6px] p-[2px] w-6 h-6 flex items-center justify-center shadow-lg">
                                                <img 
                                                    src={logo} 
                                                    alt="MemoryFlow" 
                                                    className="w-full h-full object-contain"
                                                />
                                            </div>
                                        </div>

                                        {/* Right: Electric Current - Positioned in the right expansion zone */}
                                        <div className="absolute right-0 top-0 h-full flex items-center justify-center w-[40px] pr-1.5">
                                            <ElectricCurrent />
                                        </div>
                                    </>
                                ) : (
                                    // INITIAL STATE: Clean, small pill (No Logo, No Pulse)
                                    <div className="w-full h-full"></div>
                                )}
                            </motion.div>

                            {/* EXPANDED STATE CONTENT (Relative Positioned to prop up height) */}
                            <motion.div
                                initial={false}
                                animate={{ 
                                    opacity: isExpanded ? 1 : 0, 
                                    filter: isExpanded ? 'blur(0px)' : 'blur(5px)',
                                    pointerEvents: isExpanded ? 'auto' : 'none',
                                }}
                                transition={{ duration: 0.3 }}
                                className="flex flex-col w-full p-6 z-10" // Lower z-index
                                style={{ width: expandedWidth, minWidth: expandedWidth }} // Explicitly lock width
                            >
                                {/* ... content ... */}
                                {/* Top Row: Overview Cards */}
                                <div className="flex gap-4 mb-6">
                                    {/* Card 1: Pending */}
                                    <div className="flex-1 flex flex-col items-start justify-between h-20 group/card">
                                        <span className="text-xs font-bold text-white/40 uppercase tracking-wider mb-1">待复习</span>
                                        <div className="flex items-baseline gap-1">
                                            <span className="text-5xl font-bold text-white tracking-tighter">{data.totalPendingReviews}</span>
                                            <span className="text-sm text-white/40 font-medium">项</span>
                                        </div>
                                    </div>

                                    {/* Card 2: Today's Progress */}
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

                                {/* List of Subjects (Compact Grid) */}
                                <motion.div 
                                    className="grid grid-cols-2 gap-2 w-full" // Removed overflow and max-height
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
                                        const displaySubjects = activeSubjects.slice(0, 6); // Limit to 6 items
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
                                                        {/* Icon */}
                                                        <div className="size-8 rounded-lg bg-blue-500/20 text-blue-400 flex items-center justify-center shrink-0 group-hover:bg-blue-500/30 transition-colors">
                                                            <span className="material-symbols-outlined text-base">{subject.icon || 'school'}</span>
                                                        </div>

                                                        {/* Text Info */}
                                                        <div className="flex flex-col flex-1 min-w-0">
                                                            <span className="text-xs font-bold text-white truncate">{subject.title}</span>
                                                            <span className="text-[9px] text-white/40 truncate">截止</span>
                                                        </div>

                                                        {/* Count */}
                                                        <div className="flex items-center justify-center bg-red-500/20 px-1.5 py-0.5 rounded text-red-400">
                                                            <span className="text-xs font-bold">{subject.pendingReviewCount}</span>
                                                        </div>
                                                    </motion.div>
                                                ))}
                                                
                                                {/* More Indicator if needed */}
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
                                    </motion.div>
                        </motion.div>
                    </motion.div>
                </div>
        </div>
    );
};

export default DynamicIslandWidget;