import { create } from 'zustand';
import settingsApis from '../services/settingsApis';

interface SettingsState {
    settings: any;
    lastFetched: number;
    isLoading: boolean;
    
    // Actions
    fetchSettings: (force?: boolean) => Promise<void>;
    updateSettings: (data: any) => Promise<void>;
}

// const CACHE_DURATION = 10 * 60 * 1000; 

export const useSettingsStore = create<SettingsState>((set, get) => ({
    settings: null,
    lastFetched: 0,
    isLoading: false,

    fetchSettings: async (force = false) => {
        const { lastFetched, isLoading, settings } = get();
        const now = Date.now();

        // 1. Check Cache
        if (!force && settings) {
            console.log(`[SettingsStore] Cache hit`);
            return;
        }

        // 2. Check Active Request (Basic lock using isLoading)
        if (isLoading) {
            console.log(`[SettingsStore] Request already in progress, skipping duplicate.`);
            return;
        }

        console.log(`[SettingsStore] Cache miss/expired, fetching from API...`);
        set({ isLoading: true });

        try {
            const res: any = await settingsApis.getSettings();
            if (res.code === 200) {
                console.log(`[SettingsStore] Successfully fetched settings`);
                set({ settings: res.data, lastFetched: now });
            }
        } catch (error) {
            console.error("Fetch settings failed", error);
        } finally {
            set({ isLoading: false });
        }
    },

    updateSettings: async (data) => {
        // Optimistic update
        set((state) => ({ settings: { ...state.settings, ...data } }));
        try {
            await settingsApis.updateSettings(data);
            // Optionally refetch or update with response
        } catch (error) {
            console.error("Update settings failed", error);
            // Revert logic could be added here
        }
    }
}));
