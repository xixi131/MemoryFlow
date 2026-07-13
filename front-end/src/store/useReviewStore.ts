import { create } from 'zustand';
import dashboardApis, { DashboardSummary } from '../services/dashboardApis';
import subjectApis from '../services/subjectApis';

interface ReviewState {
    summary: DashboardSummary | null;
    reviews: any[]; // Pending reviews for Widgets
    lastFetchedSummary: number;
    lastFetchedReviews: number;
    isLoadingSummary: boolean;
    isLoadingReviews: boolean;
    
    // Actions
    fetchSummary: (force?: boolean) => Promise<void>;
    fetchReviews: (force?: boolean) => Promise<void>;
    
    // Optimistic updates for Widgets
    completeReview: (pointId: string) => void;
    revertReview: (pointId: string) => void;
}

// const SUMMARY_CACHE_TIME = 5 * 60 * 1000; 
// const REVIEWS_CACHE_TIME = 5 * 60 * 1000; 

export const useReviewStore = create<ReviewState>((set, get) => ({
    summary: null,
    reviews: [],
    lastFetchedSummary: 0,
    lastFetchedReviews: 0,
    isLoadingSummary: false,
    isLoadingReviews: false,

    fetchSummary: async (force = false) => {
        const { lastFetchedSummary, summary, isLoadingSummary } = get();
        const now = Date.now();

        // Check Cache (Valid if not forced, data exists)
        if (!force && lastFetchedSummary > 0) {
            return;
        }

        if (isLoadingSummary) return;

        set({ isLoadingSummary: true });
        try {
            const res: any = await dashboardApis.getSummary();
            if (res.code === 200) {
                set({ summary: res.data, lastFetchedSummary: now });
            }
        } catch (error) {
            console.error("Fetch summary failed", error);
        } finally {
            set({ isLoadingSummary: false });
        }
    },

    fetchReviews: async (force = false) => {
        const { lastFetchedReviews, reviews, isLoadingReviews } = get();
        const now = Date.now();

        // Check Cache (Valid if not forced, recently fetched)
        // Note: We check lastFetchedReviews > 0 to ensure we have fetched at least once.
        if (!force && lastFetchedReviews > 0) {
            return;
        }

        if (isLoadingReviews) return;

        set({ isLoadingReviews: true });
        try {
            const res: any = await subjectApis.getPendingReviews();
            if (res.code === 200) {
                const date = new Date();
                const year = date.getFullYear();
                const month = String(date.getMonth() + 1).padStart(2, '0');
                const day = String(date.getDate()).padStart(2, '0');
                const todayStr = `${year}-${month}-${day}`;

                const data = res.data.map((r: any) => ({
                    ...r,
                    completedLocal: r.lastReviewAt && r.lastReviewAt.startsWith(todayStr) && (r.reviewCompleted || (r.nextReviewDate && r.nextReviewDate > todayStr))
                }));
                set({ reviews: data, lastFetchedReviews: now });
            }
        } catch (error) {
            console.error("Fetch reviews failed", error);
        } finally {
             set({ isLoadingReviews: false });
        }
    },

    completeReview: (pointId) => {
        set((state) => ({
            reviews: state.reviews.map(r => 
                String(r.id) === String(pointId) ? { ...r, completedLocal: true } : r
            ),
            // Optionally update summary counts locally
            summary: state.summary ? {
                ...state.summary,
                completedReviewCount: state.summary.completedReviewCount + 1,
                pendingReviewCount: Math.max(0, state.summary.pendingReviewCount - 1)
            } : null
        }));
    },

    revertReview: (pointId) => {
        set((state) => ({
            reviews: state.reviews.map(r => 
                String(r.id) === String(pointId) ? { ...r, completedLocal: false } : r
            ),
             // Optionally update summary counts locally
             summary: state.summary ? {
                ...state.summary,
                completedReviewCount: Math.max(0, state.summary.completedReviewCount - 1),
                pendingReviewCount: state.summary.pendingReviewCount + 1
            } : null
        }));
    }
}));
