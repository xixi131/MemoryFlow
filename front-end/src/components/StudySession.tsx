import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useStudyEngine } from '../hooks/useStudyEngine';

interface StudySessionProps {
    courseId?: number;
    onExit: () => void;
    target?: string;
}

// 学习会话组件：包含卡片学习、复习逻辑
const StudySession: React.FC<StudySessionProps> = ({ courseId, onExit, target }) => {
    const { 
        loading, 
        currentWord, 
        stats, 
        isFinished, 
        handleForgot, 
        handleKnow, 
        nextWord,
        totalInitial 
    } = useStudyEngine(courseId);

    const [isFlipped, setIsFlipped] = useState(false);
    const [audioPlaying, setAudioPlaying] = useState(false);
    const [showDefinition, setShowDefinition] = useState(false);
    const [hasAnswered, setHasAnswered] = useState(false); // Valid for current card
    const [autoAdvanceTimer, setAutoAdvanceTimer] = useState<number | null>(null);
    const [isExiting, setIsExiting] = useState(false);
    
    // 使用 ref 跟踪当前的 Audio 对象，以便在切换时停止播放
    const currentAudioRef = useRef<HTMLAudioElement | null>(null);

    // 播放音频
    const playAudio = useCallback((e?: React.MouseEvent) => {
        e?.stopPropagation();
        if (!currentWord) return;

        // 停止上一个音频
        if (currentAudioRef.current) {
            currentAudioRef.current.pause();
            currentAudioRef.current = null;
        }
        // 停止 TTS
        if ('speechSynthesis' in window) {
            window.speechSynthesis.cancel();
        }

        setAudioPlaying(true);

        // 策略1：优先使用数据库提供的真人发音 URL
        if (currentWord.audioUrl) {
            const audio = new Audio(currentWord.audioUrl);
            currentAudioRef.current = audio; // 保存引用

            audio.onended = () => {
                setAudioPlaying(false);
                currentAudioRef.current = null;
            };
            audio.onerror = () => {
                // 如果 URL 加载失败，回退到 TTS
                console.warn("Audio load failed, falling back to TTS");
                speakWithTTS(currentWord.word);
            };
            audio.play().catch(err => {
                console.error("Audio play failed", err);
                setAudioPlaying(false);
            });
        } 
        // 策略2：如果没有 URL，使用浏览器原生 TTS (Text-to-Speech)
        else {
            speakWithTTS(currentWord.word);
        }
    }, [currentWord]);

    // 浏览器原生 TTS 辅助函数
    const speakWithTTS = (text: string) => {
        if ('speechSynthesis' in window) {
            // 取消当前正在播放的
            window.speechSynthesis.cancel();

            const utterance = new SpeechSynthesisUtterance(text);
            utterance.lang = 'en-US'; // 设置为美式英语
            utterance.rate = 1.0;     // 语速正常
            
            utterance.onend = () => setAudioPlaying(false);
            utterance.onerror = () => setAudioPlaying(false);

            window.speechSynthesis.speak(utterance);
        } else {
            console.error("Browser does not support SpeechSynthesis");
            setAudioPlaying(false);
        }
    };

    // Handle session finish
    useEffect(() => {
        if (isFinished) {
            alert("Session Completed! Great job!");
            onExit();
        }
    }, [isFinished, onExit]);

    // Cleanup timer on unmount or word change
    useEffect(() => {
        return () => {
            if (autoAdvanceTimer) clearTimeout(autoAdvanceTimer);
        };
    }, [autoAdvanceTimer]);

    // Reset local state when word changes
    useEffect(() => {
        // Stop any playing audio when word changes
        if (currentAudioRef.current) {
            currentAudioRef.current.pause();
            currentAudioRef.current = null;
        }
        if ('speechSynthesis' in window) {
            window.speechSynthesis.cancel();
        }
        setAudioPlaying(false);

        setShowDefinition(false);
        setHasAnswered(false);
        if (autoAdvanceTimer) {
            clearTimeout(autoAdvanceTimer);
            setAutoAdvanceTimer(null);
        }
    }, [currentWord]); // Depend on currentWord object reference

    // Auto-play audio
    useEffect(() => {
        if (currentWord && !showDefinition) {
            playAudio();
        }
    }, [currentWord, playAudio, showDefinition]);

    // 封装统一的切词逻辑：动画 -> 数据更新
    const transitionToNext = async (callback: () => Promise<void> | void) => {
        // 1. Start Word/Phonetic exit animation AND hide definition
        setIsExiting(true);
        setShowDefinition(false);
        setHasAnswered(false);
        
        // 2. Wait for animations to complete (300ms) BEFORE changing data
        setTimeout(async () => {
            await callback();
            nextWord();
            
            // 3. Reset exit state to trigger enter animation for new word
            setTimeout(() => setIsExiting(false), 50);
        }, 300);
    };

    // 处理用户反馈
    const onUserResponse = async (isKnow: boolean) => {
        if (!currentWord || hasAnswered) return;

        setHasAnswered(true);
        setShowDefinition(true);

        if (isKnow) {
            // Case 1: Know -> Start Timer -> Master it
            const timer = window.setTimeout(async () => {
                await transitionToNext(async () => {
                    await handleKnow();
                });
            }, 3000);
            setAutoAdvanceTimer(timer);
        } else {
            // Case 2: Forgot -> Show Def -> Requeue immediately
            await handleForgot();
            // User stays on screen to read definition. 
            // They must click "Know" (which will act as Next) or we provide a Next button.
        }
    };

    // Handle "Next" action (for when user is in Forgot state and wants to move on)
    const handleNextAfterForgot = () => {
        if (autoAdvanceTimer) clearTimeout(autoAdvanceTimer);
        transitionToNext(() => {});
    };

    // 键盘快捷键支持
    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if (loading || !currentWord) return;

            if (!hasAnswered) {
                if (e.key === '1') onUserResponse(false); // Forgot
                if (e.key === '2') onUserResponse(true);  // Know
            } else {
                // If already answered (showing definition)
                // Allow '2' or 'Enter' to skip timer or move next
                if (e.key === '2' || e.key === 'Enter') {
                    if (autoAdvanceTimer) {
                        // If timer running (Know state), force finish
                        clearTimeout(autoAdvanceTimer);
                        transitionToNext(async () => {
                            await handleKnow();
                        });
                    } else {
                        // If no timer (Forgot state), just next
                        handleNextAfterForgot();
                    }
                }
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [currentWord, loading, hasAnswered, autoAdvanceTimer, handleKnow, nextWord]);

    if (loading) {
        return <div className="flex items-center justify-center h-screen text-white">Loading session...</div>;
    }

    if (!currentWord) {
        return (
            <div className="flex flex-col items-center justify-center h-screen gap-4">
                <h2 className="text-2xl text-white font-bold">Preparing your session...</h2>
            </div>
        );
    }

    // Progress calculation
    // Total effort = current mastered + current queue size? 
    // Or just fixed based on initial? 
    // Let's use (mastered) / (mastered + new + review) to be dynamic
    const totalCurrent = stats.masteredCount + stats.newCount + stats.reviewCount;
    const progressPercent = totalCurrent > 0 ? (stats.masteredCount / totalCurrent) * 100 : 0;

    return (
        <div className="w-full flex flex-col items-center animate-fade-in min-h-[calc(100vh-140px)] justify-start pt-0">
            <style>{`
                @keyframes progress {
                    from { width: 0%; }
                    to { width: 100%; }
                }
            `}</style>
            {/* 左上角课程标题 */}
            <div className="fixed top-8 left-8 z-40 flex items-center gap-4 animate-fade-in hidden xl:flex">
                <div className="size-12 rounded-2xl bg-gradient-to-br from-rose-500 to-orange-500 flex items-center justify-center shadow-lg shadow-orange-500/20">
                     <span className="material-symbols-outlined text-white text-2xl">menu_book</span>
                </div>
                <div className="flex flex-col">
                    <h2 className="text-xl font-bold text-slate-900 dark:text-white leading-tight">{target || 'Vocabulary'}</h2>
                    <span className="text-xs font-bold text-slate-500 tracking-[0.2em] uppercase">Session</span>
                </div>
            </div>

            {/* 右上角退出按钮 */}
            <button 
                onClick={onExit}
                className="fixed top-8 right-8 z-40 flex items-center gap-2 px-5 py-2.5 rounded-full bg-slate-200/50 dark:bg-white/5 hover:bg-slate-300 dark:hover:bg-white/10 text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-all text-sm font-bold border border-slate-300 dark:border-white/5 backdrop-blur-md"
            >
                Exit Focus <span className="material-symbols-outlined text-sm">close</span>
            </button>

            {/* 进度条区域 (居中) */}
            <div className="w-full max-w-xl mx-auto flex flex-col gap-4 mb-12 mt-4 relative z-30">
                <div className="flex justify-between text-sm font-extrabold text-slate-400 dark:text-slate-300 uppercase tracking-wider">
                    <span>Today's Progress</span>
                    <span className="text-rose-500 text-base">{stats.masteredCount} / {totalCurrent}</span>
                </div>
                <div className="h-3 w-full bg-slate-200 dark:bg-slate-800 rounded-full overflow-hidden border border-slate-300 dark:border-white/5">
                    <div 
                        className="h-full bg-gradient-to-r from-rose-500 to-orange-500 transition-all duration-500 ease-out shadow-[0_0_10px_rgba(244,63,94,0.5)]"
                        style={{ width: `${progressPercent}%` }}
                    />
                </div>
                <div className="flex justify-between px-2 text-xs font-bold text-slate-500 dark:text-slate-400 mt-2">
                    <span className="flex items-center gap-3">
                        <div className="w-2.5 h-2.5 rounded-full shadow-[0_0_8px_rgba(59,130,246,0.8)]" style={{ backgroundColor: '#3B82F6' }}></div>
                        New: {stats.newCount}
                    </span>
                    <span className="flex items-center gap-3">
                        <div className="w-2.5 h-2.5 rounded-full shadow-[0_0_8px_rgba(250,145,60,0.8)]" style={{ backgroundColor: '#FA913C' }}></div>
                        Review: {stats.reviewCount}
                    </span>
                    <span className="flex items-center gap-3">
                        <div className="w-2.5 h-2.5 rounded-full shadow-[0_0_8px_rgba(52,211,153,0.8)]" style={{ backgroundColor: '#34D399' }}></div>
                        Mastered: {stats.masteredCount}
                    </span>
                </div>
            </div>

            {/* 卡片容器 */}
            <div className="relative w-full max-w-3xl aspect-[16/11]" style={{ perspective: '1000px' }}>
                
                <div className="relative w-full h-full transition-transform duration-700 cursor-default">
                    {/* 正面 (Front) */}
                    <div className="absolute inset-0">
                        <div className="relative w-full h-full rounded-[2.5rem] flex flex-col items-center justify-center p-12 shadow-[0_20px_60px_-10px_rgba(0,0,0,0.1)] dark:shadow-[0_20px_60px_-10px_rgba(0,0,0,0.5)] bg-white dark:bg-[#0F172B] overflow-hidden border border-slate-200 dark:border-none ring-1 ring-slate-900/5 dark:ring-white/5">
                            {/* Glow Effects */}
                            <div className="absolute top-0 right-0 w-[400px] h-[400px] bg-slate-100 dark:bg-[#1A192C] blur-[60px] rounded-full translate-x-1/4 -translate-y-1/4 pointer-events-none transition-colors duration-500"></div>
                            <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-slate-50 dark:bg-[#14182B] blur-[60px] rounded-full -translate-x-1/4 translate-y-1/4 pointer-events-none transition-colors duration-500"></div>

                            {/* Timer Progress (Only when Know is clicked) */}
                            {autoAdvanceTimer && (
                                <div className="absolute top-0 left-0 w-full h-1 bg-slate-200 dark:bg-slate-800">
                                    <div className="h-full bg-green-500 animate-[progress_3s_linear_forwards]" style={{ width: '100%' }}></div>
                                </div>
                            )}

                            <div className="relative z-10 flex flex-col items-center w-full">
                                <div className={`transition-all duration-300 transform ${isExiting ? 'opacity-0 -translate-x-8 blur-sm' : 'opacity-100 translate-x-0 blur-0'} flex flex-col items-center`}>
                                    <span className="text-sm font-bold tracking-[0.2em] text-slate-400 dark:text-slate-500 uppercase mb-8">
                                        {currentWord?.pos || 'VOCABULARY'}
                                    </span>
                                    
                                    <h1 className="text-6xl md:text-8xl font-bold text-slate-900 dark:text-white mb-10 text-center tracking-tight font-display drop-shadow-sm dark:drop-shadow-lg">
                                        {currentWord?.word}
                                    </h1>
                                    
                                    <div className="flex items-center gap-4 bg-slate-100 dark:bg-black/40 px-6 py-3 rounded-full hover:bg-slate-200 dark:hover:bg-black/60 transition-colors border border-slate-200 dark:border-white/5 cursor-pointer group" onClick={playAudio}>
                                        <span className="font-mono text-rose-500 text-xl md:text-2xl font-medium tracking-wide">
                                            /{currentWord?.phonetic}/
                                        </span>
                                        <div className={`size-8 rounded-full bg-white dark:bg-white/10 flex items-center justify-center group-hover:scale-110 transition-transform ${audioPlaying ? 'text-primary animate-pulse' : 'text-slate-400'}`}>
                                            <span className="material-symbols-outlined text-[20px]">volume_up</span>
                                        </div>
                                    </div>
                                </div>
                                
                                {/* 浮动显示的中文意思 */}
                                <div className={`mt-12 transition-all duration-200 ease-out transform ${showDefinition ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4 pointer-events-none'}`}>
                                    <div className="flex flex-col gap-4 items-center max-w-2xl px-8">
                                        <p className="text-slate-700 dark:text-slate-200 text-xl md:text-2xl text-center leading-relaxed font-medium bg-slate-100/80 dark:bg-black/20 backdrop-blur-md px-8 py-4 rounded-2xl border border-slate-200 dark:border-white/5 shadow-lg dark:shadow-xl">
                                            {currentWord?.translation}
                                        </p>
                                    </div>
                                </div>
                            </div>
                            
                            {/* Bottom Text Position Adjustment - Hidden if Definition shown */}
                            <div className={`absolute bottom-12 text-slate-400 dark:text-slate-600 text-xs font-bold tracking-[0.2em] animate-pulse z-10 transition-opacity duration-300 ${showDefinition ? 'opacity-0' : 'opacity-100'}`}>
                                TAP BUTTONS BELOW
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* 底部操作栏 */}
            <div className={`mt-12 flex gap-12 transition-all duration-500 opacity-100 translate-y-0 w-full max-w-4xl justify-center`}>
                {/* Forgot Button */}
                <div className={`flex flex-col items-center gap-3 transition-opacity duration-300 ${hasAnswered ? 'opacity-50 pointer-events-none' : 'opacity-100'}`}>
                    <button 
                        onClick={() => onUserResponse(false)}
                        className="group relative flex items-center gap-4 px-12 py-6 rounded-full bg-[#FF7E5F] hover:bg-[#FF6B4A] active:scale-95 text-white shadow-xl shadow-orange-500/20 transition-all duration-300 w-[320px] justify-center border-none"
                    >
                        <span className="material-symbols-outlined text-3xl group-hover:-rotate-12 transition-transform">restart_alt</span>
                        <span className="font-bold text-2xl tracking-wide">Forgot</span>
                    </button>
                    <span className="flex items-center gap-2 text-xs font-medium text-slate-500">
                        <span className="material-symbols-outlined text-[14px]">history</span>
                        Next review in 1m
                    </span>
                </div>

                {/* Know / Next Button */}
                <div className="flex flex-col items-center gap-3">
                    <button 
                        onClick={() => hasAnswered ? handleNextAfterForgot() : onUserResponse(true)}
                        className={`group relative flex items-center gap-4 px-12 py-6 rounded-full transition-all duration-300 w-[320px] justify-center border-none
                            ${hasAnswered && !autoAdvanceTimer 
                                ? 'bg-blue-500 hover:bg-blue-600 shadow-blue-500/20' // "Next" style
                                : 'bg-[#FF3366] hover:bg-[#F42156] shadow-pink-500/20' // "Know" style
                            }`}
                    >
                        {hasAnswered && !autoAdvanceTimer ? (
                            <>
                                <span className="material-symbols-outlined text-3xl">arrow_forward</span>
                                <span className="font-bold text-2xl tracking-wide">Next</span>
                            </>
                        ) : (
                            <>
                                <span className="material-symbols-outlined text-3xl group-hover:scale-110 transition-transform">check_circle</span>
                                <span className="font-bold text-2xl tracking-wide">Know</span>
                            </>
                        )}
                    </button>
                    <span className="flex items-center gap-2 text-xs font-medium text-slate-500">
                        <span className="material-symbols-outlined text-[14px]">calendar_today</span>
                        Next review in 1d
                    </span>
                </div>
            </div>
        </div>
    );
};

export default StudySession;