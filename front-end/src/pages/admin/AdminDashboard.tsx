import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { LayoutDashboard, Users, ShieldCheck, LogOut, Search } from 'lucide-react';
import UserTable from './UserTable';
import WhitelistManager from './WhitelistManager';
import DashboardOverview from './DashboardOverview';
import { useUserStore } from '../../store/useUserStore';

// Sidebar Menu Items
const MENU_ITEMS = [
    { id: 'dashboard', label: '控制台', icon: LayoutDashboard },
    { id: 'users', label: '用户审计', icon: Users },
    { id: 'whitelist', label: '准入管理', icon: ShieldCheck },
];

const AdminDashboard: React.FC = () => {
    const navigate = useNavigate();
    const { logout } = useUserStore();
    const [activeTab, setActiveTab] = useState('dashboard');

    const handleLogout = () => {
        logout();
        navigate('/login');
    };

    return (
        <div className="min-h-screen flex font-sans text-slate-900 dark:text-white">
            {/* Sidebar */}
            <aside className="w-64 fixed h-full bg-white dark:bg-surface-dark border-r border-slate-200 dark:border-white/5 flex flex-col z-20">
                <div className="p-6 flex items-center gap-3">
                    <div className="size-8 rounded-lg bg-primary flex items-center justify-center text-white font-bold">M</div>
                    <span className="font-bold text-xl tracking-tight">Admin<span className="text-primary">Panel</span></span>
                </div>

                <nav className="flex-1 px-4 space-y-2 mt-4">
                    {MENU_ITEMS.map((item) => (
                        <button
                            key={item.id}
                            onClick={() => setActiveTab(item.id)}
                            className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all font-medium ${
                                activeTab === item.id
                                    ? 'bg-primary text-white shadow-lg shadow-blue-500/30'
                                    : 'text-slate-500 hover:bg-slate-50 dark:text-slate-400 dark:hover:bg-white/5'
                            }`}
                        >
                            <item.icon className="size-5" />
                            {item.label}
                        </button>
                    ))}
                </nav>

                <div className="p-4">
                    <button 
                        onClick={handleLogout}
                        className="w-full flex items-center gap-3 px-4 py-3 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/10 rounded-xl transition-all"
                    >
                        <LogOut className="size-5" />
                        退出管理
                    </button>
                </div>
            </aside>

            {/* Main Content */}
            <main className="flex-1 ml-64 p-8">
                {/* Header */}
                <header className="flex justify-between items-center mb-8">
                    <div>
                        <h1 className="text-3xl font-bold text-slate-900 dark:text-white">
                            {MENU_ITEMS.find(i => i.id === activeTab)?.label}
                        </h1>
                        <p className="text-slate-500 mt-1">MemoryFlow 后台管理系统</p>
                    </div>
                    <div className="flex items-center gap-4">
                        <div className="flex items-center gap-2 bg-white dark:bg-surface-dark px-3 py-1.5 rounded-full border border-slate-200 dark:border-white/5 shadow-sm">
                            <div className="size-2 rounded-full bg-green-500 animate-pulse" />
                            <span className="text-xs font-mono text-slate-500">System Online</span>
                        </div>
                        <div className="size-10 rounded-full bg-slate-200 dark:bg-white/10 overflow-hidden border-2 border-white dark:border-white/5 shadow-lg">
                            <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=Admin" alt="Admin" />
                        </div>
                    </div>
                </header>

                {/* Content Area */}
                <motion.div
                    key={activeTab}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.3 }}
                >
                    {activeTab === 'dashboard' && <DashboardOverview />}
                    {activeTab === 'users' && <UserTable />}
                    {activeTab === 'whitelist' && <WhitelistManager />}
                </motion.div>
            </main>
        </div>
    );
};

export default AdminDashboard;
