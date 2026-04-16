import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, Filter, Lock, Unlock, MapPin, Calendar, Activity, Users, ShieldCheck } from 'lucide-react';
import adminApis from '../../services/adminApis';
import { resolveApiAssetUrl } from '../../utils/resolveApiAssetUrl';

interface User {
    id: number;
    email: string;
    nickname: string;
    avatarUrl: string;
    status: number; // 1=Normal, 0=Banned
    registrationIp: string;
    registrationLocation?: string;
    lastLoginIp: string;
    lastLoginLocation?: string;
    lastLoginTime: string;
    loginCount: number;
    createdAt: string;
}

const UserTable: React.FC = () => {
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);
    const [keyword, setKeyword] = useState('');
    const [onlyBanned, setOnlyBanned] = useState(false);
    const [page, setPage] = useState(1);
    const [total, setTotal] = useState(0);
    const [stats, setStats] = useState({
        totalUsers: 0,
        newUsersThisMonth: 0,
        whitelistUsageRate: 0,
        whitelistActivatedCount: 0,
        whitelistTotalCount: 0,
        activeUsersToday: 0
    });

    const fetchStats = async () => {
        try {
            const res = await adminApis.getStats();
            if (res.data) {
                setStats(res.data);
            }
        } catch (error) {
            console.error('Failed to fetch stats', error);
        }
    };

    const fetchUsers = async () => {
        setLoading(true);
        try {
            const res = await adminApis.getUserList(page, 10, keyword, onlyBanned);
            if (res.data) {
                setUsers(res.data.records);
                setTotal(res.data.total);
            }
        } catch (error) {
            console.error('Failed to fetch users', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        // Debounce fetch when keyword changes
        const timer = setTimeout(() => {
            fetchUsers();
        }, 300);
        return () => clearTimeout(timer);
    }, [page, keyword, onlyBanned]);

    // Force refresh when component mounts or tab becomes active
    useEffect(() => {
        fetchUsers();
        fetchStats();
    }, []);

    const handleToggleStatus = async (user: User) => {
        try {
            if (user.status === 1) {
                await adminApis.banUser(user.id);
            } else {
                await adminApis.unbanUser(user.id);
            }
            // Refresh local state to avoid full reload
            setUsers(users.map(u => u.id === user.id ? { ...u, status: u.status === 1 ? 0 : 1 } : u));
        } catch (error) {
            console.error('Failed to update status', error);
        }
    };

    // Stagger animation variants
    const container = {
        hidden: { opacity: 0 },
        show: {
            opacity: 1,
            transition: {
                staggerChildren: 0.05
            }
        }
    };

    const item = {
        hidden: { opacity: 0, y: 20 },
        show: { opacity: 1, y: 0 }
    };

    const formatDate = (dateStr: string) => {
        if (!dateStr) return '从未登录';
        const date = new Date(dateStr);
        const now = new Date();
        const diff = now.getTime() - date.getTime();
        
        // Less than 1 hour
        if (diff < 3600000) return `${Math.floor(diff / 60000)}分钟前`;
        // Less than 24 hours
        if (diff < 86400000) return `${Math.floor(diff / 3600000)}小时前`;
        // Less than 7 days
        if (diff < 604800000) return `${Math.floor(diff / 86400000)}天前`;
        
        return date.toLocaleDateString();
    };

    return (
        <div className="space-y-6">
            {/* Toolbar */}
            <div className="flex flex-col sm:flex-row gap-4 justify-between items-center bg-white dark:bg-surface-dark p-4 rounded-2xl border border-slate-200 dark:border-white/5 shadow-sm">
                <div className="relative w-full sm:w-96">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 size-5" />
                    <input
                        type="text"
                        placeholder="搜索邮箱或昵称..."
                        value={keyword}
                        onChange={(e) => setKeyword(e.target.value)}
                        className="w-full pl-10 pr-4 py-2 bg-slate-50 dark:bg-black/20 border border-slate-200 dark:border-white/10 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all text-slate-700 dark:text-white"
                    />
                </div>
                <div className="flex items-center gap-3 w-full sm:w-auto">
                    <button
                        onClick={() => setOnlyBanned(!onlyBanned)}
                        className={`flex items-center gap-2 px-4 py-2 rounded-xl border transition-all ${
                            onlyBanned 
                                ? 'bg-red-50 dark:bg-red-500/10 border-red-200 dark:border-red-500/30 text-red-600 dark:text-red-400' 
                                : 'bg-white dark:bg-surface-dark border-slate-200 dark:border-white/10 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-white/5'
                        }`}
                    >
                        <Filter className="size-4" />
                        <span>{onlyBanned ? '已筛选: 被封禁' : '筛选状态'}</span>
                    </button>
                </div>
            </div>

            {/* Table */}
            <div className="bg-white dark:bg-surface-dark rounded-3xl border border-slate-200 dark:border-white/5 shadow-lg overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse">
                        <thead>
                            <tr className="border-b border-slate-100 dark:border-white/5 bg-slate-50/50 dark:bg-white/5">
                                <th className="p-5 text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">用户</th>
                                <th className="p-5 text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">审计信息</th>
                                <th className="p-5 text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">活跃度</th>
                                <th className="p-5 text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider text-right">操作</th>
                            </tr>
                        </thead>
                        <tbody
                            className="divide-y divide-slate-100 dark:divide-white/5"
                        >
                            {loading ? (
                                <tr>
                                    <td colSpan={4} className="p-10 text-center text-slate-400">加载中...</td>
                                </tr>
                            ) : users.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="p-10 text-center text-slate-400">暂无数据</td>
                                </tr>
                            ) : users.map((user) => (
                                <tr 
                                    key={user.id} 
                                    className={`group transition-colors hover:bg-slate-50 dark:hover:bg-white/5 ${user.status === 0 ? 'bg-red-50/30 dark:bg-red-900/10' : ''}`}
                                >
                                    <td className="p-5">
                                        <div className="flex items-center gap-4">
                                            <div className="relative">
                                                <div className="size-12 rounded-full bg-slate-200 dark:bg-white/10 overflow-hidden">
                                                    {user.avatarUrl ? (
                                                        <img src={resolveApiAssetUrl(user.avatarUrl)} alt={user.nickname} className="w-full h-full object-cover" />
                                                    ) : (
                                                        <div className="w-full h-full flex items-center justify-center text-slate-400 font-bold text-lg">
                                                            {user.nickname?.[0]?.toUpperCase() || 'U'}
                                                        </div>
                                                    )}
                                                </div>
                                                {user.status === 0 && (
                                                    <div className="absolute -bottom-1 -right-1 bg-red-500 text-white rounded-full p-1 border-2 border-white dark:border-surface-dark">
                                                        <Lock className="size-3" />
                                                    </div>
                                                )}
                                            </div>
                                            <div>
                                                <div className="font-bold text-slate-900 dark:text-white flex items-center gap-2">
                                                    {user.nickname || '未命名用户'}
                                                    {user.status === 0 && <span className="text-xs px-2 py-0.5 rounded bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400 font-medium">已冻结</span>}
                                                </div>
                                                <div className="text-sm text-slate-500 dark:text-slate-400 font-mono">{user.email}</div>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="p-5">
                                        <div className="space-y-2">
                                            <div className="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
                                                <MapPin className="size-4 text-slate-400" />
                                                <span className="font-mono text-xs bg-slate-100 dark:bg-white/10 px-2 py-1 rounded">
                                                    注册: {user.registrationIp || '未知'}
                                                </span>
                                                <span className="text-[10px] text-slate-400 ml-1">
                                                    📍 {user.registrationLocation || '本地/未知'}
                                                </span>
                                            </div>
                                            <div className="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
                                                <Activity className="size-4 text-primary" />
                                                <span className="font-mono text-xs bg-primary/10 text-primary px-2 py-1 rounded">
                                                    最近: {user.lastLoginIp || '无记录'}
                                                </span>
                                                <span className="text-[10px] text-slate-400 ml-1">
                                                    📍 {user.lastLoginLocation || '本地/未知'}
                                                </span>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="p-5">
                                        <div className="space-y-1">
                                            <div className="flex items-center gap-2 text-sm text-slate-900 dark:text-white font-medium">
                                                <Calendar className="size-4 text-slate-400" />
                                                {formatDate(user.lastLoginTime)}
                                            </div>
                                            <div className="text-xs text-slate-500 dark:text-slate-400">
                                                累计登录 {user.loginCount || 0} 次
                                            </div>
                                        </div>
                                    </td>
                                    <td className="p-5 text-right">
                                        <button
                                            onClick={() => handleToggleStatus(user)}
                                            className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                                                user.status === 1
                                                    ? 'text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20'
                                                    : 'text-green-600 hover:bg-green-50 dark:hover:bg-green-900/20'
                                            }`}
                                        >
                                            {user.status === 1 ? (
                                                <>
                                                    <Lock className="size-4" /> 冻结
                                                </>
                                            ) : (
                                                <>
                                                    <Unlock className="size-4" /> 解冻
                                                </>
                                            )}
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
                {/* Pagination (Simple) */}
                <div className="p-4 border-t border-slate-100 dark:border-white/5 flex justify-end gap-2">
                    <button 
                        disabled={page === 1}
                        onClick={() => setPage(p => p - 1)}
                        className="px-3 py-1 rounded border border-slate-200 dark:border-white/10 text-sm disabled:opacity-50"
                    >
                        上一页
                    </button>
                    <span className="px-3 py-1 text-sm text-slate-500">第 {page} 页</span>
                    <button 
                        disabled={users.length < 10} // Simple check
                        onClick={() => setPage(p => p + 1)}
                        className="px-3 py-1 rounded border border-slate-200 dark:border-white/10 text-sm disabled:opacity-50"
                    >
                        下一页
                    </button>
                </div>
            </div>
        </div>
    );
};

export default UserTable;
