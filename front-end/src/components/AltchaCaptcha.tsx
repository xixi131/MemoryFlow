import React, { useEffect, useRef } from 'react';
import 'altcha';
import type {} from 'altcha/types/react';
import type { WidgetAttributes, WidgetMethods } from 'altcha/types';
import { API_URL } from '../services/api';

interface AltchaCaptchaProps {
    onVerify: (payload: string) => void;
    onError: (message: string) => void;
}

interface AltchaStateChangeEvent extends Event {
    detail?: {
        payload?: string;
        error?: string;
    };
}

const AltchaCaptcha: React.FC<AltchaCaptchaProps> = ({ onVerify, onError }) => {
    const widgetRef = useRef<(WidgetAttributes & WidgetMethods & HTMLElement) | null>(null);
    const handledRef = useRef(false);
    const onVerifyRef = useRef(onVerify);
    const onErrorRef = useRef(onError);

    useEffect(() => {
        onVerifyRef.current = onVerify;
        onErrorRef.current = onError;
    }, [onVerify, onError]);

    useEffect(() => {
        const widget = widgetRef.current;
        if (!widget) return;

        const handleStateChange = (event: Event) => {
            const detail = (event as AltchaStateChangeEvent).detail;
            if (detail?.payload && !handledRef.current) {
                handledRef.current = true;
                onVerifyRef.current(detail.payload);
            } else if (detail?.error) {
                onErrorRef.current('安全验证未完成，请刷新后重试。');
            }
        };

        widget.addEventListener('statechange', handleStateChange);
        return () => widget.removeEventListener('statechange', handleStateChange);
    }, []);

    return (
        <altcha-widget
            ref={widgetRef}
            challenge={`${API_URL}/auth/captcha/challenge`}
            auto="onload"
            type="checkbox"
            language="zh"
            configuration={JSON.stringify({ minDuration: 700, timeout: 60000 })}
            style={{
                '--altcha-max-width': '100%',
                '--altcha-border-radius': '10px',
                '--altcha-border-width': '1px',
                '--altcha-border-color': '#cbd5e1',
                '--altcha-padding': '18px 20px',
                '--altcha-checkbox-size': '34px',
                '--altcha-checkbox-border-radius': '8px',
                '--altcha-color-base': '#ffffff',
                '--altcha-color-base-content': '#0f172a',
                '--altcha-shadow': 'none',
            } as React.CSSProperties}
        />
    );
};

export default AltchaCaptcha;
