import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { 
    Users, ShieldCheck, Activity, TrendingUp, Clock, 
    Server, Globe, Cpu, AlertCircle, CheckCircle2 
} from 'lucide-react';
import adminApis from '../../services/adminApis';

// Stats Card Component
const StatCard = ({ title, value, subtext, icon: Icon, colorClass, bgClass }: any) => (
    <div className={`p-6 rounded-3xl border border-slate-200 dark:border-white/5 shadow-sm relative overflow-hidden group ${bgClass}`}>
        <div className="absolute right-0 top-0 p-6 opacity-5 group-hover:opacity-10 transition-opacity">
            <Icon className="size-24" />
        </div>
        <h3 className="text-slate-500 dark:text-slate-400 text-sm font-bold uppercase tracking-wider mb-2">{title}</h3>
        <div className="text-4xl font-black text-slate-900 dark:text-white mb-4">{value}</div>
        {subtext && (
            <div className={`inline-flex items-center gap-2 text-sm font-bold px-3 py-1 rounded-full w-fit ${colorClass}`}>
                {subtext}
            </div>
        )}
    </div>
);

// System Status Item
const SystemStatusItem = ({ label, status, icon: Icon }: any) => (
    <div className="flex items-center justify-between p-4 bg-slate-50 dark:bg-white/5 rounded-2xl">
        <div className="flex items-center gap-3">
            <div className={`p-2 rounded-xl ${status === 'normal' ? 'bg-green-100 text-green-600 dark:bg-green-900/20 dark:text-green-400' : 'bg-yellow-100 text-yellow-600'}`}>
                <Icon className="size-5" />
            </div>
            <span className="font-medium text-slate-700 dark:text-slate-200">{label}</span>
        </div>
        <div className="flex items-center gap-2">
            <div className={`size-2 rounded-full ${status === 'normal' ? 'bg-green-500' : 'bg-yellow-500'} animate-pulse`} />
            <span className="text-xs font-mono text-slate-500">{status === 'normal' ? '运行正常' : '负载较高'}</span>
        </div>
    </div>
);

const DashboardOverview: React.FC = () => {
    const [stats, setStats] = useState({
        totalUsers: 0,
        newUsersThisMonth: 0,
        whitelistUsageRate: 0,
        whitelistActivatedCount: 0,
        whitelistTotalCount: 0,
        activeUsersToday: 0
    });

    useEffect(() => {
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
        fetchStats();
    }, []);

    const container = {
        hidden: { opacity: 0 },
        show: {
            opacity: 1,
            transition: { staggerChildren: 0.1 }
        }
    };

    const item = {
        hidden: { opacity: 0, y: 20 },
        show: { opacity: 1, y: 0 }
    };

    return (
        <motion.div 
            variants={container}
            initial="hidden"
            animate="show"
            className="space-y-8"
        >
            {/* Hero Section */}
            <motion.div variants={item} className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <StatCard 
                    title="总注册用户" 
                    value={stats.totalUsers.toLocaleString()} 
                    subtext={`+${stats.newUsersThisMonth} 本月新增`}
                    icon={Users}
                    colorClass="bg-green-50 text-green-600 dark:bg-green-900/20 dark:text-green-400"
                    bgClass="bg-white dark:bg-surface-dark"
                />
                <StatCard 
                    title="白名单使用率" 
                    value={`${stats.whitelistUsageRate}%`} 
                    subtext={`${stats.whitelistActivatedCount}/${stats.whitelistTotalCount} 已激活`}
                    icon={ShieldCheck}
                    colorClass="bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400"
                    bgClass="bg-white dark:bg-surface-dark"
                />
                <div className="bg-gradient-to-br from-indigo-600 to-violet-700 p-6 rounded-3xl text-white shadow-xl shadow-indigo-500/20 relative overflow-hidden">
                    <div className="relative z-10">
                        <h3 className="text-indigo-100 text-sm font-bold uppercase tracking-wider mb-2">今日活跃</h3>
                        <div className="text-5xl font-black mb-4">{stats.activeUsersToday.toLocaleString()}</div>
                        <div className="flex items-center gap-2 text-indigo-100 bg-white/10 px-3 py-1.5 rounded-full w-fit backdrop-blur-sm">
                            <Activity className="size-4" />
                            <span className="text-sm font-medium">实时监控中...</span>
                        </div>
                    </div>
                    <div className="absolute -bottom-6 -right-6 size-40 bg-white/10 rounded-full blur-3xl" />
                    <div className="absolute top-0 right-0 p-6 opacity-20">
                        <TrendingUp className="size-24" />
                    </div>
                </div>
            </motion.div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* System Status */}
                <motion.div variants={item} className="lg:col-span-2 bg-white dark:bg-surface-dark p-6 rounded-3xl border border-slate-200 dark:border-white/5 shadow-sm">
                    <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-6 flex items-center gap-2">
                        <Server className="size-5 text-slate-400" />
                        系统状态概览
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <SystemStatusItem label="API 服务" status="normal" icon={Globe} />
                        <SystemStatusItem label="数据库连接" status="normal" icon={Server} />
                        <SystemStatusItem label="Redis 缓存" status="normal" icon={Cpu} />
                        <SystemStatusItem label="邮件服务" status="normal" icon={CheckCircle2} />
                    </div>
                    
                    <div className="mt-6 p-4 bg-slate-50 dark:bg-white/5 rounded-2xl border border-slate-100 dark:border-white/5">
                        <div className="flex items-start gap-3">
                            <AlertCircle className="size-5 text-blue-500 mt-0.5" />
                            <div>
                                <h4 className="font-bold text-slate-900 dark:text-white text-sm">系统公告</h4>
                                <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
                                    系统将于本周日凌晨 03:00 进行例行维护，预计耗时 30 分钟。请提前做好准备。
                                </p>
                            </div>
                        </div>
                    </div>
                </motion.div>

                {/* Quick Actions / Recent Activity */}
                <motion.div variants={item} className="bg-white dark:bg-surface-dark p-6 rounded-3xl border border-slate-200 dark:border-white/5 shadow-sm">
                    <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-6 flex items-center gap-2">
                        <Clock className="size-5 text-slate-400" />
                        最近活动
                    </h3>
                    <div className="space-y-6">
                        {[1, 2, 3].map((_, i) => (
                            <div key={i} className="flex gap-4 relative">
                                {i !== 2 && <div className="absolute left-2.5 top-8 bottom-[-24px] w-0.5 bg-slate-100 dark:bg-white/5" />}
                                <div className="size-5 rounded-full bg-primary/20 border-2 border-primary mt-1 relative z-10" />
                                <div>
                                    <p className="text-sm font-medium text-slate-900 dark:text-white">系统自动备份完成</p>
                                    <p className="text-xs text-slate-500 mt-1">2026-02-07 12:00:00</p>
                                </div>
                            </div>
                        ))}
                    </div>
                </motion.div>
            </div>
        </motion.div>
    );
};

export default DashboardOverview;
