import React, { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { authService } from '../services/authService';
import { message } from '../components/Message';
import { useSecurityStore } from '../store/useSecurityStore';

export const Login: React.FC<{ setView: (v: string) => void }> = ({ setView }) => {
    const location = useLocation();
    const navigate = useNavigate();
    const { setPendingAction, setReturnPath } = useSecurityStore();
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [desktopRedirecting, setDesktopRedirecting] = useState(false);

    const [isConnecting, setIsConnecting] = useState(true); // New state to track connection status

    // Check if already logged in and needs desktop callback
    useEffect(() => {
        const token = localStorage.getItem('token');
        const params = new URLSearchParams(location.search);
        
        if (token && params.get('callback') === 'desktop') {
            // Already logged in, show connecting state immediately
            setDesktopRedirecting(true);
            setIsConnecting(true); // Start with connecting state
            
            // Wait a bit to ensure UI renders
            setTimeout(() => {
                // Try to wake up desktop app
                window.location.href = `memoryflow://callback?token=${token}`;
                
                // After attempting to connect, show success state
                setTimeout(() => {
                    setIsConnecting(false);
                }, 2000);
            }, 1000);
        }
    }, []);

    const handleLogin = async () => {
        if (!email || !password) return message.warning("Please enter email and password");
        
        // Setup pending action for security check
        setPendingAction(processLogin);
        setReturnPath('/login');
        navigate('/security-check');
    };

    const processLogin = async () => {
        setLoading(true);
        try {
            const res = await authService.login({ email, password });
            if (res.code === 200) {
                if (res.data.accessToken) {
                    localStorage.setItem('token', res.data.accessToken);
                    
                    // Check for desktop callback
                    const params = new URLSearchParams(location.search);
                    if (params.get('callback') === 'desktop') {
                        setDesktopRedirecting(true);
                        setIsConnecting(true); // Start connecting
                        
                        window.location.href = `memoryflow://callback?token=${res.data.accessToken}`;
                        
                        // Show success after a delay
                        setTimeout(() => {
                            setIsConnecting(false);
                        }, 2000);
                        return; 
                    }
                }
                message.success("登录成功");
                setTimeout(() => {
                    // Check for admin role or specific email
                    if (res.data.user && (res.data.user.role === 'ADMIN' || res.data.user.email === 'admin@gmail.com')) {
                        setView('admin');
                    } else {
                        setView('dashboard');
                    }
                }, 500);
            } else {
                message.error("Login failed: " + res.message);
            }
        } catch (e) {
            console.error("Login error", e);
            message.error("Login failed. Please check your credentials.");
        } finally {
            setLoading(false);
        }
    };

    if (desktopRedirecting) {
        if (isConnecting) {
            // Connecting State (Blue Icon)
            return (
                <div className="flex flex-col items-center justify-center min-h-screen bg-[#F8FAFC] text-slate-900 px-4 animate-fade-in font-sans selection:bg-blue-500/20">
                     <div className="bg-white p-8 rounded-3xl shadow-xl shadow-slate-200/50 flex flex-col items-center max-w-sm w-full border border-slate-100">
                        <div className="w-16 h-16 bg-blue-50 rounded-2xl flex items-center justify-center mb-6 animate-pulse">
                            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-blue-600">
                                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" strokeLinecap="round" strokeLinejoin="round"/>
                            </svg>
                        </div>
                        <h2 className="text-xl font-bold text-slate-900 mb-2">正在连接桌面组件...</h2>
                        <p className="text-slate-500 text-sm text-center mb-6">请在浏览器弹出的对话框中点击<br/>“打开 MemoryFlow”</p>
                        
                        <div className="flex gap-2">
                            <div className="w-2 h-2 rounded-full bg-blue-500 animate-bounce"></div>
                            <div className="w-2 h-2 rounded-full bg-blue-500 animate-bounce delay-100"></div>
                            <div className="w-2 h-2 rounded-full bg-blue-500 animate-bounce delay-200"></div>
                        </div>

                        <button 
                            onClick={() => setDesktopRedirecting(false)}
                            className="mt-8 text-xs text-slate-400 hover:text-blue-600 transition-colors"
                        >
                            返回登录页
                        </button>
                    </div>
                </div>
            );
        }

        // Success State (Green Check)
        return (
            <div className="flex flex-col items-center justify-center min-h-screen bg-[#F8FAFC] text-slate-900 px-4 animate-fade-in font-sans selection:bg-blue-500/20">
                {/* Icons Container */}
                <div className="flex items-center gap-4 md:gap-8 mb-12 relative">
                    {/* Web Icon Box */}
                    <div className="w-24 h-24 md:w-32 md:h-32 bg-white rounded-3xl flex items-center justify-center border border-slate-200 shadow-xl shadow-slate-200/50 relative group transition-transform hover:-translate-y-1 duration-300">
                        <div className="absolute inset-0 bg-gradient-to-br from-blue-50/50 to-transparent rounded-3xl opacity-0 group-hover:opacity-100 transition-opacity"></div>
                        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="text-slate-700">
                            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                            <line x1="3" y1="9" x2="21" y2="9"></line>
                            <line x1="9" y1="21" x2="9" y2="9"></line>
                        </svg>
                    </div>

                    {/* Connection Line */}
                    <div className="flex items-center gap-1 md:gap-2">
                        <div className="w-1.5 h-1.5 bg-slate-300 rounded-full"></div>
                        <div className="w-1.5 h-1.5 bg-slate-300 rounded-full"></div>
                        <div className="w-1.5 h-1.5 bg-slate-300 rounded-full"></div>
                        
                        {/* Checkmark */}
                        <div className="w-10 h-10 rounded-full bg-[#10B981] flex items-center justify-center shadow-[0_4px_12px_rgba(16,185,129,0.3)] mx-2 animate-scale-in border-4 border-[#F8FAFC]">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" className="text-white">
                                <polyline points="20 6 9 17 4 12"></polyline>
                            </svg>
                        </div>

                        <div className="w-1.5 h-1.5 bg-slate-300 rounded-full"></div>
                        <div className="w-1.5 h-1.5 bg-slate-300 rounded-full"></div>
                        <div className="w-1.5 h-1.5 bg-slate-300 rounded-full"></div>
                    </div>

                    {/* App Icon Box */}
                    <div className="w-24 h-24 md:w-32 md:h-32 bg-white rounded-3xl flex items-center justify-center border border-slate-200 shadow-xl shadow-slate-200/50 relative group transition-transform hover:-translate-y-1 duration-300 delay-75">
                        <div className="absolute inset-0 bg-gradient-to-br from-blue-50/50 to-transparent rounded-3xl opacity-0 group-hover:opacity-100 transition-opacity"></div>
                        <span className="text-4xl md:text-6xl font-black text-transparent bg-clip-text bg-gradient-to-br from-blue-600 to-indigo-600">M</span>
                    </div>
                </div>

                {/* Text Content */}
                <h1 className="text-3xl md:text-4xl font-bold mb-4 tracking-tight text-slate-900">
                    登录成功
                </h1>
                <p className="text-slate-500 text-base md:text-lg text-center max-w-lg leading-relaxed font-medium">
                    您现在可以关闭此窗口并返回使用 <span className="text-blue-600 font-bold">MemoryFlow</span>
                </p>

                {/* Close Button */}
                <button 
                    onClick={() => window.close()}
                    className="mt-12 px-8 py-2.5 rounded-full bg-white hover:bg-slate-50 text-slate-600 text-sm font-semibold transition-all border border-slate-200 hover:border-slate-300 hover:shadow-md active:scale-95"
                >
                    关闭窗口
                </button>
            </div>
        );
    }

    return (
        <div className="flex items-center justify-center min-h-screen animate-fade-in px-4">
            <div className="p-12 transition-all text-center max-w-md w-full">
                <h1 className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-indigo-600 dark:from-blue-400 dark:to-indigo-400 mb-2">MemoryFlow</h1>
                <h2 className="text-2xl font-bold text-slate-900 dark:text-white mb-6">登录</h2>
                <div className="flex flex-col gap-4 text-left">
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">邮箱</label>
                        <input
                            type="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                            placeholder="name@example.com"
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">密码</label>
                        <input
                            type="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                            placeholder="••••••••"
                        />
                    </div>
                </div>
                <div className="flex items-center justify-between mt-4 text-sm">
                    <button onClick={() => setView('register')} className="text-slate-500 dark:text-text-secondary hover:text-primary dark:hover:text-white transition-colors">没有账号？注册</button>
                    <button onClick={() => setView('forgot-password')} className="text-slate-500 dark:text-text-secondary hover:text-primary dark:hover:text-white transition-colors">忘记密码</button>
                </div>
                <button
                    onClick={handleLogin}
                    disabled={loading}
                    className="w-full mt-6 py-3 rounded-xl bg-primary text-white font-bold hover:bg-blue-600 transition-all shadow-glow disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    {loading ? '登录中...' : '登录'}
                </button>
            </div>
        </div>
    );
};
