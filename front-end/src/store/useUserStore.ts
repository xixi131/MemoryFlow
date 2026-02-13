import { create } from 'zustand';
import { User } from '../types';
import userApis from '../api/userApis';
import { authService } from '../services/authService';
import { resolveApiAssetUrl } from '../utils/resolveApiAssetUrl';

interface UserState {
    user: User | null;
    isAuthenticated: boolean;
    isLoading: boolean;
    
    // Actions
    fetchUser: (force?: boolean) => Promise<void>;
    setUser: (user: User | null) => void;
    updateUser: (data: Partial<User>) => Promise<boolean>;
    logout: () => void;
}

export const useUserStore = create<UserState>((set, get) => ({
    user: null,
    isAuthenticated: !!localStorage.getItem('token'),
    isLoading: false,

    fetchUser: async (force = false) => {
        const { user, isLoading } = get();
        // If user already exists and not forced, don't fetch
        if (user && !force) return;
        
        // If already loading, avoid duplicate requests (basic debounce)
        if (isLoading) return;

        set({ isLoading: true });
        try {
            const res: any = await userApis.getUserInfo();
            if (res.code === 200) {
                const nextUser = res.data
                    ? { ...res.data, avatarUrl: resolveApiAssetUrl(res.data.avatarUrl) }
                    : res.data;
                set({ user: nextUser, isAuthenticated: true });
            } else {
                // If token invalid, might need logout
                set({ user: null }); // Don't auto logout here to avoid redirect loops, let interceptor handle 401
            }
        } catch (error) {
            console.error("Fetch user failed", error);
        } finally {
            set({ isLoading: false });
        }
    },

    setUser: (user) => set({ user, isAuthenticated: !!user }),

    updateUser: async (data) => {
        try {
            // Optimistic update
            const currentUser = get().user;
            if (currentUser) {
                const nextAvatarUrl = data.avatarUrl !== undefined ? resolveApiAssetUrl(data.avatarUrl) : currentUser.avatarUrl;
                set({ user: { ...currentUser, ...data, avatarUrl: nextAvatarUrl } });
            }

            const res: any = await authService.updateProfile(data);
            if (res.code === 200) {
                // Ensure server data is synced
                const nextUser = res.data
                    ? { ...res.data, avatarUrl: resolveApiAssetUrl(res.data.avatarUrl) }
                    : res.data;
                set({ user: nextUser });
                return true;
            }
            return false;
        } catch (error) {
            console.error("Update user failed", error);
            // Revert on failure (could implement more robust revert logic)
            get().fetchUser(true);
            return false;
        }
    },

    logout: () => {
        localStorage.removeItem('token');
        localStorage.removeItem('refreshToken');
        localStorage.removeItem('tokenExpiresAt');
        set({ user: null, isAuthenticated: false });
        authService.logout(); // Call backend logout
    }
}));
