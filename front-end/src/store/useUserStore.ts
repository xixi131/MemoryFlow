import { create } from 'zustand';
import { User } from '../types';
import userApis from '../api/userApis';
import { authService } from '../services/authService';

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
                set({ user: res.data, isAuthenticated: true });
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
                set({ user: { ...currentUser, ...data } });
            }

            const res: any = await authService.updateProfile(data);
            if (res.code === 200) {
                // Ensure server data is synced
                set({ user: res.data });
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
        set({ user: null, isAuthenticated: false });
        authService.logout(); // Call backend logout
    }
}));
