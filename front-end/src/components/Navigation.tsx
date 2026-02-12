import React, { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useUserStore } from '../store/useUserStore';

// 导航栏组件：使用项目统一的 glass-panel 毛玻璃样式
export const Navigation: React.FC = () => {
    // 当前路径（HashRouter 下为 # 后的路径）
    const location = useLocation();
    const pathname = location.pathname;
    const [isScrolled, setIsScrolled] = useState(false);
    const [isHovered, setIsHovered] = useState(false);
    // 新增状态：控制弹性动画阶段
    const [isAnimating, setIsAnimating] = useState(false);
    const [isDesktop, setIsDesktop] = useState(true);
    const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
    
    // 使用 User Storeright-4 md:right-8
    const { user, fetchUser } = useUserStore();
    const avatarUrl = user?.avatarUrl;

    useEffect(() => {
        fetchUser();
        
        // Listen for profile update event to re-fetch if needed (though store update should handle it)
        const handleProfileUpdate = () => fetchUser(true);
        window.addEventListener('profile:updated', handleProfileUpdate);
        
        return () => {
            window.removeEventListener('profile:updated', handleProfileUpdate);
        };
    }, []);

    useEffect(() => {
        const mediaQuery = window.matchMedia('(min-width: 768px)');
        const update = () => setIsDesktop(mediaQuery.matches);
        update();
        mediaQuery.addEventListener?.('change', update);
        return () => mediaQuery.removeEventListener?.('change', update);
    }, []);

    useEffect(() => {
        setMobileMenuOpen(false);
    }, [pathname]);

    // 监听滚动事件
    useEffect(() => {
        const handleScroll = () => {
            const shouldCollapse = window.scrollY > 50;
            if (shouldCollapse !== isScrolled) {
                setIsScrolled(shouldCollapse);
                // 触发弹性动画
                setIsAnimating(true);
                setTimeout(() => setIsAnimating(false), 1200); // 动画结束后重置 (延长到1.2秒以覆盖1秒动画)
            }
        };

        window.addEventListener('scroll', handleScroll);
        return () => window.removeEventListener('scroll', handleScroll);
    }, [isScrolled]);

    const isCollapsed = isDesktop && isScrolled && !isHovered;

    // 路由配置：导航项与路径映射
    const navItems = [
        { id: 'dashboard', label: '首页', path: '/home', icon: 'home' },
        { id: 'calendar', label: '日历', path: '/calendar', icon: 'calendar_month' },
        { id: 'stats', label: '统计', path: '/stats', icon: 'analytics' },
        { id: 'english', label: '英语', path: '/english', icon: 'translate' },
        { id: 'settings', label: '设置', path: '/settings', icon: 'settings' }
    ];

    // “首页”按钮在 /、/detail、/subject 下都高亮
    const isDashboardActive = pathname === '/home' || pathname === '/detail' || pathname === '/subject';

    return (
        <>
            {/* 占位元素，占据文档流空间，防止 fixed 导致下方内容上移 */}
            <div className="h-[80px] mb-10 w-full" />
            <header className="fixed top-6 left-0 z-40 flex justify-center w-full mb-10 pointer-events-none h-[80px]">
                {/* 占位容器，保持原始布局宽度 */}
                <div className={`relative transition-all duration-700 ease-[cubic-bezier(0.4,0,0.2,1)] h-full ${
                    isCollapsed ? 'w-full max-w-[1600px] px-4 md:px-8' : 'w-full max-w-4xl mx-4'
                }`}>
                    <nav 
                        className={`glass-panel !border-0 pointer-events-auto flex items-center absolute right-0 shadow-[0_12px_30px_rgba(15,23,42,0.10),0_2px_8px_rgba(15,23,42,0.06)] hover:shadow-[0_20px_50px_rgba(15,23,42,0.14),0_8px_16px_rgba(15,23,42,0.08)] dark:shadow-[0_14px_44px_rgba(0,0,0,0.55),0_4px_14px_rgba(0,0,0,0.30)] dark:hover:shadow-[0_22px_70px_rgba(0,0,0,0.60),0_10px_24px_rgba(0,0,0,0.34)] transition-all duration-[1000ms] ${mobileMenuOpen ? 'overflow-visible' : 'overflow-hidden'} ${
                            isAnimating 
                                ? (isCollapsed ? 'animate-squish-in' : 'animate-squish-out') // 应用弹性动画
                                : 'ease-[cubic-bezier(0.34,1.56,0.64,1)]' // 静态时的平滑回弹效果
                        } ${
                            isCollapsed 
                            ? 'w-[48px] h-[48px] rounded-full justify-center p-0 top-[16px] right-4 md:right-8 lg:right-[240px] xl:right-[346px]' // 收缩时
                            : 'w-full h-full rounded-full justify-between px-5 py-4 top-0 right-0'
                        }`}
                        onMouseEnter={() => setIsHovered(true)}
                        onMouseLeave={() => setIsHovered(false)}
                    >
                        <div className={`flex items-center gap-2 transition-all duration-500 ${
                            isCollapsed ? 'opacity-0 w-0 p-0 overflow-hidden absolute left-0' : 'opacity-100 w-auto pl-2 pr-2 relative'
                        }`}>
                            <button
                                type="button"
                                aria-label={mobileMenuOpen ? '关闭菜单' : '打开菜单'}
                                aria-expanded={mobileMenuOpen}
                                onClick={() => setMobileMenuOpen((v) => !v)}
                                className={`md:hidden size-12 rounded-full flex items-center justify-center transition-colors ${
                                    mobileMenuOpen
                                        ? 'bg-slate-200 dark:bg-white/10 text-slate-900 dark:text-white'
                                        : 'text-slate-500 hover:bg-slate-200 dark:text-text-secondary dark:hover:text-white dark:hover:bg-white/10'
                                }`}
                            >
                                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                                    <path d="M4 7H20" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
                                    <path d="M4 12H20" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
                                    <path d="M4 17H20" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
                                </svg>
                            </button>
                            <Link 
                                to="/home" 
                                className="flex items-center gap-4 cursor-pointer transition-all duration-500 pl-3 pr-3"
                            >
                                <img 
                                    src="/logo-memoryflow.png" 
                                    alt="MemoryFlow Logo" 
                                    className="size-10 object-contain shrink-0" 
                                />
                                <span className="text-slate-800 dark:text-white font-bold text-xl tracking-tight hidden sm:block whitespace-nowrap">
                                    MemoryFlow
                                </span>
                            </Link>
                        </div>

                        {/* Nav Links */}
                        <div className={`hidden md:flex items-center bg-slate-100/50 dark:bg-[#0F172A]/50 rounded-full p-2 transition-all duration-500 overflow-hidden ${
                            isCollapsed ? 'opacity-0 w-0 p-0 border-0 absolute left-1/2 -translate-x-1/2' : 'opacity-100 w-auto relative'
                        }`}>
                            {navItems.map((item) => (
                                <Link
                                    key={item.id}
                                    to={item.path}
                                    className={`px-7 py-3 rounded-full text-base font-bold transition-all whitespace-nowrap ${
                                        (item.id === 'dashboard' && isDashboardActive) ||
                                        (item.id !== 'dashboard' && pathname === item.path)
                                            ? 'bg-primary text-white shadow-glow'
                                            : 'text-slate-500 hover:text-slate-900 hover:bg-white/50 dark:text-text-secondary dark:hover:text-white dark:hover:bg-white/5'
                                    }`}
                                >
                                    {item.label}
                                </Link>
                            ))}
                        </div>

                        {/* Profile：链接到个人资料页 */}
                        <div className={`flex items-center gap-2 transition-all duration-500 overflow-hidden ${
                            isCollapsed ? 'w-full justify-center pr-0 absolute right-0' : 'w-auto opacity-100 pr-2 relative'
                        }`}>
                            <button className={`size-12 rounded-full flex items-center justify-center text-slate-500 hover:bg-slate-200 dark:text-text-secondary dark:hover:text-white dark:hover:bg-white/10 transition-colors shrink-0 ${
                                isCollapsed ? 'w-0 opacity-0 overflow-hidden hidden' : 'block'
                            }`}>
                                <span className="material-symbols-outlined text-[22px]">notifications</span>
                            </button>
                            <Link
                                to="/profile"
                                className={`rounded-full bg-cover bg-center shadow-sm cursor-pointer shrink-0 transition-all duration-500 ${
                                    isCollapsed ? 'size-[48px]' : 'h-12 w-12'
                                }`}
                                style={{ backgroundImage: `url('${avatarUrl || "https://lh3.googleusercontent.com/aida-public/AB6AXuBTEclYR8F_pkLAtS8wLfPT3QVwCMd5RhwSJjSY28e1PF7nHKZDXgzGQ0FV4peEV087BZVCvaPbPbgxQMbz81RuIXy7-pk7sniURUZrLqeRD0xRcANqR5YixFMj2V0UzBi28Z8ASy0fcXdkZP9g6Ym3SqqcAxkkLmtY15vtYjB-AKPa3msQWCbQs9XGyqG65y_UH1UIj4MYVuguZhyot-H03zomY8toB-6TbkdZRgwZFeQt1ba2iBPCm5j73JqVjYGFr7n-a_QyoOHw"}')` }}
                            />
                        </div>
                    </nav>
                    {mobileMenuOpen && (
                        <div className="md:hidden pointer-events-auto absolute left-0 right-0 top-[84px]">
                            <div className="glass-panel !border-0 rounded-3xl p-3 shadow-[0_12px_30px_rgba(15,23,42,0.10),0_2px_8px_rgba(15,23,42,0.06)] dark:shadow-[0_14px_44px_rgba(0,0,0,0.55),0_4px_14px_rgba(0,0,0,0.30)] mx-4">
                                <div className="flex flex-col gap-2">
                                    {navItems.map((item) => {
                                        const isActive =
                                            (item.id === 'dashboard' && isDashboardActive) ||
                                            (item.id !== 'dashboard' && pathname === item.path);
                                        return (
                                            <Link
                                                key={item.id}
                                                to={item.path}
                                                onClick={() => setMobileMenuOpen(false)}
                                                className={`flex items-center gap-3 px-4 py-3 rounded-2xl text-base font-bold transition-all ${
                                                    isActive
                                                        ? 'bg-primary text-white shadow-glow'
                                                        : 'text-slate-600 hover:text-slate-900 hover:bg-white/50 dark:text-text-secondary dark:hover:text-white dark:hover:bg-white/5'
                                                }`}
                                            >
                                                <span className="material-symbols-outlined text-[20px]">{item.icon}</span>
                                                {item.label}
                                            </Link>
                                        );
                                    })}
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </header>
        </>
    );
};
