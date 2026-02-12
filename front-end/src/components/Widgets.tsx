import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from './Message';
import { useReviewStore } from '../store/useReviewStore';

export const Widgets: React.FC = () => {
    const navigate = useNavigate();
    
    // --- Timer Logic ---
    const FOCUS_TIME = 45 * 60; // 45 minutes in seconds
    const [timeLeft, setTimeLeft] = useState(FOCUS_TIME);
    const [timerActive, setTimerActive] = useState(false);

    // --- Reviews Logic (from Store) ---
    const { reviews, fetchReviews, completeReview, revertReview } = useReviewStore();
    const [todayDate, setTodayDate] = useState('');

    useEffect(() => {
        let interval: NodeJS.Timeout;
        if (timerActive && timeLeft > 0) {
            interval = setInterval(() => {
                setTimeLeft((prev) => prev - 1);
            }, 1000);
        } else if (timeLeft === 0) {
            setTimerActive(false);
            // Optional: Play sound or notification
        }
        return () => clearInterval(interval);
    }, [timerActive, timeLeft]);

    useEffect(() => {
        // Set Date
        const date = new Date();
        setTodayDate(date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }));

        // Fetch Pending Reviews
        fetchReviews();
        
        // Listen for global review updates is handled by store actions now, 
        // but if other components emit event, we might need to sync store.
        // For now, let's assume store is the source of truth.
        // However, if SubjectDetail uses direct API calls, store might be stale.
        // We can add a listener to refresh store.
        const handleReviewUpdate = () => fetchReviews(true);
        window.addEventListener('review:update', handleReviewUpdate);
        
        return () => window.removeEventListener('review:update', handleReviewUpdate);
    }, []);

    const formatTime = (seconds: number) => {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    };

    const resetTimer = () => {
        setTimerActive(false);
        setTimeLeft(FOCUS_TIME);
    };

    const handleToggleReview = async (e: React.MouseEvent, review: any) => {
        e.stopPropagation(); // Prevent navigation
        
        const isCompleted = review.completedLocal; // Local state for UI
        
        // Optimistic Update via Store
        if (isCompleted) {
            revertReview(review.id);
        } else {
            completeReview(review.id);
        }

        try {
            // Actual API call logic should be in store or here?
            // Store has optimistic update but doesn't call API in completeReview/revertReview (based on my implementation).
            // Wait, my useReviewStore implementation only updates local state.
            // I should move API calls to store actions OR call API here.
            // Calling API here is fine for now to match previous logic, but cleaner in store.
            // Let's call API here for now as I didn't add API calls to store actions (just state update).
            // Actually, I should have added API calls to store.
            // But let's keep it simple: Optimistic update in store, then API call.
            
            // Re-import api
            const subjectApis = (await import('../services/subjectApis')).default;

            if (isCompleted) {
                await subjectApis.revertReview(review.id);
                message.success("已撤销复习");
            } else {
                await subjectApis.completeReview(review.id);
                message.success("复习完成");
            }
        } catch (error) {
            console.error(error);
            message.error("操作失败");
            // Revert on error
            if (isCompleted) {
                completeReview(review.id);
            } else {
                revertReview(review.id);
            }
        }
    };

    const handleNavigate = (subjectId: string) => {
        navigate(`/subject/${subjectId}`);
    };

    return (
        <aside className="w-full lg:w-80 xl:w-96 shrink-0 relative">
            <div className="sticky top-32 md:top-36 lg:top-32 lg:w-80 xl:w-96 flex flex-col gap-6 z-10">
                {/* Today's Focus Widget */}
                <div className="glass-panel rounded-3xl p-6 flex flex-col gap-6 h-fit border border-slate-200 dark:border-white/10 shadow-xl transition-all">
                <div className="flex items-center justify-between">
                    <h3 className="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
                        <span className="material-symbols-outlined text-accent-coral">today</span>
                        今日聚焦
                    </h3>
                    <span className="text-xs font-mono text-slate-500 dark:text-text-secondary bg-slate-100 dark:bg-[#0F172A] px-2 py-1 rounded-md transition-colors">{todayDate}</span>
                </div>

                {/* 任务列表 - 展示所有待复习内容，取消内部滚动，使其完全展开 */}
                <div className="flex flex-col gap-3 pr-1">
                    {reviews.length === 0 ? (
                        <div className="text-center py-4 text-slate-400 text-sm">今日无待复习内容</div>
                    ) : (
                        reviews.map((review) => (
                            <div 
                                key={review.id} 
                                onClick={() => handleNavigate(review.subjectId)}
                                className={`flex items-center gap-3 p-3 rounded-2xl border transition-all cursor-pointer group ${
                                review.completedLocal 
                                ? 'bg-slate-100 dark:bg-[#0F172A]/50 border-transparent opacity-60' 
                                : 'bg-slate-50 dark:bg-[#0F172A] border-slate-200 dark:border-surface-light hover:border-primary/50'
                            }`}>
                                <div onClick={(e) => handleToggleReview(e, review)}>
                                    {review.completedLocal ? (
                                        <span className="material-symbols-outlined text-accent-green text-xl">check_circle</span>
                                    ) : (
                                        <div className="relative flex items-center justify-center size-5 rounded-full border-2 border-slate-400 dark:border-text-secondary group-hover:border-primary transition-colors">
                                            <div className="size-2.5 rounded-full bg-primary opacity-0 group-hover:opacity-100 transition-opacity"></div>
                                        </div>
                                    )}
                                </div>
                                <div className="flex flex-col flex-1 min-w-0">
                                    <span className={`text-sm font-medium transition-colors truncate ${review.completedLocal ? 'text-slate-400 dark:text-text-secondary line-through' : 'text-slate-700 dark:text-white group-hover:text-primary'}`}>
                                        {review.title}
                                    </span>
                                    <div className="flex justify-between items-center text-xs text-slate-400 dark:text-text-secondary truncate">
                                        <span>{review.chapterTitle || 'Review'}</span>
                                        {review.learnedAt && (
                                            <span className="opacity-70 ml-2 scale-90 origin-right">
                                                {new Date(review.learnedAt).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                                            </span>
                                        )}
                                    </div>
                                </div>
                            </div>
                        ))
                    )}
                </div>

                {/* Divider */}
                <div className="h-px w-full bg-slate-200 dark:bg-surface-light transition-colors"></div>

                {/* Timer Action */}
                <div className="flex flex-col gap-4">
                    <div className="flex justify-between items-end">
                        <div className="flex flex-col">
                            <span className="text-xs text-slate-500 dark:text-text-secondary font-medium uppercase tracking-wider">番茄钟</span>
                            <span className="text-3xl font-mono font-bold text-slate-900 dark:text-white tracking-widest">{formatTime(timeLeft)}</span>
                        </div>
                        <div className={`text-primary ${timerActive ? 'animate-pulse' : ''}`}>
                            <span className="material-symbols-outlined">timelapse</span>
                        </div>
                    </div>
                    <div className="flex gap-3">
                        <button 
                            onClick={() => setTimerActive(!timerActive)}
                            className={`flex-1 py-4 rounded-2xl font-bold text-sm tracking-wide shadow-glow transition-all flex items-center justify-center gap-2 group ${
                                timerActive ? 'bg-accent-coral text-white hover:bg-red-500' : 'bg-primary text-white hover:bg-blue-600'
                            }`}
                        >
                            <span className="material-symbols-outlined group-hover:scale-110 transition-transform">
                                {timerActive ? 'pause' : 'play_arrow'}
                            </span>
                            {timerActive ? '暂停' : '开始专注'}
                        </button>
                        <button 
                            onClick={resetTimer}
                            className="w-14 rounded-2xl bg-slate-100 dark:bg-white/5 text-slate-500 hover:text-slate-900 dark:text-text-secondary dark:hover:text-white flex items-center justify-center transition-colors"
                            title="Reset Timer"
                        >
                            <span className="material-symbols-outlined">restart_alt</span>
                        </button>
                    </div>
                </div>
            </div>

            {/* Motivation Card */}
            <div className="rounded-3xl p-5 bg-gradient-to-br from-purple-50 to-white dark:from-purple-900/40 dark:to-surface-dark border border-slate-200 dark:border-white/5 flex gap-4 items-center transition-colors">
                <div className="size-10 rounded-full bg-purple-100 dark:bg-white/10 flex items-center justify-center shrink-0">
                    <span className="material-symbols-outlined text-yellow-500 dark:text-yellow-400">lightbulb</span>
                </div>
                <p className="text-sm text-slate-600 dark:text-gray-300 italic">"The only way to do great work is to love what you do."</p>
            </div>
        </div>
        </aside>
    );
};
