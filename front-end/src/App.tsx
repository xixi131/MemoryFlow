import React, { useState, useEffect, useRef } from 'react';
import { useLocation, useNavigate, Routes, Route, Navigate } from 'react-router-dom';
import { Navigation } from './components/Navigation';
import { Login } from './pages/Login';
import { Register } from './pages/Register';
import { ForgotPassword } from './pages/ForgotPassword';
import SecurityCheck from './pages/SecurityCheck';
import AdminDashboard from './pages/admin/AdminDashboard';
import { MessageContainer } from './components/Message';
import { Widgets } from './components/Widgets';
import { GOALS, SUBJECTS, TOPICS, GOAL_THEMES } from './constants';
import { AddSubjectModal, EditContentModal, DeleteConfirmModal, AddGoalModal } from './components/Modals';
import EditArticleModal from './components/EditArticleModal';
import StudySession from './components/StudySession';
import LearnedHistory from './components/LearnedHistory';

import { Subject, Goal, User } from './types';
import goalApis from './services/goalApis';
import subjectApis from './services/subjectApis';
import { authService } from './services/authService';
import dashboardApis, { DashboardSummary } from './services/dashboardApis'; // Import
import calendarApis, { CalendarRecordDTO } from './services/calendarApis';
import settingsApis from './services/settingsApis';
import userApis from './api/userApis';
import { message } from './components/Message';
import ReactMarkdown from 'react-markdown';
import HomePage from './pages/HomePage';

import DynamicIslandWidget from './components/DynamicIslandWidget';
import { useGoalStore } from './store/useGoalStore';
import { useReviewStore } from './store/useReviewStore';
import { useUserStore } from './store/useUserStore';
import { useSettingsStore } from './store/useSettingsStore';
import { useSubjectStore } from './store/useSubjectStore';

import { BackgroundGlow } from './components/BackgroundGlow';

// --- Page Components ---

const Dashboard: React.FC<{ setView: (v: string) => void; onOpenAddGoal: () => void; onGoalClick: (id: string) => void }> = ({ setView, onOpenAddGoal, onGoalClick }) => {
    const { summary, fetchSummary } = useReviewStore();
    const { goals, fetchGoals } = useGoalStore();

    useEffect(() => {
        fetchSummary();
        fetchGoals();
    }, []);

    return (
        <>
            <section className="flex flex-col gap-4 px-2">
                <div className="flex flex-col gap-1">
                    <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight text-slate-900 dark:text-white leading-tight">
                        {/* Use greeting if available, else default */}
                        {summary ? (
                            <span dangerouslySetInnerHTML={{ __html: summary.greeting.replace('你好，', '你好，<span class="text-transparent bg-clip-text bg-gradient-to-r from-blue-500 to-primary dark:from-blue-200 dark:to-primary">').replace('同学', '同学</span>') }}></span>
                        ) : (
                            <>你好，<span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-500 to-primary dark:from-blue-200 dark:to-primary">同学</span></>
                        )}
                    </h1>
                    <p className="text-slate-500 dark:text-text-secondary text-lg font-medium">Keep the flow going. 保持专注，未来可期。</p>
                </div>
                <div className="flex flex-wrap gap-4 mt-2">
                    {[
                        { icon: 'priority_high', label: `待复习: ${summary ? summary.pendingReviewCount : '-'}`, color: 'text-accent-coral', bg: 'bg-accent-coral/20' },
                        { icon: 'check_circle', label: `已完成: ${summary ? summary.completedReviewCount : '-'}`, color: 'text-accent-green', bg: 'bg-accent-green/20' },
                        // Removed Focus Time as requested
                    ].map((chip, idx) => (
                        <div key={idx} className="flex items-center gap-3 pl-3 pr-5 py-2 rounded-full bg-white dark:bg-surface-dark border border-slate-200 dark:border-white/5 shadow-sm dark:shadow-inner-light transition-colors">
                            <div className={`size-8 rounded-full ${chip.bg} flex items-center justify-center ${chip.color}`}>
                                <span className="material-symbols-outlined text-[18px]">{chip.icon}</span>
                            </div>
                            <span className="text-slate-700 dark:text-white text-sm font-bold">{chip.label}</span>
                        </div>
                    ))}
                </div>
            </section>

            <section>
                <div className="flex items-center justify-between mb-6 px-2 mt-10">
                    <h2 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight flex items-center gap-2">
                        <span className="material-symbols-outlined text-primary">target</span>
                        我的目标
                    </h2>
                    <button className="text-sm font-bold text-primary hover:text-blue-600 dark:hover:text-white transition-colors">查看全部</button>
                </div>
                <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
                    {goals.map((goal) => (
                        <div key={goal.id} onClick={() => onGoalClick(goal.id)} className="group relative overflow-hidden bg-white dark:bg-surface-dark rounded-3xl p-6 border border-slate-200 dark:border-white/5 shadow-lg hover:shadow-glow transition-all duration-300 hover:-translate-y-1 cursor-pointer">
                            <div className="absolute top-0 right-0 p-6 opacity-5 dark:opacity-10 group-hover:opacity-10 dark:group-hover:opacity-20 transition-opacity">
                                <span className="material-symbols-outlined text-[120px] text-current">{goal.icon}</span>
                            </div>
                            <div className="relative z-10 flex flex-col h-full justify-between gap-6">
                                <div className="flex justify-between items-start">
                                    <div className={`size-14 rounded-2xl flex items-center justify-center overflow-hidden shrink-0 ${goal.iconBgClass} shadow-md`}>
                                       {goal.id === '1' ? (
                                           <div className="font-black text-xs leading-none text-center">BYTE<br/>DANCE</div>
                                       ) : (
                                           <span className="material-symbols-outlined text-3xl">{goal.icon}</span>
                                       )}
                                    </div>
                                    {goal.priority && (
                                        <div className="px-3 py-1 rounded-full bg-primary/10 text-primary text-xs font-bold border border-primary/20">高优先级</div>
                                    )}
                                    {goal.daily && (
                                        <div className="px-3 py-1 rounded-full bg-purple-500/10 text-purple-500 dark:text-purple-400 text-xs font-bold border border-purple-500/20">每日打卡</div>
                                    )}
                                    {(!goal.priority && !goal.daily && goal.labelType === 'longterm') && (
                                        <div className="px-3 py-1 rounded-full bg-emerald-500/10 text-emerald-500 dark:text-emerald-400 text-xs font-bold border border-emerald-500/20">长期计划</div>
                                    )}
                                </div>
                                <div>
                                    <h3 className="text-2xl font-bold mb-1 text-transparent bg-clip-text bg-gradient-to-r from-slate-900 via-slate-900 to-blue-600 dark:from-white dark:via-white dark:to-blue-500">{goal.title}</h3>
                                    <p className="text-slate-500 dark:text-text-secondary text-sm">{goal.subtitle}</p>
                                </div>
                                <div className="space-y-2">
                                    <div className="flex justify-between text-sm font-medium">
                                        <span className="text-slate-700 dark:text-white">总体进度</span>
                                        <span className={goal.colorClass}>{goal.progress}%</span>
                                    </div>
                                    <div className="h-3 w-full bg-slate-100 dark:bg-[#0F172A] rounded-full overflow-hidden border border-slate-200 dark:border-white/5">
                                        <div 
                                            className={`h-full w-[${goal.progress}%] rounded-full relative`}
                                            style={{ width: `${goal.progress}%`, background: goal.progressGradient || (goal.id === '1' ? 'linear-gradient(to right, #3B82F6, #60A5FA)' : 'linear-gradient(to right, #A855F7, #6366F1)') }}
                                        ></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    ))}
                    <button onClick={onOpenAddGoal} className="group flex flex-col items-center justify-center min-h-[220px] rounded-3xl border-2 border-dashed border-slate-300 dark:border-surface-light hover:border-primary dark:hover:border-primary hover:bg-slate-50 dark:hover:bg-surface-dark/50 transition-all duration-300">
                        <div className="size-16 rounded-full bg-slate-100 dark:bg-surface-light group-hover:bg-primary text-slate-400 dark:text-text-secondary group-hover:text-white flex items-center justify-center transition-colors shadow-lg mb-4">
                            <span className="material-symbols-outlined text-3xl">add</span>
                        </div>

                    <span className="text-lg font-bold text-slate-500 dark:text-text-secondary group-hover:text-primary dark:group-hover:text-white transition-colors">新建目标</span>
                    <span className="text-sm text-slate-400 dark:text-text-secondary/60 mt-1">开启新的学习旅程</span>
                </button>
            </div>
        </section>
    </>
    );
};

const GoalDetail: React.FC<{ 
    goalId: string | null,
    setView: (v: string) => void, 
    onAddSubject: () => void,
    onDeleteSubject: (id: string, title: string) => void,
    onDeleteGoal: () => void,
    onSubjectClick: (id: string) => void
}> = ({ goalId, setView, onAddSubject, onDeleteSubject, onDeleteGoal, onSubjectClick }) => {
    const { goalDetails, fetchGoalDetail } = useGoalStore();
    const detail = goalId ? goalDetails[goalId] : null;
    const goal = detail?.goal || null;
    const subjects = detail?.subjects || [];
    
    useEffect(() => {
        if (goalId) {
            fetchGoalDetail(goalId);
        }
    }, [goalId]);

    if (!goalId || !goal) {
        return <div className="flex items-center justify-center h-full min-h-[400px] text-slate-500">Loading...</div>;
    }

    return (
    <div className="flex flex-col gap-10 w-full">
        {/* Breadcrumb */}
        <div className="flex items-center gap-2 text-sm font-medium px-2">
            <button className="text-slate-500 dark:text-text-secondary hover:text-primary dark:hover:text-white transition-colors" onClick={() => setView('dashboard')}>首页</button>
            <span className="text-slate-300 dark:text-text-secondary/40 material-symbols-outlined text-base">chevron_right</span>
            <span className="text-slate-900 dark:text-white">Goals</span>
             <span className="text-slate-300 dark:text-text-secondary/40 material-symbols-outlined text-base">chevron_right</span>
            <span className="text-primary bg-primary/10 px-2 py-0.5 rounded border border-primary/20">{goal.title}</span>
        </div>

        {/* Header */}
        <section className="relative overflow-hidden rounded-[2.5rem] bg-gradient-to-br from-slate-900 to-slate-800 dark:from-surface-dark dark:to-[#151e2e] border border-white/5 p-8 md:p-10 shadow-2xl">
            <div className="absolute -right-20 -top-20 h-64 w-64 rounded-full bg-primary/20 blur-[80px]"></div>
            <div className="relative z-10 flex flex-col md:flex-row justify-between items-start md:items-end gap-6">
                <div className="flex flex-col gap-3">
                    <div className="flex items-center gap-3 mb-1">
                        <span className="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-primary text-white shadow-glow">Active Goal</span>
                        <span className="text-slate-300 dark:text-text-secondary text-sm flex items-center gap-1">
                            <span className="material-symbols-outlined text-base">event</span> Target: {goal.dueDate ? goal.dueDate.substring(0, 10) : 'N/A'}
                        </span>
                    </div>
                    <h1 className="text-4xl md:text-5xl font-black tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-white via-blue-200 to-blue-500 leading-tight">
                        {goal.title}
                    </h1>
                    <p className="text-slate-300 dark:text-text-secondary max-w-md">{goal.subtitle || '暂无描述'}</p>
                </div>
                <div className="flex flex-col items-end gap-2 min-w-[140px]">
                    <div className="text-right">
                        <span className="text-4xl font-bold text-white">{goal.progress}%</span>
                        <span className="text-slate-300 dark:text-text-secondary text-sm block">Completed</span>
                    </div>
                    <div className="w-full h-3 bg-slate-700 dark:bg-slate-800 rounded-full overflow-hidden border border-white/5">
                        <div 
                            className="h-full bg-gradient-to-r from-primary to-primary-glow rounded-full shadow-glow"
                            style={{ width: `${goal.progress}%` }}
                        ></div>
                    </div>
                </div>
            </div>
        </section>

        {/* Subjects */}
        <section className="flex flex-col gap-4">
            <div className="flex items-center justify-between px-2">
                <h2 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
                    <span className="material-symbols-outlined text-primary">library_books</span>
                    科目 Subjects
                </h2>
            </div>
            {subjects.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-10 text-slate-400">
                    <span className="material-symbols-outlined text-4xl mb-2">inbox</span>
                    <p>暂无科目，点击下方按钮添加</p>
                </div>
            ) : subjects.map((subject, index) => {
                const theme = GOAL_THEMES[index % GOAL_THEMES.length];
                return (
                    <div key={subject.id} onClick={() => onSubjectClick(subject.id)} className="group relative flex items-center justify-between p-3 bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-white/5 hover:border-primary/40 hover:bg-slate-50 dark:hover:bg-[#1E293B] hover:shadow-[0_4px_20px_-8px_rgba(55,128,246,0.4)] transition-all duration-300 transform hover:-translate-y-1 cursor-pointer">
                        <div className="flex items-center gap-5 pl-2">
                            <div className={`flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 ${theme.colorClass} shadow-md`}>
                                <span className="material-symbols-outlined text-2xl">{subject.icon || theme.icon}</span>
                            </div>
                            <div className="flex flex-col gap-1">
                                <h3 className="text-lg font-bold text-slate-900 dark:text-white leading-tight">{subject.title}</h3>
                                <div className="flex items-center gap-2">
                                    <span className={`text-xs font-bold ${theme.colorClass} uppercase tracking-wider`}>
                                        {subject.status === 'Due Today' ? 'Review Today' : `${subject.completedTasks || 0} / ${subject.totalTasks || 0} Tasks`}
                                    </span>
                                </div>
                            </div>
                        </div>
                        
                        <div className="flex items-center flex-1 justify-end">
                            {/* Progress Bar */}
                            <div className="hidden sm:flex flex-col gap-1 w-32 md:w-48 mr-32 transition-all duration-300 group-hover:opacity-80">
                                <div className="flex justify-between items-end">
                                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Progress</span>
                                    <span className={`text-xs font-bold ${theme.colorClass}`}>{subject.progress}%</span>
                                </div>
                                <div className="h-2.5 w-full bg-slate-100 dark:bg-black/20 rounded-full overflow-hidden border border-slate-200 dark:border-white/5">
                                    <div 
                                        className="h-full rounded-full relative"
                                        style={{ width: `${subject.progress}%`, background: theme.progressGradient }}
                                    >
                                        <div className="absolute inset-0 bg-white/20 animate-[shimmer_2s_infinite] skew-x-12"></div>
                                    </div>
                                </div>
                            </div>

                            {/* Action Buttons */}
                            <div className="absolute right-4 flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-all duration-300 translate-x-4 group-hover:translate-x-0">
                                <button 
                                    className="h-10 w-10 flex items-center justify-center rounded-full bg-primary/10 text-primary hover:bg-primary hover:text-white transition-all shadow-lg" 
                                    title="Edit"
                                    onClick={(e) => { e.stopPropagation(); }}
                                >
                                    <span className="material-symbols-outlined text-[20px]">edit</span>
                                </button>
                                <button 
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        onDeleteSubject(subject.id, subject.title);
                                    }}
                                    className="h-10 w-10 flex items-center justify-center rounded-full bg-red-500/10 text-red-500 hover:bg-red-500 hover:text-white transition-all shadow-lg"
                                    title="Delete"
                                >
                                    <span className="material-symbols-outlined text-[20px]">delete</span>
                                </button>
                            </div>
                        </div>
                    </div>
                );
            })}
            <div className="flex justify-between items-center w-full">
                <button onClick={onAddSubject} className="group flex-1 mr-4 rounded-full border border-dashed border-primary/40 bg-primary/5 py-4 flex items-center justify-center gap-2 text-primary transition-all duration-300 hover:bg-primary/10 hover:border-primary">
                    <span className="material-symbols-outlined group-hover:rotate-90 transition-transform duration-300">add_circle</span>
                    <span className="font-bold text-lg">新增科目 (Add Subject)</span>
                </button>
                <button onClick={onDeleteGoal} className="group rounded-full border border-dashed border-red-500/40 bg-red-500/5 py-4 px-6 flex items-center justify-center gap-2 text-red-500 transition-all duration-300 hover:bg-red-500/10 hover:border-red-500">
                     <span className="material-symbols-outlined">delete_forever</span>
                     <span className="font-bold text-lg">删除计划</span>
                </button>
            </div>
        </section>
    </div>
    );
};

