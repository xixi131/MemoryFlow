import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { authService } from '../services/authService';
import { message } from '../components/Message';
import { useSecurityStore } from '../store/useSecurityStore';

export const Register: React.FC<{ setView: (v: string) => void }> = ({ setView }) => {
    const navigate = useNavigate();
    const { setPendingAction, setReturnPath } = useSecurityStore();
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [nickname, setNickname] = useState('');
    const [code, setCode] = useState('');
    const [loading, setLoading] = useState(false);
    const [countdown, setCountdown] = useState(0);

    const handleSendCode = async () => {
        if (!email) return message.warning("请输入邮箱");
        if (countdown > 0) return;

        try {
            const res = await authService.sendCode(email, 'register');
            if (res.code === 200) {
                message.success("验证码已发送");
                setCountdown(60);
                const timer = setInterval(() => {
                    setCountdown(prev => {
                        if (prev <= 1) {
                            clearInterval(timer);
                            return 0;
                        }
                        return prev - 1;
                    });
                }, 1000);
            } else {
                message.error(res.message || "发送失败");
            }
        } catch (e: any) {
            console.error("Send code error", e);
            // 修复: 只有当后端明确返回 4xx/5xx 且有 message 时才显示错误信息
            // 否则对于 400 Bad Request 等情况，可能 e.response.data.message 就是后端的错误提示
            const errorMsg = e.response?.data?.message || "发送失败，请稍后重试";
            message.error(errorMsg);
        }
    };

    const handleRegister = async () => {
        if (!email || !password || !nickname || !code) return message.warning("请填写所有字段");
        if (password !== confirmPassword) return message.warning("两次输入的密码不一致");

        // Password complexity validation
        const passwordRegex = /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,20}$/;
        if (!passwordRegex.test(password)) {
            return message.warning("密码需要包含字母和数字，长度8-20位");
        }

        // Setup pending action for security check
        setPendingAction(processRegister);
        setReturnPath('/register');
        navigate('/security-check');
    };

    const processRegister = async () => {
        setLoading(true);
        try {
            const res = await authService.register({ email, password, nickname, code });
            if (res.code === 200) {
                message.success("注册成功，请登录");
                setView('login');
            } else {
                message.error("注册失败: " + res.message);
            }
        } catch (e: any) {
            console.error("Register error", e);
            const errorMsg = e.response?.data?.message || "注册失败，请重试";
            // If there are specific validation errors
            if (e.response?.data?.data && typeof e.response.data.data === 'object') {
                 const firstError = Object.values(e.response.data.data)[0] as string;
                 message.error(firstError || errorMsg);
            } else {
                message.error(errorMsg);
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="flex items-center justify-center min-h-screen animate-fade-in px-4">
            <div className="p-12 transition-all text-center max-w-md w-full">
                <h1 className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-indigo-600 dark:from-blue-400 dark:to-indigo-400 mb-2">MemoryFlow</h1>
                <h2 className="text-2xl font-bold text-slate-900 dark:text-white mb-6">注册</h2>
                <div className="flex flex-col gap-4 text-left">
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">昵称</label>
                        <input
                            type="text"
                            value={nickname}
                            onChange={(e) => setNickname(e.target.value)}
                            className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                            placeholder="Your Name"
                        />
                    </div>
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
                    
                    {/* 验证码输入框 */}
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">验证码</label>
                        <div className="flex gap-3">
                            <input
                                type="text"
                                value={code}
                                onChange={(e) => setCode(e.target.value)}
                                className="flex-1 bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                                placeholder="6位验证码"
                            />
                            <button
                                onClick={handleSendCode}
                                disabled={countdown > 0 || !email}
                                className="px-4 rounded-2xl bg-blue-100 text-blue-600 font-bold hover:bg-blue-200 disabled:opacity-50 disabled:cursor-not-allowed whitespace-nowrap transition-colors dark:bg-blue-900/30 dark:text-blue-400"
                            >
                                {countdown > 0 ? `${countdown}s` : '发送验证码'}
                            </button>
                        </div>
                    </div>

                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">密码</label>
                        <input
                            type="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                            placeholder="至少 8 位"
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">确认密码</label>
                        <input
                            type="password"
                            value={confirmPassword}
                            onChange={(e) => setConfirmPassword(e.target.value)}
                            className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                            placeholder="再次输入密码"
                        />
                    </div>
                </div>
                <div className="flex items-center justify-between mt-4 text-sm">
                    <button onClick={() => setView('login')} className="text-slate-500 dark:text-text-secondary hover:text-primary dark:hover:text-white transition-colors">已有账号？登录</button>
                    <span className="text-slate-400 dark:text-slate-500">注册即表示同意服务条款</span>
                </div>
                <button
                    onClick={handleRegister}
                    disabled={loading}
                    className="w-full mt-6 py-3 rounded-xl bg-primary text-white font-bold hover:bg-blue-600 transition-all shadow-glow disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    {loading ? '注册中...' : '注册'}
                </button>
            </div>
        </div>
    );
};
