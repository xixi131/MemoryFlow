import React, { useState, useEffect, useCallback } from 'react';

// Message types
export type MessageType = 'success' | 'error' | 'info' | 'warning' | 'loading';

export interface Message {
    id: string;
    type: MessageType;
    content: string;
    duration?: number;
    closing?: boolean;
}

// Internal state management (simple pub/sub)
type Listener = (messages: Message[]) => void;
let messages: Message[] = [];
let listeners: Listener[] = [];

const notifyListeners = () => {
    listeners.forEach(listener => listener([...messages]));
};

// Message Service - Pure TS API
export const message = {
    show: (content: string, type: MessageType = 'info', duration = 3000) => {
        const id = Date.now().toString() + Math.random().toString(36).substring(2);
        const newMessage: Message = { id, type, content, duration };
        
        messages = [...messages, newMessage];
        notifyListeners();

        if (duration > 0) {
            setTimeout(() => {
                message.remove(id);
            }, duration);
        }
        
        return id;
    },
    
    success: (content: string, duration = 3000) => message.show(content, 'success', duration),
    error: (content: string, duration = 3000) => message.show(content, 'error', duration),
    info: (content: string, duration = 3000) => message.show(content, 'info', duration),
    warning: (content: string, duration = 3000) => message.show(content, 'warning', duration),
    loading: (content: string, duration = 0) => message.show(content, 'loading', duration),
    
    remove: (id: string) => {
        const index = messages.findIndex(msg => msg.id === id);
        if (index !== -1) {
            // Trigger exit animation
            messages[index] = { ...messages[index], closing: true };
            notifyListeners();

            // Wait for animation to finish before removing from DOM
            setTimeout(() => {
                messages = messages.filter(msg => msg.id !== id);
                notifyListeners();
            }, 500); // Matches CSS duration
        }
    }
};

// Message Component (Container)
export const MessageContainer: React.FC = () => {
    const [msgList, setMsgList] = useState<Message[]>(messages);

    useEffect(() => {
        const listener = (newMessages: Message[]) => {
            setMsgList(newMessages);
        };
        listeners.push(listener);
        return () => {
            listeners = listeners.filter(l => l !== listener);
        };
    }, []);

    if (msgList.length === 0) return null;

    return (
        <div className="fixed top-6 left-1/2 -translate-x-1/2 z-[100] flex flex-col gap-3 pointer-events-none w-full max-w-md px-4 h-0 overflow-visible">
            {msgList.map((msg) => (
                <MessageItem key={msg.id} message={msg} />
            ))}
        </div>
    );
};

const MessageItem: React.FC<{ message: Message }> = ({ message: msg }) => {
    const [isMounted, setIsMounted] = useState(false);

    useEffect(() => {
        // Animation in
        requestAnimationFrame(() => setIsMounted(true));
    }, []);

    const visible = isMounted && !msg.closing;

    const getIcon = (type: MessageType) => {
        switch (type) {
            case 'success': return 'check_circle';
            case 'error': return 'error';
            case 'warning': return 'warning';
            case 'loading': return 'progress_activity';
            default: return 'info';
        }
    };

    const getColorClass = (type: MessageType) => {
        switch (type) {
            case 'success': return 'text-accent-green';
            case 'error': return 'text-accent-coral';
            case 'warning': return 'text-amber-500';
            case 'loading': return 'text-blue-500';
            default: return 'text-primary';
        }
    };

    return (
        <div 
            className={`
                pointer-events-auto glass-panel px-5 py-4 rounded-2xl shadow-xl shadow-black/5 dark:shadow-black/20 border border-slate-200/60 dark:border-white/10 
                flex items-center gap-4 transition-all duration-500 ease-[cubic-bezier(0.34,1.56,0.64,1)] transform origin-top
                ${visible ? 'translate-y-0 opacity-100 scale-100' : '-translate-y-4 opacity-0 scale-90 blur-sm'}
                min-w-[320px] backdrop-blur-xl bg-white/70 dark:bg-[#0F172A]/70
            `}
        >
            <div className={`size-10 rounded-full flex items-center justify-center shrink-0 ${
                msg.type === 'success' ? 'bg-green-500/10 text-green-500' :
                msg.type === 'error' ? 'bg-red-500/10 text-red-500' :
                msg.type === 'warning' ? 'bg-amber-500/10 text-amber-500' :
                msg.type === 'loading' ? 'bg-blue-500/10 text-blue-500' :
                'bg-blue-500/10 text-blue-500'
            }`}>
                <span className={`material-symbols-outlined text-[22px] ${msg.type === 'loading' ? 'animate-spin' : ''}`}>
                    {getIcon(msg.type)}
                </span>
            </div>
            
            <div className="flex flex-col gap-0.5">
                <span className="text-slate-900 dark:text-white text-sm font-bold tracking-tight leading-none">
                    {msg.type === 'success' ? 'Success' :
                     msg.type === 'error' ? 'Error' :
                     msg.type === 'warning' ? 'Warning' : 
                     msg.type === 'loading' ? 'Loading' : 'Notification'}
                </span>
                <span className="text-slate-500 dark:text-slate-400 text-xs font-medium leading-tight">
                    {msg.content}
                </span>
            </div>
        </div>
    );
};
