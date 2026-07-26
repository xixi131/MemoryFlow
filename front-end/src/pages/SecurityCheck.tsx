import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSecurityStore } from '../store/useSecurityStore';
import AltchaCaptcha from '../components/AltchaCaptcha';

const SecurityCheck: React.FC = () => {
    const navigate = useNavigate();
    const { setCaptchaProof, pendingAction, setPendingAction, returnPath } = useSecurityStore();
    const [verifying, setVerifying] = useState(false);
    const [errorMessage, setErrorMessage] = useState('');

    // If no pending action, redirect back to login
    useEffect(() => {
        if (!pendingAction) {
            navigate(returnPath || '/login', { replace: true });
        }
    }, [pendingAction, navigate, returnPath]);

    const handleVerify = async (payload: string) => {
        if (verifying) return;
        setVerifying(true);
        
        setErrorMessage('');
        setCaptchaProof(payload);

        try {
            // Execute the pending action (e.g., login request)
            if (pendingAction) {
                const result = await pendingAction();
                const redirectTo = result?.redirectTo;
                if (redirectTo) {
                    navigate(redirectTo, { replace: true });
                } else {
                    navigate(returnPath || '/login', { replace: true });
                }
            }
            // Reset pending action after success (optional, depending on flow)
            setPendingAction(null);
        } catch (error) {
            console.error("Action failed after verification", error);
            setCaptchaProof(null);
            // If action failed, maybe redirect back to login or show error?
            // Usually the action itself (processLogin) handles error messaging
            // We just ensure we don't stay stuck here forever, or maybe we do allow retry?
            // For now, let's redirect back to returnPath to let user retry cleanly
            navigate(returnPath || '/login', { replace: true });
        } finally {
            setVerifying(false);
        }
    };

    const handleCaptchaError = (message: string) => {
        setCaptchaProof(null);
        setErrorMessage(message);
    };

    return (
        <div className="flex flex-col justify-center items-center min-h-screen animate-fade-in px-8 md:px-24">
            <div className="transition-all text-left max-w-xl w-full flex flex-col items-start">
                
                <h1 className="text-5xl font-extrabold text-slate-900 dark:text-white mb-3 tracking-tight">
                    MemoryFlow
                </h1>
                
                <p className="text-slate-500 dark:text-slate-400 text-base mb-9">
                    需要确认您是否是人类
                </p>

                <div className="w-full min-h-[154px] border border-slate-200 bg-white/80 px-6 py-6 shadow-sm dark:border-slate-700 dark:bg-slate-900/70">
                    <p className="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-4">安全验证</p>
                    <AltchaCaptcha
                        onVerify={handleVerify}
                        onError={handleCaptchaError}
                    />
                    {verifying && (
                        <p className="mt-4 text-sm font-medium text-slate-500 dark:text-slate-300">
                            正在验证...
                        </p>
                    )}
                    {errorMessage && !verifying && (
                        <p className="mt-4 text-sm text-red-600 dark:text-red-400">{errorMessage}</p>
                    )}
                </div>
            </div>
        </div>
    );
};

export default SecurityCheck;