const SubjectDetail: React.FC<{ subjectId: string | null, setView: (v: string) => void, onEdit: (title: string) => void }> = ({ subjectId, setView, onEdit }) => {
    const { fetchSubjectDetail, subjectDetails } = useSubjectStore();
    const [data, setData] = useState<any[]>([]);
    const [subjectTitle, setSubjectTitle] = useState('');
    const [expanded, setExpanded] = useState<Record<string, boolean>>({});
    const [checked, setChecked] = useState<Record<string, boolean>>({});
    const [activeTabs, setActiveTabs] = useState<Record<string, number>>({});
    const [showAddModal, setShowAddModal] = useState(false);
    const [loading, setLoading] = useState(false);
    const [deleteConfig, setDeleteConfig] = useState<{
        show: boolean;
        type: 'chapter' | 'point' | 'article';
        id: string;
        title: string;
    } | null>(null);
    const [editingArticle, setEditingArticle] = useState<any>(null);

    useEffect(() => {
        if (subjectId) {
            fetchData();
        }

        // Listen for global review updates (e.g. from Widgets)
        const handleReviewUpdate = (event: CustomEvent) => {
            const { pointId, status, nextReviewDate, lastReviewAt } = event.detail;
            
            // Find if this point belongs to current subject
            // We need to traverse data
            setData(prevData => prevData.map(c => {
                const hasPoint = c.children?.some((p: any) => String(p.id) === String(pointId));
                if (hasPoint) {
                    return {
                        ...c,
                        children: c.children.map((p: any) => {
                            if (String(p.id) === String(pointId)) {
                                return {
                                    ...p,
                                    nextReviewDate, // '2099-12-31' or today
                                    lastReviewAt,
                                    reviewCompleted: status === 'completed'
                                };
                            }
                            return p;
                        })
                    };
                }
                return c;
            }));
        };

        window.addEventListener('review:update', handleReviewUpdate as EventListener);
        return () => window.removeEventListener('review:update', handleReviewUpdate as EventListener);
    }, [subjectId]);

    const fetchData = async () => {
        if (!subjectId) return;

        // Check cache first
        const cached = subjectDetails[subjectId];
        // Only show loading if no data
        if (!cached || !cached.data) {
            setLoading(true);
        }

        try {
            // This will use cache if available (controlled by store logic)
            await fetchSubjectDetail(subjectId);
            
            // Get fresh state
            const currentDetail = useSubjectStore.getState().subjectDetails[subjectId];

            if (currentDetail && currentDetail.data) {
                const detail = currentDetail.data;
                setSubjectTitle(detail.title);
                setData(detail.chapters || []);
                
                // Don't auto expand
            } else {
                 // Fallback or error handling if needed, though store usually handles errors
                 // If we are here, fetchSubjectDetail succeeded (didn't throw), but maybe data is null?
            }
        } catch (error) {
            console.error(error);
            message.error('网络错误');
        } finally {
            setLoading(false);
        }
    };

    const handleAddSubject = async (title: string, content: string) => {
        if (!subjectId) return;
        try {
            const res: any = await subjectApis.appendContent(subjectId, content);
            if (res.code === 200) {
                message.success('添加成功');
                setShowAddModal(false);
                fetchData();
            } else {
                message.warning(res.message || '添加失败');
            }
        } catch (error) {
            console.error(error);
            message.error('网络错误');
        }
    };

    const toggleExpand = async (id: string, isChapter: boolean = false) => {
        // Toggle UI immediately
        setExpanded(prev => ({...prev, [id]: !prev[id]}));

        // If expanding a chapter, check if data is loaded
        if (isChapter && !expanded[id]) {
            const chapter = data.find(c => String(c.id) === id);
            // If chapter exists but has no content/children loaded (assuming lazy load returns empty initially)
            // Or we can check a flag. For now, check if contents and children are empty.
            // But a chapter might genuinely be empty. 
            // Better to check if we already fetched.
            // Let's add a 'loaded' flag to local state or just check if children/contents are empty array 
            // BUT backend now returns empty array for lazy load. 
            // We can assume if it's the first time expanding or if we want to refresh.
            // Let's rely on a 'loaded' property we inject or just fetch every time (simplest for now to ensure data)
            // Or better: check if we have modified the data structure to include 'loaded'.
            // Since we can't easily modify the type on the fly without TS errors, let's just fetch if contents/children are empty.
            
            // Lazy load if contents are null (backend returns null for lazy) or children exist but their contents are null
            const needsLoad = !chapter.contents || (chapter.children && chapter.children.length > 0 && !chapter.children[0].contents);

            if (chapter && needsLoad) {
                try {
                    const res: any = await subjectApis.getChapterDetail(id);
                    if (res.code === 200 && res.data) {
                        // Merge data
                        setData(prevData => prevData.map(c => {
                            if (String(c.id) === id) {
                                return { ...c, ...res.data };
                            }
                            return c;
                        }));
                    }
                } catch (error) {
                    console.error("Failed to load chapter details", error);
                }
            }
        }
    };

    const toggleCheck = async (id: string, isChapter: boolean, e: React.MouseEvent) => {
        e.stopPropagation();
        
        // Find the item to check its current status from 'data'
        // We need to look into chapters and points
        let currentStatus = false;
        
        if (isChapter) {
            const chapter = data.find(c => String(c.id) === id);
            if (!chapter) return;
            
            // Determine current status based on counts if available, otherwise fallback to children
            let allLearned = false;
            if (chapter.totalPoints !== undefined && chapter.completedPoints !== undefined) {
                 allLearned = chapter.totalPoints > 0 && chapter.completedPoints === chapter.totalPoints;
            } else {
                 allLearned = chapter.children?.length > 0 && chapter.children.every((p: any) => p.isLearned);
            }
            
            currentStatus = !!allLearned;

            // Optimistic Update
            const newStatus = !currentStatus;
            
            // Update UI immediately
            setData(prev => prev.map(c => {
                if (String(c.id) === id) {
                    const newCompleted = newStatus ? (c.totalPoints || 0) : 0;
                    return {
                        ...c,
                        completedPoints: newCompleted,
                        children: c.children?.map((p: any) => ({ ...p, isLearned: newStatus }))
                    };
                }
                return c;
            }));

            try {
                if (newStatus) {
                    await subjectApis.markChapterLearned(id);
                } else {
                    await subjectApis.unmarkChapterLearned(id);
                }
            } catch (error) {
                console.error(error);
                message.error('操作失败');
                // Revert on error - Ideally we should fetch data here to be sure
                fetchData();
            }

        } else {
            // Point
            let parentChapterId = '';
            let point: any = null;
            
            for (const c of data) {
                const p = c.children?.find((child: any) => String(child.id) === id);
                if (p) {
                    point = p;
                    parentChapterId = String(c.id);
                    break;
                }
            }
            
            if (!point) return;
            currentStatus = point.isLearned;
            const newStatus = !currentStatus;

            // Optimistic Update
            setData(prev => prev.map(c => {
                if (String(c.id) === parentChapterId) {
                    // Update completedPoints count
                    let newCompleted = c.completedPoints || 0;
                    if (newStatus) newCompleted++;
                    else newCompleted = Math.max(0, newCompleted - 1);

                    return {
                        ...c,
                        completedPoints: newCompleted,
                        children: c.children?.map((p: any) => 
                            String(p.id) === id ? { ...p, isLearned: newStatus } : p
                        )
                    };
                }
                return c;
            }));

            try {
                if (newStatus) {
                    await subjectApis.markPointLearned(id);
                } else {
                    await subjectApis.unmarkPointLearned(id);
                }
            } catch (error) {
                console.error(error);
                message.error('操作失败');
                fetchData();
            }
        }
    };

    // Calculate Progress
    const calculateProgress = () => {
        let total = 0;
        let learned = 0;
        data.forEach(c => {
            if (c.totalPoints !== undefined && c.completedPoints !== undefined) {
                total += c.totalPoints;
                learned += c.completedPoints;
            } else if (c.children) {
                // Fallback if counts not available
                c.children.forEach((p: any) => {
                    total++;
                    if (p.isLearned) learned++;
                });
            }
        });
        return total === 0 ? 0 : Math.round((learned / total) * 100);
    };

    const progress = calculateProgress();

    const handleTabClick = (id: string, index: number, e: React.MouseEvent) => {
        e.stopPropagation();
        setActiveTabs(prev => ({...prev, [id]: index}));
    };

    const performDelete = async () => {
        if (!deleteConfig) return;
        const { type, id } = deleteConfig;
        try {
            let res: any;
            if (type === 'chapter') {
                res = await subjectApis.deleteChapter(id);
            } else if (type === 'point') {
                res = await subjectApis.deletePoint(id);
            } else if (type === 'article') {
                res = await subjectApis.deleteArticle(id);
            }

            if (res && res.code === 200) {
                message.success('删除成功');
                fetchData();
            } else {
                message.error(res?.message || '删除失败');
            }
        } catch (error) {
            console.error(error);
            message.error('网络错误');
        }
        setDeleteConfig(null);
    };

    const handleDeleteChapter = (chapterId: string, title: string, e: React.MouseEvent) => {
        e.stopPropagation();
        setDeleteConfig({
            show: true,
            type: 'chapter',
            id: chapterId,
            title
        });
    };

    const handleDeletePoint = (pointId: string, title: string, e: React.MouseEvent) => {
        e.stopPropagation();
        setDeleteConfig({
            show: true,
            type: 'point',
            id: pointId,
            title
        });
    };

    const handleDeleteArticle = (articleId: string, title: string, e: React.MouseEvent) => {
        e.stopPropagation();
        setDeleteConfig({
            show: true,
            type: 'article',
            id: articleId,
            title
        });
    };

    // Review Logic for Chapter
    const todayStr = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD format (local time)

    const handleChapterReview = async (chapterId: string, pendingPoints: any[], reviewedTodayPoints: any[], e: React.MouseEvent) => {
        e.stopPropagation();

        const isCompleting = pendingPoints.length > 0;
        const targetPoints = isCompleting ? pendingPoints : reviewedTodayPoints;

        // Optimistic Update
        setData(prev => prev.map(c => {
            if (String(c.id) === chapterId) {
                return {
                    ...c,
                    children: c.children?.map((p: any) => {
                        if (targetPoints.find((tp: any) => String(tp.id) === String(p.id))) {
                            return {
                                ...p,
                                // If completing: set nextReviewDate to future (dummy), lastReviewAt to today
                                // If reverting: set nextReviewDate to today, lastReviewAt to null (or keep old?)
                                nextReviewDate: isCompleting ? '2099-12-31' : todayStr,
                                lastReviewAt: isCompleting ? (todayStr + 'T12:00:00') : null
                            };
                        }
                        return p;
                    })
                };
            }
            return c;
        }));

        try {
            // Process sequentially to avoid race conditions or overwhelming backend
            for (const p of targetPoints) {
                if (isCompleting) {
                    await subjectApis.completeReview(String(p.id));
                    // Emit event for Widgets
                    window.dispatchEvent(new CustomEvent('review:update', {
                        detail: { 
                            pointId: p.id, 
                            status: 'completed',
                            nextReviewDate: '2099-12-31',
                            lastReviewAt: todayStr + 'T12:00:00'
                        }
                    }));
                } else {
                    await subjectApis.revertReview(String(p.id));
                    // Emit event for Widgets
                    window.dispatchEvent(new CustomEvent('review:update', {
                        detail: { 
                            pointId: p.id, 
                            status: 'reverted',
                            nextReviewDate: todayStr,
                            lastReviewAt: null
                        }
                    }));
                }
            }
            message.success(isCompleting ? '复习完成' : '已撤销复习');
        } catch (error) {
            console.error(error);
            message.error('操作失败');
            fetchData(); // Revert on error
        }
    };

    const handleSaveArticle = async (id: string, title: string, content: string) => {
        try {
            const res: any = await subjectApis.updateArticle(id, title, content);
            if (res.code === 200) {
                message.success('修改成功');
                fetchData();
            } else {
                message.error(res.message || '修改失败');
            }
        } catch (error) {
            console.error(error);
            message.error('网络错误');
        }
    };

    const handleEditArticle = (article: any, e: React.MouseEvent) => {
        e.stopPropagation();
        if (article) {
            setEditingArticle(article);
        }
    };

    if (loading && data.length === 0) {
        return <div className="flex justify-center items-center h-full py-20 text-slate-500">Loading...</div>;
    }

    return (
        <div className="flex flex-col gap-8 w-full animate-fade-in pb-20">
             {/* Header */}
            <div className="flex flex-col gap-4 px-2">
                 <div className="flex items-center gap-2 text-sm font-medium">
                    <button className="text-slate-500 dark:text-text-secondary hover:text-primary dark:hover:text-white transition-colors" onClick={() => setView('detail')}>Subjects</button>
                    <span className="text-slate-300 dark:text-text-secondary/40 material-symbols-outlined text-base">chevron_right</span>
                    <span className="text-slate-900 dark:text-white">{subjectTitle || '加载中...'}</span>
                </div>
                <div>
                    <div className="flex justify-between items-end mb-2">
                        <h2 className="text-4xl font-extrabold tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-slate-900 via-slate-900 to-blue-600 dark:from-white dark:via-white dark:to-blue-500">{subjectTitle}</h2>
                        <span className="text-2xl font-bold text-primary">{progress}%</span>
                    </div>
                    <div className="h-3 w-full bg-slate-100 dark:bg-white/10 rounded-full overflow-hidden">
                        <div 
                            className="h-full bg-gradient-to-r from-primary to-blue-400 transition-all duration-1000 ease-out"
                            style={{ width: `${progress}%` }}
                        ></div>
                    </div>
                </div>
            </div>

            <div className="flex flex-col gap-6">
                {data.map(chapter => {
                    const isChapterChecked = (chapter.completedPoints === chapter.totalPoints && chapter.totalPoints > 0) || (chapter.children?.length > 0 && chapter.children.every((p: any) => p.isLearned));
                    
                    // Review Status Calculation
                    const pendingPoints = chapter.children?.filter((p: any) => p.isLearned && !p.reviewCompleted && p.nextReviewDate <= todayStr) || [];
                    // Fix: reviewedTodayPoints should NOT exclude pending points logic here, 
                    // but the logic "showReviewCompleted = !showReviewReminder && reviewedTodayPoints.length > 0" handles priority.
                    // However, we need to ensure reviewedTodayPoints includes points that were reviewed today EVEN IF they are not pending.
                    // The issue "even if checked, Reviewed still shows" -> Wait, user says "Reviewed still shows" -> that's correct behavior for "Reviewed" state.
                    // User says: "即使已经勾选了复习，在今天这个复习时间中Reviewed还是一直显示着"
                    // If user means "It should disappear", that's one thing.
                    // If user means "It shows 'Reviewed' correctly", that's good.
                    // User phrasing: "Review和Reviewed... 即使已经勾选了复习... Reviewed还是一直显示着"
                    // It seems the user implies this is a PROBLEM. Maybe they want it to disappear after some time?
                    // Or maybe they mean "The 'Review' (red) badge still shows"? 
                    // No, "Reviewed还是一直显示着" means the GREY badge.
                    // Usually "Reviewed" badge is good feedback. 
                    // UNLESS the user wants it to vanish? 
                    // Let's re-read: "Review提示要和今日聚焦的状态同步... 即使已经勾选了复习... Reviewed还是一直显示着"
                    // Maybe the user thinks "Reviewed" badge is clutter?
                    // But if it disappears, how do they UNDO it?
                    // "点击了某个待复习的点... Review的状态就也要变为已经复习... 同样的点击了这个Review也同步要修改这个今日聚焦的状态"
                    // So the GREY badge is the toggle for UNDO. It MUST exist.
                    // Perhaps the user means "The RED badge still shows"? 
                    // "Review 和 Reviewed ... Reviewed 还是一直显示着" -> This sounds like they see the grey one.
                    // If the grey one is always there for ANY learned chapter, that's noise.
                    // It should ONLY show if there was a review task TODAY that was completed.
                    // My logic: `reviewedTodayPoints = ... p.lastReviewAt.startsWith(todayStr)`
                    // This ensures it only shows if reviewed TODAY.
                    // So if I reviewed it yesterday, today it won't show "Reviewed", it will show nothing (until next review date).
                    // This seems correct.
                    // Maybe the user is reporting a bug where it doesn't update?
                    // "改成进入页面就显示，不需要手动展开就可以显示" -> This was the main request.
                    // I will focus on fixing the "Entering page shows badges immediately" issue first (Backend change).
                    
                    const reviewedTodayPoints = chapter.children?.filter((p: any) => p.isLearned && p.lastReviewAt && p.lastReviewAt.startsWith(todayStr)) || [];
                    const showReviewReminder = pendingPoints.length > 0;
                    const showReviewCompleted = !showReviewReminder && reviewedTodayPoints.length > 0;

                    return (
                    <div key={chapter.id} className={`flex flex-col transition-all duration-500 ease-in-out ${expanded[chapter.id] ? 'bg-slate-50/80 dark:bg-slate-900/40 rounded-[2.5rem] border border-slate-200 dark:border-white/5 p-3 pb-6 gap-2' : 'gap-4 bg-transparent border border-transparent p-0'}`}>
                        {/* Level 1: Chapter */}
                        <div 
                            className={`group relative rounded-[2rem] transition-all cursor-pointer overflow-hidden ${expanded[chapter.id] ? 'bg-transparent' : 'bg-white dark:bg-surface-dark border border-slate-200 dark:border-white/5 shadow-sm hover:shadow-md'}`}
                            onClick={() => toggleExpand(String(chapter.id), true)}
                        >
                            <div className="flex items-center justify-between p-6">
                                <div className="flex items-center gap-4">
                                     <div 
                                        className={`size-6 rounded-full border-2 flex items-center justify-center transition-colors ${isChapterChecked ? 'bg-primary border-primary' : 'border-slate-300 dark:border-white/20 hover:border-primary'}`}
                                        onClick={(e) => toggleCheck(String(chapter.id), true, e)}
                                    >
                                        {isChapterChecked && <span className="material-symbols-outlined text-white text-sm font-bold">check</span>}
                                    </div>
                                    <h3 className="text-xl font-bold text-slate-900 dark:text-white">{chapter.title}</h3>
                                    
                                    {/* Review Reminder Badge */}
                                    {(showReviewReminder || showReviewCompleted) && (
                                        <div 
                                            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-bold cursor-pointer transition-all ml-2 z-10 ${
                                                showReviewReminder 
                                                ? 'bg-accent-coral/10 text-accent-coral border border-accent-coral/20 hover:bg-accent-coral hover:text-white shadow-sm hover:shadow-glow-red animate-pulse' 
                                                : 'bg-slate-100 text-slate-400 border border-slate-200 dark:bg-white/5 dark:text-slate-500 dark:border-white/5 grayscale opacity-70'
                                            }`}
                                            onClick={(e) => handleChapterReview(String(chapter.id), pendingPoints, reviewedTodayPoints, e)}
                                            title={showReviewReminder ? "今日待复习 (Click to Complete)" : "今日复习已完成 (Click to Undo)"}
                                        >
                                            <span className="material-symbols-outlined text-[16px]">
                                                {showReviewReminder ? 'notifications_active' : 'check_circle'}
                                            </span>
                                            <span>
                                                {showReviewReminder ? 'Review' : 'Reviewed'}
                                            </span>
                                        </div>
                                    )}
                                </div>
                                <div className="flex items-center gap-4">
                                    {/* Level 1 Delete Button */}
                                    <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                        <button 
                                            onClick={(e) => handleDeleteChapter(String(chapter.id), chapter.title, e)}
                                            className="h-10 w-10 flex items-center justify-center rounded-full bg-red-500/10 text-red-500 hover:bg-red-500 hover:text-white transition-all shadow-lg"
                                            title="Delete Chapter"
                                        >
                                            <span className="material-symbols-outlined text-[20px]">delete</span>
                                        </button>
                                    </div>
                                    <span className={`material-symbols-outlined text-slate-400 transition-transform duration-300 ${expanded[chapter.id] ? 'rotate-180' : ''}`}>expand_more</span>
                                </div>
                            </div>
                        </div>

                        {/* Level 2 Container */}
                        <div className={`grid transition-all duration-500 ease-in-out ${expanded[chapter.id] ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'}`}>
                            <div className="overflow-hidden">
                                <div className="flex flex-col gap-4 px-2 md:px-4 pt-2">
                                    {(!chapter.contents?.length && !chapter.children?.length) && expanded[chapter.id] && (
                                        <div className="text-center py-8 text-slate-400 dark:text-text-secondary italic">
                                            Loading content...
                                        </div>
                                    )}

                                    {/* Level 1 Content (Articles direct under Chapter) */}
                                    {(chapter.contents && chapter.contents.length > 0) && (
                                        <div className="bg-white dark:bg-[#0F172A] rounded-2xl border border-slate-200 dark:border-white/5 shadow-inner flex flex-col mb-4">
                                            {/* Header with Tabs */}
                                            <div className="group flex justify-between items-center border-b border-slate-100 dark:border-white/5 px-6 pt-6 pb-2">
                                                <div className="flex gap-2 overflow-x-auto flex-1 no-scrollbar">
                                                    {chapter.contents.map((article: any, idx: number) => {
                                                        const isActive = (activeTabs[String(chapter.id)] || 0) === idx;
                                                        return (
                                                            <button 
                                                                key={article.id}
                                                                onClick={(e) => handleTabClick(String(chapter.id), idx, e)}
                                                                className={`px-4 py-2 rounded-full text-sm font-bold transition-all whitespace-nowrap flex items-center gap-2 ${
                                                                    isActive 
                                                                    ? 'bg-primary text-white shadow-md' 
                                                                    : 'bg-slate-100 dark:bg-white/5 text-slate-500 dark:text-text-secondary hover:bg-slate-200 dark:hover:bg-white/10'
                                                                }`}
                                                            >
                                                                {article.title}
                                                                {isActive && <span className="material-symbols-outlined text-[16px]">article</span>}
                                                            </button>
                                                        );
                                                    })}
                                                </div>

                                                <div className="flex items-center gap-2 pl-4 opacity-0 group-hover:opacity-100 transition-opacity">
                                                    <button 
                                                        onClick={(e) => handleEditArticle(chapter.contents[activeTabs[String(chapter.id)] || 0], e)}
                                                        className="h-9 w-9 flex items-center justify-center rounded-full bg-primary/10 text-primary hover:bg-primary hover:text-white transition-all shadow-sm"
                                                        title="Edit Article"
                                                    >
                                                        <span className="material-symbols-outlined text-[18px]">edit</span>
                                                    </button>
                                                    <button 
                                                        onClick={(e) => {
                                                            const currentArticle = chapter.contents[activeTabs[String(chapter.id)] || 0];
                                                            if (currentArticle) handleDeleteArticle(String(currentArticle.id), currentArticle.title, e);
                                                        }}
                                                        className="h-9 w-9 flex items-center justify-center rounded-full bg-red-500/10 text-red-500 hover:bg-red-500 hover:text-white transition-all shadow-sm"
                                                        title="Delete Article"
                                                    >
                                                        <span className="material-symbols-outlined text-[18px]">delete</span>
                                                    </button>
                                                </div>
                                            </div>
                                            
                                            <div className="p-6 md:p-8">
                                                {chapter.contents[activeTabs[String(chapter.id)] || 0] && (
                                                    <div className="prose prose-slate dark:prose-invert max-w-none prose-headings:font-bold prose-h1:text-3xl prose-h2:text-2xl prose-h3:text-xl prose-a:text-primary prose-code:text-primary prose-code:bg-primary/10 prose-code:px-1 prose-code:rounded prose-pre:bg-slate-900 prose-pre:dark:bg-[#0B1120] prose-pre:border prose-pre:border-white/10">
                                                        <h1 className="text-3xl font-black mb-6 text-slate-900 dark:text-white">{chapter.contents[activeTabs[String(chapter.id)] || 0].title}</h1>
                                                        <ReactMarkdown>{chapter.contents[activeTabs[String(chapter.id)] || 0].body}</ReactMarkdown>
                                                    </div>
                                                )}
                                            </div>
                                        </div>
                                    )}

                                    {/* Level 2 Points (Children of Chapter) */}
                                    {chapter.children?.map((point: any) => (
                                        <div key={point.id} className="flex flex-col">
                                            <div 
                                                className={`group relative bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-white/5 hover:border-primary/30 transition-all cursor-pointer ${expanded[point.id] ? 'rounded-b-none border-b-0 bg-slate-50 dark:bg-white/5' : ''}`}
                                                onClick={() => toggleExpand(String(point.id))}
                                            >
                                                <div className="flex items-center justify-between p-5">
                                                     <div className="flex items-center gap-4">
                                                        <div 
                                                            className={`size-5 rounded-full border-2 flex items-center justify-center transition-colors ${point.isLearned ? 'bg-accent-green border-accent-green' : 'border-slate-300 dark:border-white/20 hover:border-accent-green'}`}
                                                            onClick={(e) => toggleCheck(String(point.id), false, e)}
                                                        >
                                                            {point.isLearned && <span className="material-symbols-outlined text-white text-xs font-bold">check</span>}
                                                        </div>
                                                        <span className="text-base font-bold text-slate-700 dark:text-slate-200 group-hover:text-primary transition-colors">{point.title}</span>
                                                    </div>
                                                    
                                                    <div className="flex items-center gap-4">
                                                        {/* Level 2 Edit/Delete Buttons */}
                                                        <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                                            <button 
                                                                onClick={(e) => handleDeletePoint(String(point.id), point.title, e)}
                                                                className="h-9 w-9 flex items-center justify-center rounded-full bg-red-500/10 text-red-500 hover:bg-red-500 hover:text-white transition-all shadow-sm"
                                                                title="Delete Point"
                                                            >
                                                                <span className="material-symbols-outlined text-[18px]">delete</span>
                                                            </button>
                                                        </div>
                                                        <span className={`material-symbols-outlined text-slate-400 text-sm transition-transform duration-300 ${expanded[point.id] ? 'rotate-180' : ''}`}>expand_more</span>
                                                    </div>
                                                </div>
                                            </div>

                                            {/* Level 3: Content (Detail with Tabs) */}
                                            <div className={`grid transition-all duration-500 ease-in-out ${expanded[point.id] ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'}`}>
                                                <div className="overflow-hidden">
                                                    {(point.contents && point.contents.length > 0) ? (
                                                        <div className="bg-white dark:bg-[#0F172A] rounded-b-2xl border border-t-0 border-slate-200 dark:border-white/5 shadow-inner flex flex-col">
                                                            {/* Tabs if multiple contents */}
                                                            {point.contents.length > 1 && (
                                                                <div className="flex gap-2 px-6 pt-6 pb-2 overflow-x-auto border-b border-slate-100 dark:border-white/5">
                                                                    {point.contents.map((article: any, idx: number) => {
                                                                        const isActive = (activeTabs[String(point.id)] || 0) === idx;
                                                                        return (
                                                                            <button 
                                                                                key={article.id}
                                                                                onClick={(e) => handleTabClick(String(point.id), idx, e)}
                                                                                className={`px-4 py-2 rounded-full text-sm font-bold transition-all whitespace-nowrap flex items-center gap-2 ${
                                                                                    isActive 
                                                                                    ? 'bg-primary text-white shadow-md' 
                                                                                    : 'bg-slate-100 dark:bg-white/5 text-slate-500 dark:text-text-secondary hover:bg-slate-200 dark:hover:bg-white/10'
                                                                                }`}
                                                                            >
                                                                                {article.title}
                                                                                {isActive && <span className="material-symbols-outlined text-[16px]">article</span>}
                                                                            </button>
                                                                        );
                                                                    })}
                                                                </div>
                                                            )}
                                                            
                                                            <div className="p-6 md:p-8 relative group/article">
                                                                {(() => {
                                                                    const activeIndex = activeTabs[String(point.id)] || 0;
                                                                    const currentArticle = point.contents[activeIndex] || point.contents[0];
                                                                    
                                                                    if (!currentArticle) return null;

                                                                    return (
                                                                        <>
                                                                            <div className="absolute top-4 right-4 flex gap-2 opacity-0 group-hover/article:opacity-100 transition-opacity z-10">
                                                                                <button 
                                                                                    onClick={(e) => handleEditArticle(currentArticle, e)}
                                                                                    className="h-8 w-8 flex items-center justify-center rounded-full bg-primary/10 text-primary hover:bg-primary hover:text-white transition-all"
                                                                                >
                                                                                    <span className="material-symbols-outlined text-[16px]">edit</span>
                                                                                </button>
                                                                                <button 
                                                                                    onClick={(e) => handleDeleteArticle(String(currentArticle.id), currentArticle.title, e)}
                                                                                    className="h-8 w-8 flex items-center justify-center rounded-full bg-red-500/10 text-red-500 hover:bg-red-500 hover:text-white transition-all"
                                                                                >
                                                                                    <span className="material-symbols-outlined text-[16px]">delete</span>
                                                                                </button>
                                                                            </div>

                                                                            <div className="prose prose-slate dark:prose-invert max-w-none prose-headings:font-bold prose-h1:text-3xl prose-h2:text-2xl prose-h3:text-xl prose-a:text-primary prose-code:text-primary prose-code:bg-primary/10 prose-code:px-1 prose-code:rounded prose-pre:bg-slate-900 prose-pre:dark:bg-[#0B1120] prose-pre:border prose-pre:border-white/10">
                                                                                <h1 className="text-3xl font-black mb-6 text-slate-900 dark:text-white">{currentArticle.title}</h1>
                                                                                <ReactMarkdown>{currentArticle.body}</ReactMarkdown>
                                                                            </div>
                                                                        </>
                                                                    );
                                                                })()}
                                                            </div>
                                                        </div>
                                                    ) : (
                                                        <div className="bg-white dark:bg-[#0F172A] rounded-b-2xl border border-t-0 border-slate-200 dark:border-white/5 p-6 text-slate-500 dark:text-slate-400 italic">
                                                            No content available.
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>
                    </div>
                    );
                })}
                
                {/* Add Point/Chapter Button */}
                <button onClick={() => setShowAddModal(true)} className="group rounded-[2rem] border border-dashed border-primary/40 bg-primary/5 py-6 flex items-center justify-center gap-2 text-primary transition-all duration-300 hover:bg-primary/10 hover:border-primary">
                    <span className="material-symbols-outlined group-hover:rotate-90 transition-transform duration-300">add_circle</span>
                    <span className="font-bold text-lg">添加内容 (Add Content)</span>
                </button>
            </div>
            
            {showAddModal && <AddSubjectModal onClose={() => setShowAddModal(false)} onCreate={handleAddSubject} />}
            {deleteConfig && deleteConfig.show && (
                <DeleteConfirmModal 
                    title={deleteConfig.title}
                    onClose={() => setDeleteConfig(null)}
                    onConfirm={performDelete}
                />
            )}
            {editingArticle && (
                <EditArticleModal
                    article={editingArticle}
                    onClose={() => setEditingArticle(null)}
                    onSave={handleSaveArticle}
                />
            )}
        </div>
    );
};

const Settings: React.FC<{ theme: string; setTheme: (t: 'light' | 'dark') => void }> = ({ theme, setTheme }) => {
    const { settings: storeSettings, fetchSettings, updateSettings } = useSettingsStore();
    const [settings, setSettings] = useState<any>({
        dailyNewWordsGoal: 20,
        reminderTime: '20:00',
        emailReminderEnabled: true,
        autoPlayAudio: true,
        soundEffectsEnabled: true,
        theme: 'dark'
    });
    const [showTimePicker, setShowTimePicker] = useState(false);

    useEffect(() => {
        fetchSettings();
    }, []);

    useEffect(() => {
        if (storeSettings) {
            setSettings(storeSettings);
            if (storeSettings.theme && storeSettings.theme !== 'auto' && storeSettings.theme !== theme) {
                setTheme(storeSettings.theme);
            }
        }
    }, [storeSettings]);

    const handleSettingChange = async (key: string, value: any) => {
        const newSettings = { ...settings, [key]: value };
        setSettings(newSettings);
        
        // Special case for theme
        if (key === 'theme') {
            setTheme(value);
        }

        try {
            await updateSettings({ [key]: value });
        } catch (error) {
            console.error("Failed to update setting", key, error);
            message.error("设置更新失败");
        }
    };

    return (
        <div className="flex flex-col gap-10 w-full animate-fade-in pb-10">
            {/* Header */}
            <header className="flex flex-col gap-2 px-2">
                <h2 className="text-4xl font-extrabold tracking-tight text-slate-900 dark:text-white">设置</h2>
                <p className="text-slate-500 dark:text-text-secondary text-lg">个性化您的深度学习环境</p>
            </header>

            {/* Appearance Section */}
            <section className="flex flex-col gap-6">
                <h3 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2 px-2">
                    <span className="material-symbols-outlined text-primary">style</span>
                    外观设置
                </h3>
                <div className="p-6 md:p-8 bg-white dark:bg-surface-dark rounded-[2.5rem] border border-slate-200 dark:border-white/5 shadow-lg transition-colors duration-500">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {/* Dark Theme */}
                        <div onClick={() => handleSettingChange('theme', 'dark')} className="relative group cursor-pointer">
                            {settings.theme === 'dark' && <div className="absolute inset-0 bg-primary/20 blur-xl rounded-3xl opacity-50 transition-opacity"></div>}
                            <div className={`relative flex flex-col h-full bg-[#0F172A] border-2 ${settings.theme === 'dark' ? 'border-primary' : 'border-slate-200 dark:border-white/10'} rounded-3xl p-4 transition-all hover:scale-[1.01] overflow-hidden`}>
                                <div className="flex justify-between items-center px-2 py-4">
                                    <div>
                                        <p className="text-white text-lg font-bold">深邃蓝</p>
                                        <p className="text-slate-400 text-sm">沉浸式夜间学习</p>
                                    </div>
                                    <div className={`size-6 rounded-full ${settings.theme === 'dark' ? 'bg-primary' : 'bg-slate-800'} flex items-center justify-center transition-colors`}>
                                        {settings.theme === 'dark' && <span className="material-symbols-outlined text-white text-[16px] font-bold">check</span>}
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* Light Theme */}
                        <div onClick={() => handleSettingChange('theme', 'light')} className="relative group cursor-pointer">
                            {settings.theme === 'light' && <div className="absolute inset-0 bg-primary/20 blur-xl rounded-3xl opacity-50 transition-opacity"></div>}
                            <div className={`relative flex flex-col h-full bg-slate-50 border-2 ${settings.theme === 'light' ? 'border-primary' : 'border-slate-200 dark:border-white/10'} rounded-3xl p-4 transition-all hover:scale-[1.01] overflow-hidden`}>
                                <div className="flex justify-between items-center px-2 py-4">
                                    <div>
                                        <p className="text-slate-900 text-lg font-bold">明亮白</p>
                                        <p className="text-slate-500 text-sm">高对比度日间模式</p>
                                    </div>
                                    <div className={`size-6 rounded-full ${settings.theme === 'light' ? 'bg-primary' : 'bg-slate-200'} flex items-center justify-center transition-colors`}>
                                        {settings.theme === 'light' && <span className="material-symbols-outlined text-white text-[16px] font-bold">check</span>}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

             {/* Algorithm & Reminders Section */}
            <section className="flex flex-col gap-6">
                <h3 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2 px-2">
                    <span className="material-symbols-outlined text-primary">neurology</span>
                    学习与习惯
                </h3>
                <div className="p-8 bg-white dark:bg-surface-dark rounded-[2.5rem] border border-slate-200 dark:border-white/5 shadow-lg flex flex-col gap-8 transition-colors duration-500">
                     <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                        {/* Daily Goal */}
                        <div className="flex flex-col gap-3">
                            <label className="text-base font-bold text-slate-900 dark:text-white">每日新词目标</label>
                            <div className="relative group">
                                <input 
                                    type="number" 
                                    min="5"
                                    max="200"
                                    value={settings.dailyNewWordsGoal} 
                                    onChange={(e) => handleSettingChange('dailyNewWordsGoal', parseInt(e.target.value))}
                                    className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 text-slate-900 dark:text-white rounded-2xl pl-12 pr-5 py-4 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all font-mono text-lg" 
                                />
                                <span className="material-symbols-outlined absolute left-5 top-1/2 -translate-y-1/2 text-slate-400 dark:text-text-secondary pointer-events-none group-hover:text-primary transition-colors">flag</span>
                            </div>
                            <p className="text-xs text-slate-500 dark:text-text-secondary pl-1">推荐: 20-50词/天</p>
                        </div>

                        {/* Time */}
                        <div className="flex flex-col gap-3">
                            <label className="text-base font-bold text-slate-900 dark:text-white">每日提醒时间</label>
                            <div className="relative group cursor-pointer" onClick={() => setShowTimePicker(true)}>
                                <div className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 text-slate-900 dark:text-white rounded-2xl px-5 py-4 font-mono text-lg flex items-center justify-between hover:border-primary dark:hover:border-primary transition-all">
                                    <span>{settings.reminderTime || "20:00"}</span>
                                    <span className="material-symbols-outlined text-slate-400 dark:text-text-secondary group-hover:text-primary transition-colors">schedule</span>
                                </div>
                            </div>
                            {/* Custom Time Picker Modal */}
                            {showTimePicker && (
                                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                                    <div className="absolute inset-0 bg-black/20 backdrop-blur-sm" onClick={() => setShowTimePicker(false)}></div>
                                    <div className="relative bg-white/90 dark:bg-surface-dark/90 backdrop-blur-xl border border-white/20 dark:border-white/10 rounded-3xl shadow-2xl p-6 w-full max-w-sm animate-fade-in-up">
                                        <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-4 text-center">选择时间</h3>
                                        <div className="flex justify-center gap-4 h-48 mb-6">
                                            {/* Hours */}
                                            <div className="flex-1 overflow-y-auto no-scrollbar snap-y snap-mandatory bg-slate-50/50 dark:bg-black/20 rounded-xl">
                                                {Array.from({length: 24}, (_, i) => i).map(h => {
                                                    const hStr = String(h).padStart(2, '0');
                                                    const isSelected = (settings.reminderTime || "20:00").startsWith(hStr);
                                                    return (
                                                        <div 
                                                            key={h} 
                                                            onClick={() => {
                                                                const m = (settings.reminderTime || "20:00").split(':')[1];
                                                                handleSettingChange('reminderTime', `${hStr}:${m}`);
                                                            }}
                                                            className={`snap-center h-12 flex items-center justify-center text-lg font-mono cursor-pointer transition-colors hover:bg-black/5 dark:hover:bg-white/5 ${isSelected ? 'font-bold text-primary bg-primary/10' : 'text-slate-500 dark:text-slate-400'}`}
                                                        >
                                                            {hStr}
                                                        </div>
                                                    );
                                                })}
                                            </div>
                                            <div className="flex items-center text-slate-400">:</div>
                                            {/* Minutes */}
                                            <div className="flex-1 overflow-y-auto no-scrollbar snap-y snap-mandatory bg-slate-50/50 dark:bg-black/20 rounded-xl">
                                                {Array.from({length: 60}, (_, i) => i).map(m => {
                                                    const mStr = String(m).padStart(2, '0');
                                                    const isSelected = (settings.reminderTime || "20:00").endsWith(mStr);
                                                    return (
                                                        <div 
                                                            key={m} 
                                                            onClick={() => {
                                                                const h = (settings.reminderTime || "20:00").split(':')[0];
                                                                handleSettingChange('reminderTime', `${h}:${mStr}`);
                                                            }}
                                                            className={`snap-center h-12 flex items-center justify-center text-lg font-mono cursor-pointer transition-colors hover:bg-black/5 dark:hover:bg-white/5 ${isSelected ? 'font-bold text-primary bg-primary/10' : 'text-slate-500 dark:text-slate-400'}`}
                                                        >
                                                            {mStr}
                                                        </div>
                                                    );
                                                })}
                                            </div>
                                        </div>
                                        <button 
                                            onClick={() => setShowTimePicker(false)}
                                            className="w-full py-3 rounded-xl bg-primary text-white font-bold hover:bg-blue-600 transition-colors shadow-lg shadow-primary/30"
                                        >
                                            确认
                                        </button>
                                    </div>
                                </div>
                            )}
                        </div>
                     </div>
                     
                     <div className="h-px bg-slate-100 dark:bg-white/5 w-full"></div>

                     {/* Toggles Grid */}
                     <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-6">
                        {[
                            { label: '自动播放发音', id: 'autoPlayAudio', icon: 'volume_up', color: 'text-blue-500', bg: 'bg-blue-500/10' },
                            { label: '应用内音效', id: 'soundEffectsEnabled', icon: 'music_note', color: 'text-pink-500', bg: 'bg-pink-500/10' },
                            { label: '邮件提醒', id: 'emailReminderEnabled', icon: 'mail', color: 'text-orange-500', bg: 'bg-orange-500/10' },
                            { label: '桌面悬浮窗', id: 'floatingWindowEnabled', icon: 'picture_in_picture', color: 'text-teal-500', bg: 'bg-teal-500/10' }
                        ].map(toggle => (
                            <div key={toggle.id} className="flex items-center justify-between p-2 rounded-xl transition-colors">
                                <div className="flex items-center gap-3">
                                    <div className={`size-10 rounded-full ${toggle.bg} flex items-center justify-center ${toggle.color}`}>
                                        <span className="material-symbols-outlined text-[20px]">{toggle.icon}</span>
                                    </div>
                                    <span className="text-base font-medium text-slate-900 dark:text-white">{toggle.label}</span>
                                </div>
                                <label className="flex items-center cursor-pointer relative">
                                    <input 
                                        type="checkbox" 
                                        checked={settings[toggle.id] || false}
                                        onChange={(e) => handleSettingChange(toggle.id, e.target.checked)}
                                        className="sr-only peer" 
                                    />
                                    <div className="w-12 h-7 bg-slate-200 dark:bg-background-dark border border-slate-300 dark:border-white/10 rounded-full peer-checked:bg-primary peer-checked:border-primary transition-all"></div>
                                    <div className="absolute left-1 top-1 bg-white w-5 h-5 rounded-full transition-all peer-checked:translate-x-5 shadow-sm"></div>
                                </label>
                            </div>
                        ))}
                     </div>
                </div>
            </section>

             {/* Data Management Section */}
            <section className="flex flex-col gap-6">
                <h3 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2 px-2">
                     <span className="material-symbols-outlined text-primary">cloud_sync</span>
                    数据管理
                </h3>
                <div className="p-6 bg-white dark:bg-surface-dark rounded-[2.5rem] border border-slate-200 dark:border-white/5 shadow-lg flex flex-wrap items-center justify-between gap-6 transition-colors duration-500">
                    <div className="flex items-center gap-4">
                        <div className="relative flex items-center justify-center size-14 bg-slate-50 dark:bg-background-dark rounded-full border border-slate-200 dark:border-white/10">
                             <span className="material-symbols-outlined text-primary text-2xl">cloud_done</span>
                             <span className="absolute top-0 right-0 flex h-3 w-3">
                                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75"></span>
                                <span className="relative inline-flex rounded-full h-3 w-3 bg-primary"></span>
                            </span>
                        </div>
                        <div>
                             <p className="text-slate-900 dark:text-white font-bold text-lg">云端同步状态</p>
                             <p className="text-primary text-sm font-medium">
                                {settings.lastSyncAt ? (() => {
                                    const diff = new Date().getTime() - new Date(settings.lastSyncAt).getTime();
                                    const mins = Math.floor(diff / 60000);
                                    if (mins < 1) return '刚刚已同步';
                                    if (mins < 60) return `已同步 (${mins}分钟前)`;
                                    const hours = Math.floor(mins / 60);
                                    if (hours < 24) return `已同步 (${hours}小时前)`;
                                    return `上次同步: ${new Date(settings.lastSyncAt).toLocaleDateString()}`;
                                })() : '尚未同步'}
                             </p>
                        </div>
                    </div>
                     <div className="flex gap-3">
                        <button className="px-6 py-3 rounded-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 hover:bg-slate-100 dark:hover:bg-white/5 text-slate-900 dark:text-white text-sm font-bold transition-all flex items-center gap-2">
                             <span className="material-symbols-outlined text-[18px]">download</span>
                             导出数据
                        </button>
                         <button className="px-6 py-3 rounded-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 hover:border-red-500/50 hover:text-red-400 text-slate-500 dark:text-text-secondary text-sm font-bold transition-all flex items-center gap-2">
                             <span className="material-symbols-outlined text-[18px]">delete_sweep</span>
                             清除缓存
                        </button>
                    </div>
                </div>
            </section>
        </div>
    );
};

const Calendar: React.FC = () => {
    const [currentDate, setCurrentDate] = useState(new Date());
    const [records, setRecords] = useState<CalendarRecordDTO[]>([]);
    const [showMonthPicker, setShowMonthPicker] = useState(false);
    const [pickerYear, setPickerYear] = useState(new Date().getFullYear());
    
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth() + 1;

    // Initialize picker year when opening
    useEffect(() => {
        if (showMonthPicker) {
            setPickerYear(year);
        }
    }, [showMonthPicker, year]);

    useEffect(() => {
        const fetchData = async () => {
            try {
                const res: any = await calendarApis.getMonthlyRecords(year, month);
                if (res.code === 200) {
                    setRecords(res.data);
                }
            } catch (error) {
                console.error("Failed to fetch calendar records", error);
            }
        };
        fetchData();
    }, [year, month]);

    // Helpers
    const getDaysInMonth = (y: number, m: number) => new Date(y, m, 0).getDate();
    const getFirstDayOfMonth = (y: number, m: number) => new Date(y, m - 1, 1).getDay(); // 0 = Sunday

    const daysInMonth = getDaysInMonth(year, month);
    const firstDay = getFirstDayOfMonth(year, month);
    
    // Previous month padding
    const prevMonthDays = getDaysInMonth(year, month - 1);
    const prevPadding = Array.from({length: firstDay}, (_, i) => prevMonthDays - firstDay + i + 1);

    // Next month padding
    const totalSlots = firstDay + daysInMonth;
    const nextPadding = Array.from({length: (totalSlots % 7 === 0 ? 0 : 7 - (totalSlots % 7))}, (_, i) => i + 1);

    // Removed old handleMonthChange as it is no longer used

    const goToToday = () => setCurrentDate(new Date());
    const prevMonth = () => setCurrentDate(new Date(year, month - 2, 1));
    const nextMonth = () => setCurrentDate(new Date(year, month, 1));

    const handleMonthSelect = (selectedMonth: number) => {
        setCurrentDate(new Date(pickerYear, selectedMonth - 1, 1));
        setShowMonthPicker(false);
    };

    const totalPoints = records.reduce((acc, curr) => acc + (curr.pointsCompleted || 0), 0);

    return (
        <div className="w-full flex-1 flex flex-col justify-center animate-fade-in">
            {/* Calendar Card */}
            <div className="w-full bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-white/5 shadow-2xl shadow-black/5 dark:shadow-black/40 p-8 md:p-10 relative overflow-hidden backdrop-blur-sm group/calendar transition-colors duration-500">
                {/* Card Inner Glow Top */}
                <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-primary/20 to-transparent opacity-50"></div>
                {/* Header */}
                <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-10">
                    <div className="flex flex-col gap-1">
                        <div className="flex items-baseline gap-3">
                            <h1 className="text-4xl md:text-5xl font-bold text-slate-900 dark:text-white tracking-[-0.03em]">{year}年 <span className="text-slate-400 dark:text-gray-500 font-light">{month}月</span></h1>
                            <span className="px-2.5 py-0.5 rounded-full bg-primary/10 text-primary text-xs font-bold uppercase tracking-wider border border-primary/20">Learning Mode</span>
                        </div>
                        <p className="text-slate-500 dark:text-slate-400 text-sm md:text-base font-normal flex items-center gap-2 mt-1">
                            <span className="material-symbols-outlined text-[18px] text-accent-green">check_circle</span>
                            本月已完成 {totalPoints} 个学习单元，保持良好势头！
                        </p>
                    </div>
                    {/* Controls */}
                    <div className="flex items-center gap-3">
                        <div className="flex bg-slate-100 dark:bg-[#0d1117] rounded-xl p-1 border border-slate-200 dark:border-white/5">
                            <button onClick={prevMonth} className="size-9 flex items-center justify-center rounded-lg hover:bg-white dark:hover:bg-white/10 text-slate-400 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors">
                                <span className="material-symbols-outlined text-[20px]">chevron_left</span>
                            </button>
                            <button onClick={goToToday} className="px-4 text-sm font-bold text-slate-900 dark:text-white hover:bg-white dark:hover:bg-white/5 rounded-lg transition-colors">
                                {year === new Date().getFullYear() && month === new Date().getMonth() + 1 ? '今天' : `${year}年${month}月`}
                            </button>
                            <button onClick={nextMonth} className="size-9 flex items-center justify-center rounded-lg hover:bg-white dark:hover:bg-white/10 text-slate-400 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors">
                                <span className="material-symbols-outlined text-[20px]">chevron_right</span>
                            </button>
                        </div>
                        <div className="relative">
                            <button 
                                onClick={() => setShowMonthPicker(!showMonthPicker)}
                                className={`size-11 flex items-center justify-center rounded-xl border transition-all ${showMonthPicker ? 'bg-primary text-white border-primary shadow-lg shadow-primary/30' : 'bg-slate-100 dark:bg-[#0d1117] border-slate-200 dark:border-white/5 text-slate-400 hover:text-primary hover:border-primary/30'}`}
                            >
                                <span className="material-symbols-outlined">filter_list</span>
                            </button>
                            
                            {/* Custom Month Picker Dropdown */}
                            {showMonthPicker && (
                                <>
                                    {/* Backdrop */}
                                    <div className="fixed inset-0 z-40" onClick={() => setShowMonthPicker(false)}></div>
                                    
                                    {/* Dropdown */}
                                    <div className="absolute right-0 top-full mt-3 z-50 w-72 bg-white dark:bg-[#1e293b] rounded-2xl shadow-2xl border border-slate-200 dark:border-white/10 p-4 animate-fade-in-down origin-top-right backdrop-blur-xl">
                                        {/* Year Selector */}
                                        <div className="flex items-center justify-between mb-4 px-1">
                                            <button 
                                                onClick={() => setPickerYear(y => y - 1)}
                                                className="size-8 flex items-center justify-center rounded-lg hover:bg-slate-100 dark:hover:bg-white/5 text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors"
                                            >
                                                <span className="material-symbols-outlined text-lg">chevron_left</span>
                                            </button>
                                            <span className="font-bold text-lg text-slate-900 dark:text-white">{pickerYear}年</span>
                                            <button 
                                                onClick={() => setPickerYear(y => y + 1)}
                                                className="size-8 flex items-center justify-center rounded-lg hover:bg-slate-100 dark:hover:bg-white/5 text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors"
                                            >
                                                <span className="material-symbols-outlined text-lg">chevron_right</span>
                                            </button>
                                        </div>
                                        
                                        {/* Month Grid */}
                                        <div className="grid grid-cols-4 gap-2">
                                            {Array.from({length: 12}, (_, i) => i + 1).map(m => {
                                                const isSelected = pickerYear === year && m === month;
                                                const isCurrentMonth = pickerYear === new Date().getFullYear() && m === new Date().getMonth() + 1;
                                                
                                                return (
                                                    <button 
                                                        key={m} 
                                                        onClick={() => handleMonthSelect(m)}
                                                        className={`
                                                            aspect-square rounded-xl text-sm font-medium transition-all duration-200 flex items-center justify-center relative
                                                            ${isSelected 
                                                                ? 'bg-primary text-white shadow-lg shadow-primary/30 scale-105' 
                                                                : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-white/5 hover:text-slate-900 dark:hover:text-white'
                                                            }
                                                            ${isCurrentMonth && !isSelected ? 'text-primary dark:text-primary font-bold border border-primary/20' : ''}
                                                        `}
                                                    >
                                                        {m}月
                                                        {isCurrentMonth && !isSelected && (
                                                            <div className="absolute bottom-1.5 size-1 rounded-full bg-primary"></div>
                                                        )}
                                                    </button>
                                                )
                                            })}
                                        </div>
                                    </div>
                                </>
                            )}
                        </div>
                    </div>
                </div>
                {/* Calendar Grid */}
                <div className="w-full">
                    {/* Weekday Headers */}
                    <div className="grid grid-cols-7 mb-4">
                        {['周日', '周一', '周二', '周三', '周四', '周五', '周六'].map(day => (
                            <div key={day} className="text-center text-slate-400 dark:text-slate-500 text-sm font-medium tracking-widest uppercase py-2">{day}</div>
                        ))}
                    </div>
                    {/* Days Grid */}
                    <div className="grid grid-cols-7 gap-3 md:gap-4 auto-rows-fr">
                        {/* Previous Month Padding */}
                        {prevPadding.map(d => (
                             <div key={`prev-${d}`} className="aspect-square p-2 opacity-20 pointer-events-none flex flex-col items-start justify-between rounded-2xl border border-transparent text-slate-900 dark:text-white">
                                <span className="text-lg font-medium">{d}</span>
                            </div>
                        ))}
                        
                        {/* Current Month Days */}
                        {Array.from({length: daysInMonth}, (_, i) => i + 1).map(day => {
                            // Find record
                            const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
                            const record = records.find(r => r.date === dateStr);
                            
                            // Determine status
                            const isToday = record?.isToday || (day === new Date().getDate() && month === new Date().getMonth() + 1 && year === new Date().getFullYear());
                            const status = record?.status || 'none';
                            const isCompleted = status === 'completed';
                            const isMissed = status === 'missed';
                            
                            if (isToday) {
                                return (
                                    <button key={day} className="group aspect-square p-3 relative flex flex-col items-start justify-between rounded-2xl bg-primary text-white shadow-glow border border-primary/50 transition-all hover:scale-[1.05] ring-4 ring-primary/20 z-10">
                                        <span className="text-lg font-bold">{day}</span>
                                        <span className="text-[10px] font-bold uppercase tracking-widest opacity-80 self-end">Today</span>
                                    </button>
                                )
                            }
                            
                            if (isCompleted) {
                                return (
                                     <button key={day} className="group aspect-square p-3 relative flex flex-col items-start justify-between rounded-2xl border border-accent-green/20 bg-accent-green/5 dark:bg-accent-green/5 shadow-[0_0_20px_-5px_rgba(76,175,80,0.4)] transition-all hover:scale-[1.02]">
                                        <span className="text-lg font-bold text-accent-green">{day}</span>
                                        <div className="w-full flex justify-end">
                                            <span className="material-symbols-outlined text-[16px] text-accent-green">check</span>
                                        </div>
                                    </button>
                                )
                            }
                            
                            if (isMissed) {
                                 return (
                                    <button key={day} className="group aspect-square p-3 relative flex flex-col items-start justify-between rounded-2xl border border-slate-200 dark:border-white/5 bg-slate-50 dark:bg-[#232d3f] hover:bg-slate-100 dark:hover:bg-[#2d384e] transition-all hover:scale-[1.02]">
                                        <span className="text-lg font-medium text-slate-400 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-white">{day}</span>
                                        <div className="absolute top-3 right-3 size-2 rounded-full bg-accent-coral shadow-[0_0_8px_rgba(239,68,68,0.6)]"></div>
                                    </button>
                                )
                            }

                            return (
                                <button key={day} className="group aspect-square p-3 relative flex flex-col items-start justify-between rounded-2xl border border-slate-200 dark:border-white/5 bg-slate-50 dark:bg-[#232d3f] hover:bg-slate-100 dark:hover:bg-[#2d384e] transition-all hover:scale-[1.02] hover:shadow-lg hover:border-primary/20 dark:hover:border-white/10">
                                    <span className="text-lg font-medium text-slate-400 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-white">{day}</span>
                                </button>
                            )
                        })}

                        {/* Next Month Padding */}
                        {nextPadding.map(d => (
                            <div key={`next-${d}`} className="aspect-square p-2 opacity-20 pointer-events-none flex flex-col items-start justify-between rounded-2xl border border-transparent text-slate-900 dark:text-white">
                                <span className="text-lg font-medium">{d}</span>
                            </div>
                        ))}
                    </div>
                </div>
                {/* Legend */}
                <div className="mt-8 pt-8 border-t border-slate-200 dark:border-white/5 flex flex-wrap items-center justify-center gap-8">
                    <div className="flex items-center gap-3 bg-slate-100 dark:bg-[#0d1117]/50 px-4 py-2 rounded-full border border-slate-200 dark:border-white/5">
                        <div className="size-2.5 rounded-full bg-accent-green shadow-[0_0_10px_rgba(76,175,80,0.8)]"></div>
                        <span className="text-sm font-medium text-slate-600 dark:text-slate-300">已完成 (Completed)</span>
                    </div>
                    <div className="flex items-center gap-3 bg-slate-100 dark:bg-[#0d1117]/50 px-4 py-2 rounded-full border border-slate-200 dark:border-white/5">
                        <div className="size-2.5 rounded-full bg-primary shadow-[0_0_10px_rgba(58,127,241,0.8)]"></div>
                        <span className="text-sm font-medium text-slate-600 dark:text-slate-300">今日 (Today)</span>
                    </div>
                    <div className="flex items-center gap-3 bg-slate-100 dark:bg-[#0d1117]/50 px-4 py-2 rounded-full border border-slate-200 dark:border-white/5">
                        <div className="size-2.5 rounded-full bg-accent-coral shadow-[0_0_8px_rgba(239,68,68,0.8)]"></div>
                        <span className="text-sm font-medium text-slate-600 dark:text-slate-300">未复习 (Missed)</span>
                    </div>
                </div>
            </div>
        </div>
    );
}



import { vocabularyApis, Course } from './services/vocabulary';

const English: React.FC<{ setView: (v: string) => void }> = ({ setView }) => {
    const navigate = useNavigate();
    const location = useLocation();

    // Parse URL for state: /english/[step]/[target]
    const pathSegments = location.pathname.split('/').filter(Boolean);
    const subRoute = pathSegments[1]; // 'setup' | 'study' | undefined
    const urlTarget = pathSegments[2] ? decodeURIComponent(pathSegments[2]) : '';

    const step = (subRoute === 'setup') ? 'wizard' : (subRoute === 'study' ? 'study' : 'selection');
    const selectedTarget = urlTarget;
    
    const [pace, setPace] = useState(50);
    const [intensity, setIntensity] = useState<'Standard' | 'Cram'>('Standard');
    const [courses, setCourses] = useState<Course[]>([]);

    const getColorClasses = (theme: string) => {
        const map: Record<string, any> = {
            purple: {
                iconBg: 'bg-purple-500/20',
                iconText: 'text-purple-500 dark:text-purple-400',
                hoverIconBg: 'group-hover:bg-purple-500',
                hoverText: 'group-hover:text-purple-500 dark:group-hover:text-purple-400',
                btnHover: 'hover:bg-purple-600 dark:hover:bg-purple-600',
                btnBorder: 'hover:border-purple-600 dark:hover:border-purple-600',
                shadow: 'hover:shadow-[0_0_40px_rgba(168,85,247,0.3)]',
                border: 'hover:border-purple-500/60',
                gradient: 'from-purple-500/5',
                wizardGradient: 'from-purple-400 to-purple-600'
            },
            blue: {
                iconBg: 'bg-blue-500/20',
                iconText: 'text-blue-500 dark:text-blue-400',
                hoverIconBg: 'group-hover:bg-blue-500',
                hoverText: 'group-hover:text-blue-500 dark:group-hover:text-blue-400',
                btnHover: 'hover:bg-blue-600 dark:hover:bg-blue-600',
                btnBorder: 'hover:border-blue-600 dark:hover:border-blue-600',
                shadow: 'hover:shadow-[0_0_40px_rgba(59,130,246,0.3)]',
                border: 'hover:border-blue-500/60',
                gradient: 'from-blue-500/5',
                wizardGradient: 'from-blue-400 to-blue-600'
            },
            rose: {
                iconBg: 'bg-rose-500/20',
                iconText: 'text-rose-500 dark:text-rose-400',
                hoverIconBg: 'group-hover:bg-rose-500',
                hoverText: 'group-hover:text-rose-500 dark:group-hover:text-rose-400',
                btnHover: 'hover:bg-rose-600 dark:hover:bg-rose-600',
                btnBorder: 'hover:border-rose-600 dark:hover:border-rose-600',
                shadow: 'hover:shadow-[0_0_40px_rgba(244,63,94,0.3)]',
                border: 'hover:border-rose-500/60',
                gradient: 'from-rose-500/5',
                wizardGradient: 'from-rose-400 to-rose-600'
            },
            green: {
                iconBg: 'bg-emerald-500/20',
                iconText: 'text-emerald-500 dark:text-emerald-400',
                hoverIconBg: 'group-hover:bg-emerald-500',
                hoverText: 'group-hover:text-emerald-500 dark:group-hover:text-emerald-400',
                btnHover: 'hover:bg-emerald-600 dark:hover:bg-emerald-600',
                btnBorder: 'hover:border-emerald-600 dark:hover:border-emerald-600',
                shadow: 'hover:shadow-[0_0_40px_rgba(16,185,129,0.3)]',
                border: 'hover:border-emerald-500/60',
                gradient: 'from-emerald-500/5',
                wizardGradient: 'from-emerald-400 to-emerald-600'
            },
            teal: {
                iconBg: 'bg-teal-500/20',
                iconText: 'text-teal-500 dark:text-teal-400',
                hoverIconBg: 'group-hover:bg-teal-500',
                hoverText: 'group-hover:text-teal-500 dark:group-hover:text-teal-400',
                btnHover: 'hover:bg-teal-600 dark:hover:bg-teal-600',
                btnBorder: 'hover:border-teal-600 dark:hover:border-teal-600',
                shadow: 'hover:shadow-[0_0_40px_rgba(20,184,166,0.3)]',
                border: 'hover:border-teal-500/60',
                gradient: 'from-teal-500/5',
                wizardGradient: 'from-teal-400 to-teal-600'
            },
            indigo: {
                iconBg: 'bg-indigo-500/20',
                iconText: 'text-indigo-500 dark:text-indigo-400',
                hoverIconBg: 'group-hover:bg-indigo-500',
                hoverText: 'group-hover:text-indigo-500 dark:group-hover:text-indigo-400',
                btnHover: 'hover:bg-indigo-600 dark:hover:bg-indigo-600',
                btnBorder: 'hover:border-indigo-600 dark:hover:border-indigo-600',
                shadow: 'hover:shadow-[0_0_40px_rgba(99,102,241,0.3)]',
                border: 'hover:border-indigo-500/60',
                gradient: 'from-indigo-500/5',
                wizardGradient: 'from-indigo-400 to-indigo-600'
            }
        };
        return map[theme] || map['blue'];
    };

    // Derive active course from fetched courses (User's current course)
    const activeCourseData = courses.find(c => c.isUserCourse);
    const activeCourse = activeCourseData ? activeCourseData.name : null;
    const activeCourseColors = activeCourseData ? getColorClasses(activeCourseData.colorTheme) : null;

    useEffect(() => {
        fetchCourses();
    }, []);

    const fetchCourses = async () => {
        try {
            const res = await vocabularyApis.getAllCourses();
            if (res.code === 200) {
                setCourses(res.data);
                // If we have an active course data, sync pace settings
                const active = res.data.find((c: Course) => c.isUserCourse);
                if (active && active.dailyGoal) {
                    setPace(active.dailyGoal);
                }
            }
        } catch (error) {
            console.error("Failed to fetch courses", error);
        }
    };

    const handleSelectTarget = (target: string) => {
        navigate(`/english/setup/${encodeURIComponent(target)}`);
    };

    const handleGeneratePlan = async () => {
        const course = courses.find(c => c.name === selectedTarget);
        if (course) {
            try {
                await vocabularyApis.selectCourse({
                    courseId: course.id,
                    dailyGoal: pace
                });
                // Refresh courses to update "Active" status immediately
                await fetchCourses();
            } catch (error) {
                console.error("Failed to start course", error);
            }
        }
        navigate(`/english/study/${encodeURIComponent(selectedTarget)}`);
    };

    // Calculate completion date based on pace (approximate logic)
    const calculateCompletionDate = (wordsPerDay: number) => {
        const totalWords = 3500;
        const days = Math.ceil(totalWords / wordsPerDay);
        const date = new Date();
        date.setDate(date.getDate() + days);
        return date.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
    };

    const completionDate = calculateCompletionDate(pace);
    const dailyStudyTime = Math.ceil(pace * 0.5); // 0.5 mins per word approx

    if (step === 'study') {
        const targetName = selectedTarget || activeCourse || 'IELTS Core';
        return <StudySession 
            onExit={() => navigate('/english')} 
            target={targetName} 
            courseId={courses.find(c => c.name === targetName)?.id}
        />;
    }

    if (step === 'wizard') {
        return (
            <div className="w-full flex-1 flex flex-col items-center justify-center min-h-[calc(100vh-100px)] relative animate-fade-in font-display">
                <style>{`
                    input[type=range]::-webkit-slider-thumb {
                        -webkit-appearance: none;
                        height: 32px;
                        width: 32px;
                        border-radius: 50%;
                        background: #3A7FF1;
                        cursor: pointer;
                        margin-top: -12px;
                        box-shadow: 0 0 0 4px #101722, 0 0 15px rgba(58, 127, 241, 0.6);
                        border: 2px solid white;
                    }
                    input[type=range]::-webkit-slider-runnable-track {
                        width: 100%;
                        height: 8px;
                        cursor: pointer;
                        background: #1E293B;
                        border-radius: 999px;
                    }
                `}</style>
                
                {/* Background Ambient Glows */}
                <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[500px] h-[500px] bg-primary/5 rounded-full blur-[100px] pointer-events-none -z-10"></div>
                <div className="absolute bottom-0 right-0 w-[300px] h-[300px] bg-purple-600/5 rounded-full blur-[80px] pointer-events-none -z-10"></div>

                {/* Header for Wizard */}
                <header className="absolute top-0 left-0 w-full flex items-center justify-between px-6 py-4 md:px-0 z-10">
                     <div className="flex items-center gap-3 opacity-0 pointer-events-none"> {/* Hidden spacer for alignment if needed, or just standard flex */}
                     </div>
                    <button 
                        onClick={() => navigate('/english')}
                        className="group flex items-center gap-2 px-4 py-2 rounded-full bg-slate-200/50 dark:bg-white/5 hover:bg-slate-300 dark:hover:bg-white/10 transition-colors border border-slate-300 dark:border-white/5 text-sm font-medium text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
                    >
                        <span>Close Wizard</span>
                        <span className="material-symbols-outlined text-lg">close</span>
                    </button>
                </header>

                <div className="flex flex-col items-center w-full max-w-[600px] px-4 pt-16 pb-10">
                     {/* 1. Context Card (Selected Course Data) */}
                    <div className="glass-panel px-5 py-3 rounded-full flex items-center gap-4 mb-10 shadow-lg animate-modal">
                        <div className={`size-8 rounded-full bg-gradient-to-br ${courses.find(c => c.name === selectedTarget) ? getColorClasses(courses.find(c => c.name === selectedTarget)!.colorTheme).wizardGradient : 'from-blue-400 to-blue-600'} flex items-center justify-center shadow-lg text-white`}>
                            {/* 显示选定课程的图标，默认为 school */}
                            <span className="material-symbols-outlined text-sm font-bold">
                                {courses.find(c => c.name === selectedTarget)?.icon || 'school'}
                            </span>
                        </div>
                        <div className="flex flex-col sm:flex-row sm:items-center gap-0 sm:gap-2">
                            <span className="text-slate-900 dark:text-white font-bold text-sm tracking-wide">{selectedTarget}</span>
                            <span className="hidden sm:block text-slate-400 dark:text-slate-500 text-xs">•</span>
                            {/* 显示选定课程的总词汇量 */}
                            <span className="text-slate-500 dark:text-slate-400 text-xs font-medium">
                                {courses.find(c => c.name === selectedTarget)?.wordCount?.toLocaleString() || '3,500'} Words Total
                            </span>
                        </div>
                    </div>

                    {/* 2. Headline & Value Display */}
                    <div className="text-center mb-8 w-full">
                        <h1 className="text-3xl md:text-4xl font-bold text-slate-900 dark:text-white mb-2 tracking-tight">Set Your Daily Pace</h1>
                        <p className="text-slate-500 dark:text-slate-400 text-sm mb-10">How fast do you want to learn new vocabulary?</p>
                        <div className="relative inline-block">
                            <span className="text-[80px] md:text-[100px] font-extrabold leading-none text-slate-900 dark:text-white tracking-tighter drop-shadow-2xl">{pace}</span>
                            <span className="absolute -right-12 top-6 md:top-8 -rotate-12 bg-primary px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider shadow-glow text-white">Words</span>
                            <div className="text-slate-400 dark:text-slate-500 text-sm font-medium mt-2 uppercase tracking-widest opacity-80">Per Day</div>
                        </div>
                    </div>

                    {/* 3. Slider Section */}
                    <div className="w-full px-4 mb-10">
                        <div className="relative w-full h-12 flex items-center justify-center group">
                            <div className="absolute w-full h-2 bg-slate-200 dark:bg-[#1E293B] rounded-full overflow-hidden">
                                <div className="h-full bg-gradient-to-r from-primary/50 to-primary rounded-full transition-all duration-75 ease-out" style={{ width: `${(pace / 100) * 100}%` }}></div>
                            </div>
                            <input 
                                aria-label="Words per day slider" 
                                className="relative w-full z-10 focus:outline-none bg-transparent appearance-none" 
                                max="100" 
                                min="5" 
                                type="range" 
                                value={pace} 
                                onChange={(e) => {
                                    setPace(Number(e.target.value));
                                    // 自动建议：当用户手动调整较高时，自动提示是否切换到Cram模式
                                    if (Number(e.target.value) >= 70 && intensity !== 'Cram') {
                                        setIntensity('Cram');
                                    } else if (Number(e.target.value) < 50 && intensity === 'Cram') {
                                        setIntensity('Standard');
                                    }
                                }}
                            />
                            <div className="absolute -bottom-8 left-0 text-xs font-medium text-slate-400 dark:text-slate-600">5</div>
                            <div className="absolute -bottom-8 right-0 text-xs font-medium text-slate-400 dark:text-slate-600">100</div>
                        </div>
                    </div>

                    {/* 4. Prediction Card */}
                    <div className="w-full mb-10">
                        <div className="relative overflow-hidden rounded-3xl bg-white dark:bg-surface-dark border border-slate-200 dark:border-slate-700/50 p-6 flex flex-col gap-3 shadow-xl group">
                            <div className="absolute top-0 right-0 w-32 h-32 bg-purple-500/10 rounded-full blur-2xl -mr-10 -mt-10 transition-opacity duration-500 group-hover:opacity-100"></div>
                            <div className="flex items-start gap-4 relative z-10">
                                <div className="p-2 rounded-xl bg-purple-500/10 text-purple-500 mt-1">
                                    <span className="material-symbols-outlined">auto_awesome</span>
                                </div>
                                <div>
                                    <p className="text-slate-500 dark:text-slate-400 text-sm font-medium mb-1">Estimated Completion</p>
                                    <p className="text-lg md:text-xl text-slate-900 dark:text-white font-medium leading-tight">
                                        At this pace, you will finish by <span className="text-purple-500 font-bold drop-shadow-sm">{completionDate}</span>
                                    </p>
                                </div>
                            </div>
                            <div className="w-full h-px bg-slate-100 dark:bg-slate-700/50 my-1"></div>
                            <div className="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400 relative z-10">
                                <span className="material-symbols-outlined text-[18px]">schedule</span>
                                <span>Daily study time: <span className="text-slate-900 dark:text-white font-semibold">approx. {dailyStudyTime} mins</span></span>
                            </div>
                        </div>
                    </div>

                    {/* 5. Bottom Controls */}
                    <div className="w-full flex flex-col gap-6">
                        <div className="flex flex-col items-center gap-3">
                            <span className="text-slate-400 dark:text-slate-500 text-xs font-bold uppercase tracking-widest">Review Intensity</span>
                            <div className="p-1 bg-slate-100 dark:bg-surface-dark rounded-full border border-slate-200 dark:border-slate-700/50 inline-flex w-full max-w-xs relative">
                                <button 
                                    onClick={() => {
                                        setIntensity('Standard');
                                        setPace(20); // Standard default
                                    }}
                                    className={`flex-1 py-2 px-6 rounded-full text-sm font-bold transition-all ${intensity === 'Standard' ? 'bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-md' : 'text-slate-400 hover:text-slate-600 dark:hover:text-white'}`}
                                >
                                    Standard
                                </button>
                                <button 
                                    onClick={() => {
                                        setIntensity('Cram');
                                        setPace(70); // Cram default
                                    }}
                                    className={`flex-1 py-2 px-6 rounded-full text-sm font-bold transition-all ${intensity === 'Cram' ? 'bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-md' : 'text-slate-400 hover:text-slate-600 dark:hover:text-white'}`}
                                >
                                    Cram Mode
                                </button>
                            </div>
                            <p className="text-xs text-slate-400 dark:text-slate-500 max-w-xs text-center mt-2">
                                {intensity === 'Standard' 
                                    ? 'Balanced pace for long-term retention. Best for daily habits.' 
                                    : 'High-intensity learning for upcoming exams. More words, faster pace.'}
                            </p>
                        </div>

                        <button onClick={handleGeneratePlan} className="relative w-full group overflow-hidden rounded-full p-[1px] shadow-glow hover:shadow-[0_0_30px_rgba(192,132,252,0.4)] transition-all duration-300 transform hover:-translate-y-0.5">
                            <span className="absolute inset-0 bg-gradient-to-r from-primary via-purple-500 to-primary opacity-100 animate-gradient-x"></span>
                            <div className="relative bg-gradient-to-r from-primary to-blue-600 group-hover:from-blue-600 group-hover:to-purple-600 transition-all duration-300 rounded-full py-4 px-8 flex items-center justify-center gap-3 h-14">
                                <span className="text-white text-base md:text-lg font-bold tracking-wide">Generate My Plan & Start</span>
                                <span className="material-symbols-outlined text-white group-hover:translate-x-1 transition-transform">arrow_forward</span>
                            </div>
                        </button>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="w-full flex-1 flex flex-col items-center justify-center min-h-[calc(100vh-200px)] relative animate-fade-in">
            {/* Background Glows (Removed - moved to global scope) */}

            <div className="w-full max-w-[1200px] flex flex-col gap-10 z-10">
                {/* Active Course Banner */}
                {activeCourse && activeCourseData && activeCourseColors && (
                    <div className="w-full bg-white/50 dark:bg-white/5 backdrop-blur-xl border border-slate-200 dark:border-white/10 rounded-[2rem] p-6 flex flex-col md:flex-row items-center justify-between gap-6 shadow-xl animate-fade-in-down">
                        <div className="flex items-center gap-6">
                            <div className={`size-16 rounded-2xl bg-gradient-to-br ${activeCourseColors.gradient.replace('/5', '')} flex items-center justify-center shadow-lg text-white`}>
                                <span className="material-symbols-outlined text-3xl">{activeCourseData.icon || 'school'}</span>
                            </div>
                            <div className="flex flex-col">
                                <div className="flex items-center gap-3 mb-1">
                                    <h3 className="text-xl font-bold text-slate-900 dark:text-white">{activeCourse}</h3>
                                    <span className="px-2 py-0.5 rounded-full text-xs font-bold bg-green-500/20 text-green-600 dark:text-green-400 border border-green-500/20">In Progress</span>
                                </div>
                                <div className="flex items-center gap-4 text-sm text-slate-500 dark:text-slate-400">
                                    <span>{activeCourseData.learnedCount || 0}/{activeCourseData.dailyGoal || 20} Words Today</span>
                                    <span>•</span>
                                    <span>{Math.round(activeCourseData.progress || 0)}% Mastery</span>
                                </div>
                            </div>
                        </div>
                        <div className="flex flex-col md:flex-row gap-4 w-full md:w-auto">
                            <button 
                                onClick={() => setView('english-history')}
                                className="px-6 py-3.5 rounded-xl text-slate-700 dark:text-white font-bold transition-all flex items-center justify-center gap-2 group bg-white dark:bg-white/10 hover:bg-slate-50 dark:hover:bg-white/20 border border-slate-200 dark:border-white/10 shadow-sm hover:shadow-md"
                            >
                                <span className="material-symbols-outlined text-primary">history_edu</span>
                                <span>Learned Words</span>
                            </button>
                            <button 
                                onClick={() => navigate(`/english/study/${encodeURIComponent(activeCourse)}`)}
                                className={`px-8 py-3.5 rounded-xl text-white font-bold shadow-glow transition-all flex items-center justify-center gap-2 group bg-gradient-to-r ${activeCourseColors.wizardGradient}`}
                            >
                                <span>Continue Learning</span>
                                <span className="material-symbols-outlined group-hover:translate-x-1 transition-transform">play_arrow</span>
                            </button>
                        </div>
                    </div>
                )}

                {/* Headline */}
                <div className="flex flex-col items-center text-center gap-3 mt-4">
                    <h1 className="text-3xl md:text-4xl lg:text-5xl font-bold tracking-tight text-slate-900 dark:text-white drop-shadow-lg">
                        {activeCourse ? 'Switch Target' : 'Choose Your Target'}
                    </h1>
                    <p className="text-slate-500 dark:text-slate-400 text-base font-light max-w-lg">
                        Select a vocabulary module to begin your daily flow. Unlock your potential with our curated word lists.
                    </p>
                </div>

                {/* Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mt-2">
                    {courses.map((course) => {
                        const colors = getColorClasses(course.colorTheme);
                        return (
                            <div 
                                key={course.id}
                                onClick={() => handleSelectTarget(course.name)} 
                                className={`group relative p-6 rounded-[2rem] overflow-hidden flex flex-col gap-6 transition-all duration-300 ${colors.shadow} ${colors.border} hover:-translate-y-2 cursor-pointer bg-white/50 dark:bg-white/5 backdrop-blur-xl border border-slate-200 dark:border-white/10`}
                            >
                                {/* Hover Gradient */}
                                <div className={`absolute inset-0 bg-gradient-to-b ${colors.gradient} to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-[2rem]`}></div>
                                
                                <div className="relative z-10 flex flex-col h-full">
                                    <div className="flex justify-between items-start mb-2">
                                        <div className={`size-12 rounded-2xl ${colors.iconBg} flex items-center justify-center ${colors.iconText} ${colors.hoverIconBg} group-hover:text-white transition-colors duration-300`}>
                                            <span className="material-symbols-outlined text-2xl">{course.icon || 'school'}</span>
                                        </div>
                                        <span className="px-3 py-1 rounded-full text-xs font-semibold bg-slate-100 dark:bg-white/5 text-slate-500 dark:text-slate-300 border border-slate-200 dark:border-white/10">{course.difficulty === 5 ? 'Expert' : course.difficulty >= 4 ? 'Hard' : course.difficulty >= 3 ? 'Medium' : 'Easy'}</span>
                                    </div>
                                    <div className="mt-auto">
                                        <h3 className={`text-2xl font-bold text-slate-900 dark:text-white mb-1 ${colors.hoverText} transition-colors`}>{course.name}</h3>
                                        <p className="text-slate-500 dark:text-slate-400 text-sm mb-5">{(course as any).totalWords || (course as any).wordCount} Words • {course.description ? course.description.split('-')[0].trim() : 'General'}</p>
                                        <button className={`w-full py-3 rounded-xl bg-slate-100 dark:bg-white/5 ${colors.btnHover} text-slate-900 dark:text-white hover:text-white text-sm font-bold border border-slate-200 dark:border-white/10 ${colors.btnBorder} transition-all duration-300 flex items-center justify-center gap-2`}>
                                            Start Course
                                            <span className="material-symbols-outlined text-sm">arrow_forward</span>
                                        </button>
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                    {/* Old static cards hidden or removed */}
                    <div className="hidden">
                    {/* Card 1: IELTS - partially replaced */}
                    <div onClick={() => handleSelectTarget('IELTS Core Vocabulary')} className="group relative p-6 rounded-[2rem] overflow-hidden flex flex-col gap-6 transition-all duration-300 hover:shadow-[0_0_40px_rgba(37,106,244,0.3)] hover:border-[#256af4]/60 hover:-translate-y-2 cursor-pointer bg-white/50 dark:bg-white/5 backdrop-blur-xl border border-slate-200 dark:border-white/10">
                        {/* Hover Gradient */}
                        <div className="absolute inset-0 bg-gradient-to-b from-[#256af4]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-[2rem]"></div>
                        
                        <div className="relative z-10 flex flex-col h-full">
                            <div className="flex justify-between items-start mb-2">
                                <div className="size-12 rounded-2xl bg-[#256af4]/20 flex items-center justify-center text-[#256af4] group-hover:bg-[#256af4] group-hover:text-white transition-colors duration-300">
                                    <span className="material-symbols-outlined text-2xl">school</span>
                                </div>
                                <span className="px-3 py-1 rounded-full text-xs font-semibold bg-slate-100 dark:bg-white/5 text-slate-500 dark:text-slate-300 border border-slate-200 dark:border-white/10">Academic</span>
                            </div>
                            <div className="mt-auto">
                                <h3 className="text-2xl font-bold text-slate-900 dark:text-white mb-1 group-hover:text-[#256af4] transition-colors">IELTS Core Vocabulary</h3>
                                <p className="text-slate-500 dark:text-slate-400 text-sm mb-5">4,000 Words • Essential</p>
                                <button className="w-full py-3 rounded-xl bg-slate-100 dark:bg-white/5 hover:bg-[#256af4] dark:hover:bg-[#256af4] text-slate-900 dark:text-white hover:text-white text-sm font-bold border border-slate-200 dark:border-white/10 hover:border-[#256af4] transition-all duration-300 flex items-center justify-center gap-2">
                                    Start Course
                                    <span className="material-symbols-outlined text-sm">arrow_forward</span>
                                </button>
                            </div>
                        </div>
                    </div>

                    {/* Card 2: TOEFL */}
                    <div onClick={() => handleSelectTarget('TOEFL iBT Vocabulary')} className="group relative p-6 rounded-[2rem] overflow-hidden flex flex-col gap-6 transition-all duration-300 hover:shadow-[0_0_40px_rgba(37,106,244,0.3)] hover:border-[#256af4]/60 hover:-translate-y-2 cursor-pointer bg-white/50 dark:bg-white/5 backdrop-blur-xl border border-slate-200 dark:border-white/10">
                        <div className="absolute inset-0 bg-gradient-to-b from-[#256af4]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-[2rem]"></div>
                        <div className="relative z-10 flex flex-col h-full">
                            <div className="flex justify-between items-start mb-2">
                                <div className="size-12 rounded-2xl bg-indigo-500/20 flex items-center justify-center text-indigo-500 dark:text-indigo-400 group-hover:bg-indigo-500 group-hover:text-white transition-colors duration-300">
                                    <span className="material-symbols-outlined text-2xl">public</span>
                                </div>
                                <span className="px-3 py-1 rounded-full text-xs font-semibold bg-slate-100 dark:bg-white/5 text-slate-500 dark:text-slate-300 border border-slate-200 dark:border-white/10">Global</span>
                            </div>
                            <div className="mt-auto">
                                <h3 className="text-2xl font-bold text-slate-900 dark:text-white mb-1 group-hover:text-indigo-500 dark:group-hover:text-indigo-400 transition-colors">TOEFL iBT Vocabulary</h3>
                                <p className="text-slate-500 dark:text-slate-400 text-sm mb-5">5,000 Words • Advanced</p>
                                <button className="w-full py-3 rounded-xl bg-slate-100 dark:bg-white/5 hover:bg-indigo-600 dark:hover:bg-indigo-600 text-slate-900 dark:text-white hover:text-white text-sm font-bold border border-slate-200 dark:border-white/10 hover:border-indigo-600 dark:hover:border-indigo-600 transition-all duration-300 flex items-center justify-center gap-2">
                                    Start Course
                                    <span className="material-symbols-outlined text-sm">arrow_forward</span>
                                </button>
                            </div>
                        </div>
                    </div>

                    {/* Card 3: GRE */}
                    <div onClick={() => handleSelectTarget('GRE High-Frequency Vocabulary')} className="group relative p-6 rounded-[2rem] overflow-hidden flex flex-col gap-6 transition-all duration-300 hover:shadow-[0_0_40px_rgba(37,106,244,0.3)] hover:border-[#256af4]/60 hover:-translate-y-2 cursor-pointer bg-white/50 dark:bg-white/5 backdrop-blur-xl border border-slate-200 dark:border-white/10">
                        <div className="absolute inset-0 bg-gradient-to-b from-[#256af4]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-[2rem]"></div>
                        <div className="relative z-10 flex flex-col h-full">
                            <div className="flex justify-between items-start mb-2">
                                <div className="size-12 rounded-2xl bg-rose-500/20 flex items-center justify-center text-rose-500 dark:text-rose-400 group-hover:bg-rose-500 group-hover:text-white transition-colors duration-300">
                                    <span className="material-symbols-outlined text-2xl">menu_book</span>
                                </div>
                                <span className="px-3 py-1 rounded-full text-xs font-semibold bg-slate-100 dark:bg-white/5 text-slate-500 dark:text-slate-300 border border-slate-200 dark:border-white/10">Hard</span>
                            </div>
                            <div className="mt-auto">
                                <h3 className="text-2xl font-bold text-slate-900 dark:text-white mb-1 group-hover:text-rose-500 dark:group-hover:text-rose-400 transition-colors">GRE High-Frequency Vocabulary</h3>
                                <p className="text-slate-500 dark:text-slate-400 text-sm mb-5">High Difficulty • Verbal</p>
                                <button className="w-full py-3 rounded-xl bg-slate-100 dark:bg-white/5 hover:bg-rose-600 dark:hover:bg-rose-600 text-slate-900 dark:text-white hover:text-white text-sm font-bold border border-slate-200 dark:border-white/10 hover:border-rose-600 dark:hover:border-rose-600 transition-all duration-300 flex items-center justify-center gap-2">
                                    Start Course
                                    <span className="material-symbols-outlined text-sm">arrow_forward</span>
                                </button>
                            </div>
                        </div>
                    </div>

                    {/* Card 4: CET-4/6 */}
                    <div onClick={() => handleSelectTarget('CET-4 Vocabulary')} className="group relative p-6 rounded-[2rem] overflow-hidden flex flex-col gap-6 transition-all duration-300 hover:shadow-[0_0_40px_rgba(37,106,244,0.3)] hover:border-[#256af4]/60 hover:-translate-y-2 cursor-pointer bg-white/50 dark:bg-white/5 backdrop-blur-xl border border-slate-200 dark:border-white/10">
                        <div className="absolute inset-0 bg-gradient-to-b from-[#256af4]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-[2rem]"></div>
                        <div className="relative z-10 flex flex-col h-full">
                            <div className="flex justify-between items-start mb-2">
                                <div className="size-12 rounded-2xl bg-emerald-500/20 flex items-center justify-center text-emerald-500 dark:text-emerald-400 group-hover:bg-emerald-500 group-hover:text-white transition-colors duration-300">
                                    <span className="material-symbols-outlined text-2xl">workspace_premium</span>
                                </div>
                                <span className="px-3 py-1 rounded-full text-xs font-semibold bg-slate-100 dark:bg-white/5 text-slate-500 dark:text-slate-300 border border-slate-200 dark:border-white/10">Exam Prep</span>
                            </div>
                            <div className="mt-auto">
                                <h3 className="text-2xl font-bold text-slate-900 dark:text-white mb-1 group-hover:text-emerald-500 dark:group-hover:text-emerald-400 transition-colors">CET-4 Vocabulary</h3>
                                <p className="text-slate-500 dark:text-slate-400 text-sm mb-5">College English Test</p>
                                <button className="w-full py-3 rounded-xl bg-slate-100 dark:bg-white/5 hover:bg-emerald-600 dark:hover:bg-emerald-600 text-slate-900 dark:text-white hover:text-white text-sm font-bold border border-slate-200 dark:border-white/10 hover:border-emerald-600 dark:hover:border-emerald-600 transition-all duration-300 flex items-center justify-center gap-2">
                                    Start Course
                                    <span className="material-symbols-outlined text-sm">arrow_forward</span>
                                </button>
                            </div>
                        </div>
                    </div>
                    </div> {/* Close hidden div */}
                </div>
            </div>
        </div>
    )
}





const Stats: React.FC = () => (
    <div className="flex flex-col gap-6 w-full animate-fade-in">
        <header className="flex flex-col gap-2 px-2">
            <h2 className="text-4xl font-extrabold tracking-tight text-slate-900 dark:text-white">统计分析</h2>
            <p className="text-slate-500 dark:text-text-secondary text-lg">Detailed analysis of your learning progress.</p>
        </header>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div className="bg-white dark:bg-surface-dark p-6 rounded-3xl border border-slate-200 dark:border-white/5 shadow-lg">
                <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-4">Total Study Time</h3>
                <div className="text-4xl font-bold text-primary">124.5h</div>
                <p className="text-sm text-slate-500 mt-2">+12% from last week</p>
            </div>
            <div className="bg-white dark:bg-surface-dark p-6 rounded-3xl border border-slate-200 dark:border-white/5 shadow-lg">
                <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-4">Words Mastered</h3>
                <div className="text-4xl font-bold text-accent-green">1,240</div>
                <p className="text-sm text-slate-500 mt-2">Consistent growth</p>
            </div>
             <div className="bg-white dark:bg-surface-dark p-6 rounded-3xl border border-slate-200 dark:border-white/5 shadow-lg">
                <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-4">Daily Streak</h3>
                <div className="text-4xl font-bold text-accent-coral">15 Days</div>
                <p className="text-sm text-slate-500 mt-2">Keep it up!</p>
            </div>
        </div>
        <div className="bg-white dark:bg-surface-dark p-10 rounded-[2.5rem] border border-slate-200 dark:border-white/5 shadow-lg flex items-center justify-center min-h-[300px]">
             <p className="text-slate-400 dark:text-slate-500 font-medium flex items-center gap-2">
                <span className="material-symbols-outlined">bar_chart</span>
                Detailed charts coming soon...
            </p>
        </div>
    </div>
);

const EditProfileModal: React.FC<{ isOpen: boolean; onClose: () => void; user: User | null; onUpdate: () => void }> = ({ isOpen, onClose, user, onUpdate }) => {
    const [nickname, setNickname] = useState('');
    const [profession, setProfession] = useState('');
    const [age, setAge] = useState('');
    const [email, setEmail] = useState('');
    const [avatarUrl, setAvatarUrl] = useState('');
    
    // Change Email State
    const [isChangingEmail, setIsChangingEmail] = useState(false);
    const [emailCode, setEmailCode] = useState('');
    const [newEmail, setNewEmail] = useState('');
    const [sendingCode, setSendingCode] = useState(false);
    const [countdown, setCountdown] = useState(0);

    useEffect(() => {
        if (user) {
            setNickname(user.nickname || '');
            setProfession(user.profession || '');
            setAge(user.age || '');
            setEmail(user.email || '');
            setAvatarUrl(user.avatarUrl || '');
        }
    }, [user, isOpen]);

    useEffect(() => {
        let timer: NodeJS.Timeout;
        if (countdown > 0) {
            timer = setInterval(() => {
                setCountdown((prev) => prev - 1);
            }, 1000);
        }
        return () => clearInterval(timer);
    }, [countdown]);

    const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        try {
            const res: any = await userApis.uploadAvatar(file);
            if (res.url) {
                 setAvatarUrl(res.url);
                 message.success('头像上传成功');
            } else {
                 message.error('上传失败');
            }
        } catch (error) {
            console.error(error);
            message.error('上传出错');
        }
    };

    const handleSendCode = async () => {
        if (!user?.email) return;
        
        setSendingCode(true);
        try {
            const res = await authService.sendCode(user.email);
            if (res.code === 200) {
                message.success(`验证码已发送至 ${user.email}`);
                setCountdown(60);
            } else {
                message.error(res.message || "发送失败");
            }
        } catch (e) {
            console.error(e);
            message.error("发送失败，请稍后重试");
        } finally {
            setSendingCode(false);
        }
    };

    const handleChangeEmail = async () => {
        if (!emailCode || !newEmail) {
            return message.warning("请填写完整信息");
        }
        try {
            const res = await authService.changeEmail({ code: emailCode, newEmail });
            if (res.code === 200) {
                message.success('邮箱换绑成功');
                setEmail(newEmail);
                setIsChangingEmail(false);
                setEmailCode('');
                setNewEmail('');
                onUpdate();
            } else {
                message.error(res.message || '换绑失败');
            }
        } catch (error) {
            console.error(error);
            message.error('网络错误');
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            const res: any = await authService.updateProfile({ nickname, profession, age, avatarUrl });
            if (res.code === 200) {
                message.success('个人资料已更新');
                window.dispatchEvent(new Event('profile:updated'));
                onUpdate();
                onClose();
            } else {
                message.error(res.message || '更新失败');
            }
        } catch (error) {
            console.error(error);
            message.error('网络错误');
        }
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in">
            <div className="bg-white dark:bg-surface-dark rounded-[2rem] w-full max-w-md p-6 shadow-2xl border border-white/10" onClick={(e) => e.stopPropagation()}>
                <h3 className="text-2xl font-bold text-slate-900 dark:text-white mb-6">编辑资料</h3>
                <form onSubmit={handleSubmit} className="space-y-4">
                    {/* Avatar Upload */}
                    <div className="flex flex-col items-center mb-6">
                        <div className="relative size-24 rounded-full overflow-hidden border-4 border-white dark:border-white/10 shadow-lg mb-4 group cursor-pointer">
                            <img 
                                src={avatarUrl || "https://lh3.googleusercontent.com/aida-public/AB6AXuBTEclYR8F_pkLAtS8wLfPT3QVwCMd5RhwSJjSY28e1PF7nHKZDXgzGQ0FV4peEV087BZVCvaPbPbgxQMbz81RuIXy7-pk7sniURUZrLqeRD0xRcANqR5YixFMj2V0UzBi28Z8ASy0fcXdkZP9g6Ym3SqqcAxkkLmtY15vtYjB-AKPa3msQWCbQs9XGyqG65y_UH1UIj4MYVuguZhyot-H03zomY8toB-6TbkdZRgwZFeQt1ba2iBPCm5j73JqVjYGFr7n-a_QyoOHw"} 
                                alt="Avatar" 
                                className="w-full h-full object-cover"
                            />
                            <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                                <span className="material-symbols-outlined text-white">upload</span>
                            </div>
                            <input 
                                type="file" 
                                accept="image/*" 
                                onChange={handleFileChange} 
                                className="absolute inset-0 opacity-0 cursor-pointer" 
                            />
                        </div>
                        <p className="text-xs text-slate-500">点击头像上传</p>
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-slate-500 mb-1">昵称</label>
                        <input type="text" value={nickname} onChange={e => setNickname(e.target.value)} className="w-full bg-slate-100 dark:bg-white/5 border-none rounded-xl px-4 py-3 text-slate-900 dark:text-white focus:ring-2 focus:ring-primary" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-slate-500 mb-1">职业</label>
                        <input type="text" value={profession} onChange={e => setProfession(e.target.value)} className="w-full bg-slate-100 dark:bg-white/5 border-none rounded-xl px-4 py-3 text-slate-900 dark:text-white focus:ring-2 focus:ring-primary" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-slate-500 mb-1">年龄</label>
                        <input type="text" value={age} onChange={e => setAge(e.target.value)} className="w-full bg-slate-100 dark:bg-white/5 border-none rounded-xl px-4 py-3 text-slate-900 dark:text-white focus:ring-2 focus:ring-primary" />
                    </div>
                    
                    {/* Email Section */}
                    <div>
                        <label className="block text-sm font-medium text-slate-500 mb-1">邮箱</label>
                         {!isChangingEmail ? (
                             <div className="flex gap-2">
                                 <input type="email" value={email} disabled className="w-full bg-slate-100 dark:bg-white/5 border-none rounded-xl px-4 py-3 text-slate-500 dark:text-text-secondary cursor-not-allowed" />
                                 <button type="button" onClick={() => setIsChangingEmail(true)} className="px-4 py-2 rounded-xl bg-primary/10 text-primary font-bold hover:bg-primary/20 transition-colors whitespace-nowrap">
                                     换绑
                                 </button>
                             </div>
                         ) : (
                            <div className="bg-slate-50 dark:bg-white/5 rounded-2xl p-4 border border-slate-100 dark:border-white/5 space-y-3 animate-fade-in">
                                <div className="flex justify-between items-center mb-2">
                                    <span className="text-xs font-bold text-slate-400 uppercase">验证原邮箱</span>
                                    <button type="button" onClick={() => setIsChangingEmail(false)} className="text-xs text-slate-400 hover:text-slate-600 dark:hover:text-white">取消</button>
                                </div>
                                <div className="text-sm text-slate-500 dark:text-text-secondary mb-2">验证码将发送至: {email}</div>
                                <div className="flex gap-2">
                                    <input 
                                        type="text" 
                                        value={emailCode} 
                                        onChange={e => setEmailCode(e.target.value)} 
                                        placeholder="输入验证码"
                                        className="w-full bg-white dark:bg-black/20 border-none rounded-xl px-3 py-2 text-slate-900 dark:text-white text-sm focus:ring-2 focus:ring-primary" 
                                    />
                                    <button 
                                        type="button"
                                        onClick={handleSendCode}
                                        disabled={sendingCode || countdown > 0}
                                        className="px-3 py-2 rounded-xl bg-primary text-white text-xs font-bold disabled:opacity-50 whitespace-nowrap"
                                    >
                                        {countdown > 0 ? `${countdown}s` : '获取验证码'}
                                    </button>
                                </div>
                                <div className="mt-2">
                                    <input 
                                        type="email" 
                                        value={newEmail} 
                                        onChange={e => setNewEmail(e.target.value)} 
                                        placeholder="输入新邮箱地址"
                                        className="w-full bg-white dark:bg-black/20 border-none rounded-xl px-3 py-2 text-slate-900 dark:text-white text-sm focus:ring-2 focus:ring-primary" 
                                    />
                                </div>
                                <button 
                                    type="button" 
                                    onClick={handleChangeEmail}
                                    className="w-full py-2 rounded-xl bg-primary text-white text-sm font-bold shadow-glow hover:bg-blue-600 transition-colors"
                                >
                                    确认换绑
                                </button>
                            </div>
                         )}
                    </div>

                    <div className="flex justify-end gap-3 mt-8">
                        <button type="button" onClick={onClose} className="px-6 py-2 rounded-xl text-slate-500 hover:bg-slate-100 dark:hover:bg-white/5 transition-colors font-bold">取消</button>
                        <button type="submit" className="px-6 py-2 rounded-xl bg-primary text-white font-bold shadow-glow hover:bg-blue-600 transition-colors">保存</button>
                    </div>
                </form>
            </div>
        </div>
    );
};

const Profile: React.FC<{ setView: (v: string) => void }> = ({ setView }) => {
    const { user, fetchUser, logout } = useUserStore();
    const [showEditModal, setShowEditModal] = useState(false);

    useEffect(() => {
        fetchUser();
    }, []);

    if (!user) return <div className="p-8 text-center text-slate-500">Loading...</div>;

    return (
        <div className="flex flex-col gap-8 w-full animate-fade-in">
            <header className="flex items-center gap-4 px-2">
                <button onClick={() => setView('dashboard')} className="size-10 rounded-full bg-slate-100 dark:bg-white/5 flex items-center justify-center text-slate-500 dark:text-text-secondary hover:bg-slate-200 dark:hover:bg-white/10 transition-colors">
                    <span className="material-symbols-outlined">arrow_back</span>
                </button>
                <h2 className="text-4xl font-extrabold tracking-tight text-slate-900 dark:text-white">个人资料</h2>
            </header>
            
            <div className="bg-white dark:bg-surface-dark rounded-[2.5rem] p-8 border border-slate-200 dark:border-white/5 shadow-lg relative overflow-hidden">
                 <div className="absolute top-0 left-0 w-full h-32 bg-gradient-to-r from-primary/20 to-blue-400/20"></div>
                 <div className="relative flex flex-col items-center mt-12">
                    <div className="size-32 rounded-full border-4 border-white dark:border-surface-dark shadow-xl bg-cover bg-center mb-4" style={{ backgroundImage: `url('${user.avatarUrl || "https://lh3.googleusercontent.com/aida-public/AB6AXuBTEclYR8F_pkLAtS8wLfPT3QVwCMd5RhwSJjSY28e1PF7nHKZDXgzGQ0FV4peEV087BZVCvaPbPbgxQMbz81RuIXy7-pk7sniURUZrLqeRD0xRcANqR5YixFMj2V0UzBi28Z8ASy0fcXdkZP9g6Ym3SqqcAxkkLmtY15vtYjB-AKPa3msQWCbQs9XGyqG65y_UH1UIj4MYVuguZhyot-H03zomY8toB-6TbkdZRgwZFeQt1ba2iBPCm5j73JqVjYGFr7n-a_QyoOHw"}')` }}></div>
                    <h3 className="text-2xl font-bold text-slate-900 dark:text-white">{user.nickname || (user as any).username || 'User'}</h3>
                    <p className="text-slate-500 dark:text-text-secondary">{user.profession || 'Student'}</p>
                    <div className="flex gap-4 mt-6">
                        <button onClick={() => setShowEditModal(true)} className="px-6 py-2 rounded-full bg-primary text-white text-sm font-bold shadow-glow hover:bg-blue-600 transition-colors">编辑资料</button>
                        <button className="px-6 py-2 rounded-full bg-slate-100 dark:bg-white/5 text-slate-900 dark:text-white text-sm font-bold border border-slate-200 dark:border-white/10 hover:bg-slate-200 dark:hover:bg-white/10 transition-colors">设置</button>
                    </div>
                 </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                 <div className="bg-white dark:bg-surface-dark rounded-[2rem] p-6 border border-slate-200 dark:border-white/5 shadow-lg">
                    <h4 className="text-lg font-bold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                        <span className="material-symbols-outlined text-primary">person</span>
                        账户信息
                    </h4>
                    <div className="space-y-4">
                        <div className="flex justify-between items-center py-2 border-b border-slate-100 dark:border-white/5">
                            <span className="text-slate-500 text-sm">邮箱</span>
                            <span className="text-slate-900 dark:text-white font-medium">{user.email}</span>
                        </div>
                         <div className="flex justify-between items-center py-2 border-b border-slate-100 dark:border-white/5">
                            <span className="text-slate-500 text-sm">年龄</span>
                            <span className="text-slate-900 dark:text-white font-medium">{user.age || '未设置'}</span>
                        </div>
                    </div>
                 </div>
                 <div className="bg-white dark:bg-surface-dark rounded-[2rem] p-6 border border-slate-200 dark:border-white/5 shadow-lg">
                    <h4 className="text-lg font-bold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                        <span className="material-symbols-outlined text-accent-coral">logout</span>
                        账户操作
                    </h4>
                     <button onClick={() => { logout(); setView('login'); }} className="w-full py-3 rounded-xl border border-red-500/20 text-red-500 font-bold hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors flex items-center justify-center gap-2">
                        <span className="material-symbols-outlined">logout</span>
                        退出登录
                    </button>
                 </div>
            </div>

            <EditProfileModal isOpen={showEditModal} onClose={() => setShowEditModal(false)} user={user} onUpdate={() => fetchUser(true)} />
        </div>
    );
};



const App: React.FC = () => {
    const location = useLocation();
    const navigate = useNavigate();

    // Derived State from URL (Single Source of Truth)
    const getViewFromPath = (path: string) => {
        if (path === '/') return { view: 'homepage', subjectId: null, goalId: null };
        if (path === '/home') return { view: 'dashboard', subjectId: null, goalId: null };

        // Check for specific long paths first to avoid prefix conflicts
        if (path.startsWith('/english-history')) {
            return { view: 'history', subjectId: null, goalId: null };
        }

        if (path.startsWith('/subject/')) {
            const id = path.split('/subject/')[1];
            if (id && id.trim() !== '') return { view: 'detail', subjectId: id, goalId: null };
        } else if (path.startsWith('/goal/')) {
            const id = path.split('/goal/')[1];
            if (id && id.trim() !== '') return { view: 'goal', subjectId: null, goalId: id };
        } else if (path.startsWith('/english')) {
            return { view: 'english', subjectId: null, goalId: null };
        } else if (path.startsWith('/admin')) {
             // Only allow admin view if user is authorized (checked in useEffect below)
             // But we return 'admin' view here so the component tries to render
            return { view: 'admin', subjectId: null, goalId: null };
        }
        
        const route = path.substring(1);
        if (['calendar', 'stats', 'settings', 'profile', 'login', 'register', 'widget', 'forgot-password', 'security-check', 'admin'].includes(route)) {
            return { view: route, subjectId: null, goalId: null };
        }
        
        return { view: 'dashboard', subjectId: null, goalId: null };
    };

    const { view, goalId: selectedGoalId, subjectId: selectedSubjectId } = getViewFromPath(location.pathname);

    // State
    const { addGoal, deleteGoal, addSubject, deleteSubject } = useGoalStore();
    const { fetchSettings, settings } = useSettingsStore();
    const { user, fetchUser } = useUserStore(); // Add user store
    const [showAddModal, setShowAddModal] = useState(false);
    const [refreshKey, setRefreshKey] = useState(0);
    const [showAddGoalModal, setShowAddGoalModal] = useState(false);
    const [editModalTitle, setEditModalTitle] = useState<string | null>(null);
    const [theme, setTheme] = useState<'dark' | 'light'>('light');

    // Helper for legacy setView calls
    const setView = (newView: string) => {
        if (newView === 'dashboard') {
            navigate('/home');
        } else {
            navigate(`/${newView}`);
        }
    };

    // Delete Subject Logic
    const [subjects, setSubjects] = useState<Subject[]>(SUBJECTS);
    const [showDeleteModal, setShowDeleteModal] = useState(false);
    const [deletingSubject, setDeletingSubject] = useState<{id: string, title: string} | null>(null);
    const [showDeleteGoalModal, setShowDeleteGoalModal] = useState(false);
    
    // Ref to prevent duplicate logout messages
    const lastLogoutTimeRef = useRef(0);

    // Auth Check & Event Listener
    useEffect(() => {
        const token = localStorage.getItem('token');
        // Allow public pages (login, register) without token
        if (!token && view !== 'login' && view !== 'register' && view !== 'widget' && view !== 'forgot-password' && view !== 'security-check' && view !== 'homepage') {
            navigate('/login');
        } else if (token) {
             // Fetch user info if not exists
             if (!user) fetchUser();
             
             // Sync User Theme Settings
             fetchSettings();
             
             // Admin Route Protection and Auto-Redirect
             if (view === 'admin') {
                 // If user data is loaded and not admin, redirect
                 if (user && user.role !== 'ADMIN' && user.email !== 'admin@gmail.com') {
                     message.error("无权访问管理后台");
                     navigate('/');
                 }
             } else {
                 // If user IS admin and on dashboard, suggest or redirect to admin
                 // (Optional: forcing redirect might be annoying if admin wants to use user features)
                 // But let's check if user explicitly asked for /admin redirection
                 if (user && (user.role === 'ADMIN' || user.email === 'admin@gmail.com') && view === 'dashboard' && location.pathname === '/home') {
                      // We can redirect to admin if that's the desired behavior for super admins
                      navigate('/admin');
                 }
             }
        }
    }, [view, navigate, fetchSettings, user, fetchUser]); // Added user and fetchUser to deps

    // Separate effect for admin protection to avoid race conditions with user loading
    // useEffect(() => {
    //     if (view === 'admin' && user) {
    //          if (user.role !== 'ADMIN') {
    //              message.error("无权访问管理后台");
    //              navigate('/');
    //          }
    //     }
    // }, [view, user, navigate]);

    useEffect(() => {
        const handleAuthLogout = () => {
            const now = Date.now();
            // Prevent multiple logout messages within 3 seconds
            if (now - lastLogoutTimeRef.current < 3000) return;
            lastLogoutTimeRef.current = now;

            navigate('/login');
            message.error("会话已过期，请重新登录");
        };

        window.addEventListener('auth:logout', handleAuthLogout);
        return () => window.removeEventListener('auth:logout', handleAuthLogout);
    }, [view, navigate, fetchSettings]);

    // Apply theme from settings
    useEffect(() => {
        if (settings && settings.theme) {
            setTheme(settings.theme);
        }
    }, [settings]);

    const handleDeleteSubjectClick = (id: string, title: string) => {
        setDeletingSubject({ id, title });
        setShowDeleteModal(true);
    };

    const handleConfirmDelete = async () => {
        if (deletingSubject) {
            try {
                const res: any = await subjectApis.deleteSubject(deletingSubject.id);
                if (res.code === 200) {
                    message.success('科目已删除');
                    if (selectedGoalId) {
                        deleteSubject(selectedGoalId, deletingSubject.id);
                    }
                    setRefreshKey(prev => prev + 1);
                } else {
                    message.error(res.message || '删除失败');
                }
            } catch (error) {
                console.error(error);
                message.error('网络错误');
            } finally {
                setShowDeleteModal(false);
                setDeletingSubject(null);
            }
        }
    };

    const handleDeleteGoal = async () => {
        if (!selectedGoalId) return;
        try {
            const res: any = await goalApis.deleteGoal(selectedGoalId);
            if (res.code === 200) {
                message.success('目标已删除');
                setShowDeleteGoalModal(false);
                navigate('/');
                // Refresh goals list
                deleteGoal(selectedGoalId);
            } else {
                message.error(res.message || '删除失败');
            }
        } catch (error) {
            console.error(error);
            message.error('网络错误');
        }
    };

    const handleSubjectClick = (subjectId: string) => {
        navigate(`/subject/${subjectId}`);
    };

    const handleCreateSubject = async (title: string, content: string) => {
        if (!selectedGoalId) return;
        try {
            const res: any = await goalApis.createSubject({
                goalId: selectedGoalId,
                title,
                content
            });
            if (res.code === 200) {
                message.success('科目创建成功');
                
                // Optimistically update store
                const newSubject = {
                    ...res.data,
                    id: String(res.data.id)
                };
                addSubject(selectedGoalId, newSubject);

                setShowAddModal(false);
                setRefreshKey(prev => prev + 1);
            } else {
                message.error(res.message || '创建失败');
            }
        } catch (error) {
             console.error(error);
             message.error('网络错误');
        }
    };

    // Handle theme switching
    useEffect(() => {
        const root = window.document.documentElement;
        if (theme === 'dark') {
            root.classList.add('dark');
        } else {
            root.classList.remove('dark');
        }
    }, [theme]);

    const handleGoalClick = (id: string) => {
        navigate(`/goal/${id}`);
    };



    const handleCreateGoal = async (name: string, tag: 'priority' | 'daily' | 'longterm') => {
        try {
            const res: any = await goalApis.createGoal({
                title: name,
                labelType: tag
            });
            
            if (res.code === 200) {
                const newGoal = res.data;
                const mappedGoal = {
                    ...newGoal,
                    id: String(newGoal.id),
                    priority: newGoal.labelType === 'priority',
                    daily: newGoal.labelType === 'daily',
                };
                addGoal(mappedGoal);
                setShowAddGoalModal(false);
                message.success('目标创建成功');
            } else {
                 message.error(res.message || '创建失败');
            }
        } catch (error) {
            console.error(error);
            message.error('网络错误，请稍后重试');
        }
    };

    return (
        <div 
            className={view === 'widget' ? 'bg-transparent h-fit flex justify-center items-start pt-0 pointer-events-none' : 'bg-slate-50 dark:bg-background-dark text-slate-900 dark:text-white min-h-screen selection:bg-primary selection:text-white transition-colors duration-500 relative overflow-hidden z-0'}
            style={view === 'widget' ? { background: 'transparent', backgroundColor: 'transparent' } : {}}
        >
            {view !== 'widget' && <BackgroundGlow />}
            <MessageContainer />
            {view === 'widget' ? (
                <DynamicIslandWidget />
            ) : view === 'login' ? (
                <Login setView={setView} />
            ) : view === 'register' ? (
                <Register setView={setView} />
            ) : view === 'forgot-password' ? (
                <ForgotPassword setView={setView} />
            ) : view === 'security-check' ? (
                <SecurityCheck />
            ) : view === 'homepage' ? (
                <HomePage />
            ) : view === 'admin' ? (
                <AdminDashboard />
            ) : (
                <div className="flex flex-col w-full max-w-[1600px] mx-auto min-h-screen px-4 md:px-8 pb-10 relative overflow-hidden">
                    <Navigation />
            
                    <main className="flex flex-col lg:flex-row gap-8 flex-1">
                <div className="flex flex-col flex-1 gap-10">
                    {view === 'dashboard' && <Dashboard setView={setView} onOpenAddGoal={() => setShowAddGoalModal(true)} onGoalClick={handleGoalClick} />}
                    {view === 'goal' && (
                        <GoalDetail 
                            // key removed to prevent remounting on refreshKey change
                            goalId={selectedGoalId}
                            setView={setView} 
                            onAddSubject={() => setShowAddModal(true)} 
                            onDeleteSubject={handleDeleteSubjectClick}
                            onDeleteGoal={() => setShowDeleteGoalModal(true)}
                            onSubjectClick={handleSubjectClick}
                        />
                    )}
                    {view === 'detail' && <SubjectDetail subjectId={selectedSubjectId} setView={setView} onEdit={(title) => setEditModalTitle(title)} />}
                    {view === 'settings' && <Settings theme={theme} setTheme={setTheme} />}
                    {view === 'calendar' && <Calendar />}
                    {view === 'stats' && <Stats />}
                    {view === 'english' && <English setView={setView} />}
                    {view === 'history' && <LearnedHistory onBack={() => setView('english')} />}
                    {view === 'profile' && <Profile setView={setView} />}
                    {view !== 'dashboard' && view !== 'goal' && view !== 'detail' && view !== 'settings' && view !== 'profile' && view !== 'calendar' && view !== 'stats' && view !== 'english' && view !== 'history' && (
                        <div className="flex items-center justify-center h-full text-text-secondary">Work in progress...</div>
                    )}
                </div>
                {view !== 'english' && <Widgets />}
            </main>
            </div>
            )}

            {showAddModal && <AddSubjectModal onClose={() => setShowAddModal(false)} onCreate={handleCreateSubject} />}
            {showAddGoalModal && <AddGoalModal onClose={() => setShowAddGoalModal(false)} onCreate={handleCreateGoal} />}
            {editModalTitle && <EditContentModal title={editModalTitle} onClose={() => setEditModalTitle(null)} />}
            {showDeleteModal && deletingSubject && (
                <DeleteConfirmModal 
                    title={deletingSubject.title} 
                    onClose={() => setShowDeleteModal(false)} 
                    onConfirm={handleConfirmDelete} 
                />
            )}
            {showDeleteGoalModal && (
                <DeleteConfirmModal 
                    title="当前计划" 
                    onClose={() => setShowDeleteGoalModal(false)} 
                    onConfirm={handleDeleteGoal} 
                />
            )}
        </div>
    );
};

export default App;
