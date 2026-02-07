import { create } from 'zustand';
import { Goal, Subject } from '../types';
import goalApis from '../services/goalApis';

interface GoalState {
    goals: Goal[];
    lastFetched: number;
    isLoading: boolean;
    
    // Cache for goal details and subjects
    // Key: goalId
    goalDetails: Record<string, {
        goal: Goal;
        subjects: Subject[];
        lastFetched: number;
    }>;
    
    // Track active requests to prevent concurrent duplicates
    loadingDetails: Record<string, boolean>;

    // Actions
    fetchGoals: (force?: boolean) => Promise<void>;
    fetchGoalDetail: (goalId: string, force?: boolean) => Promise<void>;
    addGoal: (goal: Goal) => void;
    deleteGoal: (id: string) => void;
    
    // Optimistic updates for subjects
    addSubject: (goalId: string, subject: Subject) => void;
    deleteSubject: (goalId: string, subjectId: string) => void;
}
// Cache duration removed as we use infinite cache until refresh
// const CACHE_DURATION = 5 * 60 * 1000; 

export const useGoalStore = create<GoalState>((set, get) => ({
    goals: [],
    lastFetched: 0,
    isLoading: false,
    goalDetails: {},
    loadingDetails: {},

    fetchGoals: async (force = false) => {
        const { lastFetched, isLoading } = get();

        // If data is already fetched and not forced, return (Infinite Cache until refresh)
        if (!force && lastFetched > 0) {
            return;
        }

        if (isLoading) return;

        set({ isLoading: true });
        try {
            const res: any = await goalApis.getGoals();
            if (res.code === 200) {
                const mappedGoals = res.data.map((g: any) => ({
                    ...g,
                    id: String(g.id),
                    priority: g.labelType === 'priority',
                    daily: g.labelType === 'daily',
                }));
                set({ goals: mappedGoals, lastFetched: Date.now() });
            }
        } catch (error) {
            console.error("Fetch goals failed", error);
        } finally {
            set({ isLoading: false });
        }
    },

    fetchGoalDetail: async (goalId, force = false) => {
        const { goalDetails, loadingDetails } = get();
        const now = Date.now();
        const cached = goalDetails[goalId];

        console.log(`[GoalStore] Fetching detail for ${goalId}. Force: ${force}, Cached: ${!!cached}, Loading: ${!!loadingDetails[goalId]}`);

        // 1. Check Cache
        if (!force && cached) {
            console.log(`[GoalStore] Cache hit for ${goalId}`);
            return;
        }

        // 2. Check Deduplication
        if (loadingDetails[goalId]) {
            console.log(`[GoalStore] Request already in progress for ${goalId}, skipping duplicate.`);
            return;
        }

        console.log(`[GoalStore] Cache miss/expired for ${goalId}, fetching from API...`);

        // Set loading state
        set((state) => ({
            loadingDetails: { ...state.loadingDetails, [goalId]: true }
        }));

        try {
            const [goalRes, subjectsRes] = await Promise.all([
                goalApis.getGoalDetail(goalId),
                goalApis.getGoalSubjects(goalId)
            ]);

            if ((goalRes as any).code === 200 && (subjectsRes as any).code === 200) {
                const g = (goalRes as any).data;
                const mappedGoal = {
                    ...g,
                    id: String(g.id),
                    priority: g.labelType === 'priority',
                    daily: g.labelType === 'daily',
                };
                
                const subjects = (subjectsRes as any).data.map((s: any) => ({
                    ...s,
                    id: String(s.id)
                }));

                console.log(`[GoalStore] Successfully fetched and cached detail for ${goalId}`);

                set((state) => ({
                    goalDetails: {
                        ...state.goalDetails,
                        [goalId]: {
                            goal: mappedGoal,
                            subjects,
                            lastFetched: now
                        }
                    },
                    loadingDetails: { ...state.loadingDetails, [goalId]: false }
                }));
            } else {
                console.error(`[GoalStore] API returned non-200 code. Goal: ${(goalRes as any).code}, Subjects: ${(subjectsRes as any).code}`);
                set((state) => ({
                    loadingDetails: { ...state.loadingDetails, [goalId]: false }
                }));
            }
        } catch (error) {
            console.error("Fetch goal detail failed", error);
            set((state) => ({
                loadingDetails: { ...state.loadingDetails, [goalId]: false }
            }));
        }
    },

    addGoal: (goal) => {
        set((state) => ({ goals: [...state.goals, goal] }));
    },

    deleteGoal: (id) => {
        set((state) => {
            const newDetails = { ...state.goalDetails };
            delete newDetails[id];
            return { 
                goals: state.goals.filter(g => g.id !== id),
                goalDetails: newDetails
            };
        });
    },

    addSubject: (goalId, subject) => {
        set((state) => {
            const detail = state.goalDetails[goalId];
            if (!detail) return state;

            return {
                goalDetails: {
                    ...state.goalDetails,
                    [goalId]: {
                        ...detail,
                        subjects: [...detail.subjects, subject]
                    }
                }
            };
        });
    },

    deleteSubject: (goalId, subjectId) => {
         set((state) => {
            const detail = state.goalDetails[goalId];
            if (!detail) return state;

            return {
                goalDetails: {
                    ...state.goalDetails,
                    [goalId]: {
                        ...detail,
                        subjects: detail.subjects.filter(s => s.id !== subjectId)
                    }
                }
            };
        });
    }
}));
