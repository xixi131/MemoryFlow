import { create } from 'zustand';

interface SecurityState {
    turnstileToken: string | null;
    setTurnstileToken: (token: string | null) => void;
    pendingAction: (() => Promise<any>) | null;
    setPendingAction: (action: (() => Promise<any>) | null) => void;
    // Optional: Store the path to return to if action fails or is cancelled
    returnPath: string | null;
    setReturnPath: (path: string | null) => void;
}

export const useSecurityStore = create<SecurityState>((set) => ({
    turnstileToken: null,
    setTurnstileToken: (token) => set({ turnstileToken: token }),
    pendingAction: null,
    setPendingAction: (action) => set({ pendingAction: action }),
    returnPath: null,
    setReturnPath: (path) => set({ returnPath: path }),
}));
