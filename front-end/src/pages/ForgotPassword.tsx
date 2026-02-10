import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { authService } from '../services/authService';
import { message } from '../components/Message';
import logo from '../assets/logo-memoryflow.png';
import { useSecurityStore } from '../store/useSecurityStore';

export const ForgotPassword: React.FC<{ setView: (v: string) => void }> = ({ setView }) => {
    const navigate = useNavigate();
    const { setPendingAction, setReturnPath } = useSecurityStore();
    const [email, setEmail] = useState('');
    const [code, setCode] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    
    const [loading, setLoading] = useState(false);
    const [sendingCode, setSendingCode] = useState(false);
    const [countdown, setCountdown] = useState(0);

    useEffect(() => {
        let timer: NodeJS.Timeout;
        if (countdown > 0) {
            timer = setInterval(() => {
                setCountdown((prev) => prev - 1);
            }, 1000);
        }
        return () => clearInterval(timer);
    }, [countdown]);

    const handleSendCode = async () => {
        if (!email) return message.warning("请输入邮箱");
        if (countdown > 0) return;

        setPendingAction(processSendCode);
        setReturnPath('/forgot-password');
        navigate('/security-check');
    };

    const processSendCode = async () => {
        setSendingCode(true);
        try {
            const res = await authService.sendCode(email);
            if (res.code === 200) {
                message.success("验证码已发送，请查收邮件");
                setCountdown(60);
            } else {
                message.error(res.message || "发送失败");
            }
        } catch (e) {
            console.error("Send code error", e);
            message.error("发送失败，请稍后重试");
        } finally {
            setSendingCode(false);
        }
    };

    const handleSubmit = async () => {
        if (!email || !code || !newPassword || !confirmPassword) {
            return message.warning("请填写所有字段");
        }
        if (newPassword !== confirmPassword) {
            return message.warning("两次输入的密码不一致");
        }

        setPendingAction(processSubmit);
        setReturnPath('/forgot-password');
        navigate('/security-check');
    };

    const processSubmit = async () => {
        setLoading(true);
        try {
            const res = await authService.resetPassword({
                email,
                code,
                newPassword
            });
            if (res.code === 200) {
                message.success("密码重置成功，请重新登录");
                setTimeout(() => {
                    setView('login');
                }, 1000);
            } else {
                message.error(res.message || "重置失败");
            }
        } catch (e) {
            console.error("Reset password error", e);
            message.error("重置失败，请稍后重试");
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="flex items-center justify-center min-h-screen animate-fade-in px-4">
            <div className="p-12 transition-all text-center max-w-md w-full">
                <h1 className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-indigo-600 dark:from-blue-400 dark:to-indigo-400 mb-2">MemoryFlow</h1>
                <h2 className="text-2xl font-bold text-slate-900 dark:text-white mb-6">重置密码</h2>
                
                <div className="flex flex-col gap-4 text-left">
                    {/* Email */}
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">邮箱</label>
                        <div className="relative">
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                                placeholder="name@example.com"
                            />
                            <button
                                onClick={handleSendCode}
                                disabled={sendingCode || countdown > 0}
                                className="absolute right-2 top-2 bottom-2 px-4 rounded-xl bg-primary/10 text-primary text-sm font-bold hover:bg-primary/20 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                            >
                                {countdown > 0 ? `${countdown}s` : (sendingCode ? '发送中...' : '发送验证码')}
                            </button>
                        </div>
                    </div>

                    {/* Code */}
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">验证码</label>
                        <input
                            type="text"
                            value={code}
                            onChange={(e) => setCode(e.target.value)}
                            className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                            placeholder="6位验证码"
                        />
                    </div>

                    {/* New Password */}
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">新密码</label>
                        <input
                            type="password"
                            value={newPassword}
                            onChange={(e) => setNewPassword(e.target.value)}
                            className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                            placeholder="••••••••"
                        />
                    </div>

                    {/* Confirm Password */}
                    <div className="flex flex-col gap-2">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">确认新密码</label>
                        <input
                            type="password"
                            value={confirmPassword}
                            onChange={(e) => setConfirmPassword(e.target.value)}
                            className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-2xl px-5 py-4 text-lg text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                            placeholder="••••••••"
                        />
                    </div>
                </div>

                <button
                    onClick={handleSubmit}
                    disabled={loading}
                    className="w-full mt-8 py-3 rounded-xl bg-primary text-white font-bold hover:bg-blue-600 transition-all shadow-glow disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    {loading ? '提交中...' : '重置密码'}
                </button>

                <div className="mt-6">
                    <button 
                        onClick={() => setView('login')} 
                        className="text-slate-500 dark:text-text-secondary hover:text-primary dark:hover:text-white transition-colors text-sm font-medium"
                    >
                        返回登录
                    </button>
                </div>
            </div>
        </div>
    );
};
