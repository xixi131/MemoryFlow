import { create } from 'zustand';
import subjectApis from '../services/subjectApis';

interface SubjectState {
    // Key: subjectId
    subjectDetails: Record<string, {
        data: any; // The full subject detail including chapters/points
        lastFetched: number;
    }>;
    loadingDetails: Record<string, boolean>;

    // Actions
    fetchSubjectDetail: (subjectId: string, force?: boolean) => Promise<void>;
}

// const CACHE_DURATION = 5 * 60 * 1000; 

export const useSubjectStore = create<SubjectState>((set, get) => ({
    subjectDetails: {},
    loadingDetails: {},

    fetchSubjectDetail: async (subjectId, force = false) => {
        const { subjectDetails, loadingDetails } = get();
        const now = Date.now();
        const cached = subjectDetails[subjectId];

        console.log(`[SubjectStore] Fetching detail for ${subjectId}. Force: ${force}, Cached: ${!!cached}, Loading: ${!!loadingDetails[subjectId]}`);

        // 1. Check Cache
        if (!force && cached) {
            console.log(`[SubjectStore] Cache hit for ${subjectId}`);
            return;
        }

        // 2. Check Deduplication
        if (!force && loadingDetails[subjectId]) {
            console.log(`[SubjectStore] Request already in progress for ${subjectId}, skipping duplicate.`);
            return;
        }

        console.log(`[SubjectStore] Cache miss/expired for ${subjectId}, fetching from API...`);

        set((state) => ({
            loadingDetails: { ...state.loadingDetails, [subjectId]: true }
        }));

        try {
            const res: any = await subjectApis.getSubjectDetail(subjectId);
            if (res.code === 200) {
                console.log(`[SubjectStore] Successfully fetched detail for ${subjectId}`);
                set((state) => ({
                    subjectDetails: {
                        ...state.subjectDetails,
                        [subjectId]: {
                            data: res.data,
                            lastFetched: now
                        }
                    },
                    loadingDetails: { ...state.loadingDetails, [subjectId]: false }
                }));
            } else {
                 set((state) => ({
                    loadingDetails: { ...state.loadingDetails, [subjectId]: false }
                }));
            }
        } catch (error) {
            console.error("Fetch subject detail failed", error);
            set((state) => ({
                loadingDetails: { ...state.loadingDetails, [subjectId]: false }
            }));
        }
    }
}));
