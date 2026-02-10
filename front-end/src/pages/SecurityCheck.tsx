import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSecurityStore } from '../store/useSecurityStore';
import CloudflareTurnstile from '../components/CloudflareTurnstile';

const SecurityCheck: React.FC = () => {
    const navigate = useNavigate();
    const { setTurnstileToken, pendingAction, setPendingAction, returnPath } = useSecurityStore();
    const siteKey = import.meta.env.VITE_CLOUDFLARE_SITE_KEY;
    const [verifying, setVerifying] = useState(false);

    // If no pending action, redirect back to login
    useEffect(() => {
        if (!pendingAction) {
            navigate(returnPath || '/login', { replace: true });
        }
    }, [pendingAction, navigate, returnPath]);

    const handleVerify = async (token: string) => {
        if (verifying) return;
        setVerifying(true);
        
        // Update token in store
        setTurnstileToken(token);

        try {
            // Execute the pending action (e.g., login request)
            if (pendingAction) {
                await pendingAction();
            }
            // Reset pending action after success (optional, depending on flow)
            setPendingAction(null);
        } catch (error) {
            console.error("Action failed after verification", error);
            // If action failed, maybe redirect back to login or show error?
            // Usually the action itself (processLogin) handles error messaging
            // We just ensure we don't stay stuck here forever, or maybe we do allow retry?
            // For now, let's redirect back to returnPath to let user retry cleanly
            navigate(returnPath || '/login', { replace: true });
        } finally {
            setVerifying(false);
        }
    };

    return (
        <div className="flex flex-col justify-center items-center min-h-screen animate-fade-in px-8 md:px-24">
            <div className="transition-all text-left max-w-md w-full flex flex-col items-start">
                
                <h1 className="text-4xl font-extrabold text-slate-900 dark:text-white mb-4 tracking-tight">
                    MemoryFlow
                </h1>
                
                <p className="text-slate-500 dark:text-slate-400 text-sm mb-12">
                    需要确认您是否是人类
                </p>

                {/* Turnstile Widget */}
                <div className="w-full flex flex-col items-start mb-12 min-h-[65px]">
                    <CloudflareTurnstile 
                        siteKey={siteKey}
                        onVerify={handleVerify}
                    />
                    
                    {/* Verifying Shimmer Effect */}
                    {verifying && (
                        <p className="mt-2 ml-1 text-sm font-medium bg-gradient-to-r from-slate-500 via-slate-300 to-slate-500 dark:from-slate-400 dark:via-slate-100 dark:to-slate-400 bg-clip-text text-transparent bg-[length:200%_auto] animate-text-shimmer text-left">
                            正在验证...
                        </p>
                    )}
                </div>
            </div>
        </div>
    );
};

export default SecurityCheck;
