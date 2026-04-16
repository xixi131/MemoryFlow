import React, { useEffect, useRef, useState } from 'react';

interface TurnstileProps {
    siteKey: string;
    onVerify: (token: string) => void;
    onError?: () => void;
    onExpire?: () => void;
}

declare global {
    interface Window {
        turnstile: any;
    }
}

const CloudflareTurnstile: React.FC<TurnstileProps> = ({ siteKey, onVerify, onError, onExpire }) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const [theme, setTheme] = useState<'light' | 'dark'>('dark');
    const widgetId = useRef<string | null>(null);

    useEffect(() => {
        // Detect theme
        const updateTheme = () => {
            const isDark = document.documentElement.classList.contains('dark');
            setTheme(isDark ? 'dark' : 'light');
        };

        updateTheme();
        const observer = new MutationObserver(updateTheme);
        observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });

        return () => observer.disconnect();
    }, []);

    useEffect(() => {
        if (!containerRef.current) return;

        // Load script if not exists
        let script = document.getElementById('cf-turnstile-script') as HTMLScriptElement;
        if (!script) {
            script = document.createElement('script');
            script.id = 'cf-turnstile-script';
            script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
            script.async = true;
            script.defer = true;
            document.head.appendChild(script);
        }

        const renderWidget = () => {
            if (window.turnstile && containerRef.current) {
                // Clear previous widget if any
                if (widgetId.current) {
                    window.turnstile.remove(widgetId.current);
                }
                
                try {
                    widgetId.current = window.turnstile.render(containerRef.current, {
                        sitekey: siteKey,
                        theme: theme,
                        appearance: 'always',
                        callback: (token: string) => onVerify(token),
                        'error-callback': () => onError?.(),
                        'expired-callback': () => onExpire?.(),
                    });
                } catch (e) {
                    console.error("Turnstile render error:", e);
                }
            }
        };

        if (window.turnstile) {
            renderWidget();
        } else {
            script.onload = renderWidget;
        }

        return () => {
            if (window.turnstile && widgetId.current) {
                window.turnstile.remove(widgetId.current);
                widgetId.current = null;
            }
        };
    }, [siteKey, theme, onVerify, onError, onExpire]);

    return <div ref={containerRef} className="min-h-[65px] min-w-[300px] flex justify-start" />;
};

export default CloudflareTurnstile;
