import { Goal, Subject, Task, Topic } from './types';

export const GOALS: Goal[] = [
    {
        id: '1',
        title: '字节跳动 Offer',
        subtitle: '下一项: 动态规划算法练习 (LeetCode)',
        priority: true,
        progress: 65,
        icon: 'corporate_fare',
        colorClass: 'text-primary',
        iconBgClass: 'bg-white text-black',
        status: 'active',
        dueDate: '2024-12-01'
    },
    {
        id: '2',
        title: '雅思口语 7.5+',
        subtitle: '下一项: Part 2 Topic Preparation',
        daily: true,
        progress: 40,
        icon: 'school',
        colorClass: 'text-purple-400',
        iconBgClass: 'bg-gradient-to-br from-purple-500 to-indigo-600 text-white',
        status: 'active',
        dueDate: '2024-11-15'
    }
];

export const SUBJECTS: Subject[] = [
    {
        id: 's1',
        title: '数据结构',
        progress: 80,
        totalTasks: 50,
        completedTasks: 40,
        icon: 'dataset',
        colorClass: 'text-accent-green',
        bgClass: 'bg-accent-green',
        status: 'In Progress'
    },
    {
        id: 's2',
        title: 'Go语言',
        progress: 30,
        totalTasks: 50,
        completedTasks: 15,
        icon: 'terminal',
        colorClass: 'text-primary',
        bgClass: 'bg-primary',
        status: 'In Progress'
    },
    {
        id: 's3',
        title: '英语',
        progress: 0,
        totalTasks: 10,
        completedTasks: 0,
        icon: 'translate',
        colorClass: 'text-accent-coral',
        bgClass: 'bg-accent-coral',
        status: 'Due Today'
    }
];

export const TOPICS: Topic[] = [
    {
        id: 't1',
        title: '二叉树遍历',
        status: 'pending',
        isExpanded: false
    },
    {
        id: 't2',
        title: '红黑树插入算法',
        status: 'in-progress',
        isExpanded: true,
        notes: [
            '根节点是黑色 (The root node is always black). This property ensures the tree structure starts correctly.',
            '插入节点默认为红色 (Inserted nodes default to red). This minimizes violation of black-height properties.',
            '每个叶子节点（NIL节点）是黑色的 (Every leaf/NIL node is black).'
        ]
    },
    {
        id: 't3',
        title: 'B+树索引原理',
        status: 'pending',
        isExpanded: false
    }
];

export const TASKS: Task[] = [
    {
        id: 'tk1',
        title: 'LeetCode 每日一题',
        time: '20:00 - 21:00',
        completed: false,
        tag: 'primary',
    },
    {
        id: 'tk2',
        title: '背诵 50 个雅思单词',
        time: 'Before Bed',
        completed: false,
        tag: 'primary',
    },
    {
        id: 'tk3',
        title: '复习操作系统笔记',
        time: 'Completed 14:30',
        completed: true,
        tag: 'success',
    }
];

export const GOAL_THEMES = [
    {
        id: 'byte',
        icon: 'corporate_fare',
        colorClass: 'text-primary',
        iconBgClass: 'bg-white text-black',
        progressGradient: 'linear-gradient(to right, #3B82F6, #60A5FA)',
    },
    {
        id: 'study',
        icon: 'school',
        colorClass: 'text-purple-400',
        iconBgClass: 'bg-gradient-to-br from-purple-500 to-indigo-600 text-white',
        progressGradient: 'linear-gradient(to right, #A855F7, #6366F1)',
    },
    {
        id: 'code',
        icon: 'code',
        colorClass: 'text-cyan-500',
        iconBgClass: 'bg-gradient-to-br from-blue-500 to-cyan-500 text-white',
        progressGradient: 'linear-gradient(to right, #0EA5E9, #22D3EE)',
    },
    {
        id: 'psychology',
        icon: 'psychology',
        colorClass: 'text-emerald-500',
        iconBgClass: 'bg-gradient-to-br from-emerald-500 to-teal-500 text-white',
        progressGradient: 'linear-gradient(to right, #10B981, #14B8A6)',
    },
    {
        id: 'group',
        icon: 'group',
        colorClass: 'text-rose-500',
        iconBgClass: 'bg-gradient-to-br from-rose-500 to-pink-500 text-white',
        progressGradient: 'linear-gradient(to right, #F43F5E, #EC4899)',
    },
    {
        id: 'star',
        icon: 'star',
        colorClass: 'text-amber-500',
        iconBgClass: 'bg-gradient-to-br from-amber-400 to-orange-500 text-white',
        progressGradient: 'linear-gradient(to right, #F59E0B, #F97316)',
    },
    {
        id: 'premium',
        icon: 'workspace_premium',
        colorClass: 'text-indigo-500',
        iconBgClass: 'bg-gradient-to-br from-indigo-500 to-blue-600 text-white',
        progressGradient: 'linear-gradient(to right, #6366F1, #2563EB)',
    },
    {
        id: 'science',
        icon: 'science',
        colorClass: 'text-lime-500',
        iconBgClass: 'bg-gradient-to-br from-lime-500 to-green-500 text-white',
        progressGradient: 'linear-gradient(to right, #84CC16, #22C55E)',
    },
    {
        id: 'language',
        icon: 'language',
        colorClass: 'text-fuchsia-500',
        iconBgClass: 'bg-gradient-to-br from-fuchsia-500 to-violet-500 text-white',
        progressGradient: 'linear-gradient(to right, #D946EF, #8B5CF6)',
    },
    {
        id: 'computer',
        icon: 'computer',
        colorClass: 'text-teal-500',
        iconBgClass: 'bg-gradient-to-br from-teal-500 to-cyan-500 text-white',
        progressGradient: 'linear-gradient(to right, #14B8A6, #06B6D4)',
    },
    {
        id: 'global',
        icon: 'public',
        colorClass: 'text-sky-500',
        iconBgClass: 'bg-gradient-to-br from-sky-500 to-blue-500 text-white',
        progressGradient: 'linear-gradient(to right, #0EA5E9, #2563EB)',
    },
    {
        id: 'terminal',
        icon: 'terminal',
        colorClass: 'text-slate-400',
        iconBgClass: 'bg-gradient-to-br from-slate-500 to-slate-700 text-white',
        progressGradient: 'linear-gradient(to right, #64748B, #334155)',
    },
    {
        id: 'light',
        icon: 'emoji_objects',
        colorClass: 'text-yellow-500',
        iconBgClass: 'bg-gradient-to-br from-yellow-400 to-amber-500 text-white',
        progressGradient: 'linear-gradient(to right, #F59E0B, #FB923C)',
    },
    {
        id: 'rocket',
        icon: 'rocket_launch',
        colorClass: 'text-orange-500',
        iconBgClass: 'bg-gradient-to-br from-orange-500 to-red-500 text-white',
        progressGradient: 'linear-gradient(to right, #F97316, #EF4444)',
    },
];
