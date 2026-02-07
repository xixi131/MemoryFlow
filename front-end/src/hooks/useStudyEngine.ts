import { useState, useEffect, useCallback, useRef } from 'react';
import vocabularyApis, { Word, StudySessionData } from '../services/vocabulary';

export interface QueueItem extends Word {
    queueType: 'new' | 'review';
    isRequeued?: boolean; // If it was inserted due to 'forgot'
    consecutiveCorrect?: number; // How many times 'Know' clicked in this session consecutively
}

interface StudyStats {
    newCount: number;
    reviewCount: number;
    masteredCount: number;
}

export const useStudyEngine = (courseId?: number) => {
    const [loading, setLoading] = useState(true);
    const [queue, setQueue] = useState<QueueItem[]>([]);
    const [currentIndex, setCurrentIndex] = useState(0);
    const [stats, setStats] = useState<StudyStats>({ newCount: 0, reviewCount: 0, masteredCount: 0 });
    const [isFinished, setIsFinished] = useState(false);
    
    // Initial data fetch
    useEffect(() => {
        const fetchSession = async () => {
            try {
                setLoading(true);
                const res: any = await vocabularyApis.getStudySession(courseId);
                if (res.code === 200) {
                    const data: StudySessionData = res.data;
                    
                    // Process words to clean up translation/pos
                    const processedWords = processWords(data.words);
                    
                    // Categorize words into initial queue
                    // We assume the backend returns a mix. 
                    // We need to identify which are 'new' and which are 'review'.
                    // Logic: If isLearned=false, it's 'new'. If isLearned=true, it's 'review'.
                    const initialQueue: QueueItem[] = processedWords.map(w => ({
                        ...w,
                        queueType: w.isLearned ? 'review' : 'new',
                        consecutiveCorrect: 0
                    }));

                    setQueue(initialQueue);
                    setStats({
                        newCount: data.newCount,
                        reviewCount: data.reviewCount,
                        masteredCount: (data as any).mastered || 0
                    });
                }
            } catch (error) {
                console.error("Failed to fetch session", error);
            } finally {
                setLoading(false);
            }
        };

        fetchSession();
    }, [courseId]);

    const currentWord = queue[currentIndex];

    // Helper: Process raw words
    const processWords = (words: Word[]): Word[] => {
        return words
            .filter(w => !w.word.startsWith('-'))
            .map(w => {
                let cleanTrans = w.translation || w.definition || "";
                cleanTrans = cleanTrans.replace(/\[.*?\]/g, '').replace(/\\n/g, '\n');
                let pos = w.pos;
                if (!pos) {
                    const posMatch = cleanTrans.match(/^([a-z]+\.)/);
                    if (posMatch) pos = posMatch[1];
                }
                return { ...w, pos, translation: cleanTrans.trim() };
            });
    };

    // Action: Forgot
    const handleForgot = useCallback(async () => {
        if (!currentWord) return;

        // 1. Update Stats
        // If it was a 'new' word (and not already requeued/reviewing), move it to Review count
        if (currentWord.queueType === 'new' && !currentWord.isRequeued) {
            setStats(prev => ({
                ...prev,
                newCount: Math.max(0, prev.newCount - 1),
                reviewCount: prev.reviewCount + 1
            }));
        }
        // If it was 'review' or already 'requeued', count stays same (it's still in review pile)

        // 2. Re-queue logic (Spaced Repetition within session)
        // Insert a clone of this word at currentIndex + 3 (or end)
        setQueue(prev => {
            const newQueue = [...prev];
            const insertIndex = Math.min(currentIndex + 4, newQueue.length); // +4 because we want 3 items in between
            
            const requeuedItem: QueueItem = {
                ...currentWord,
                queueType: 'review', // It becomes a review item now
                isRequeued: true,
                consecutiveCorrect: 0 // Reset consecutive correct on forgot
            };
            
            newQueue.splice(insertIndex, 0, requeuedItem);
            return newQueue;
        });

        // 3. Backend Sync
        // We mark it as wrong immediately so the backend knows the scheduling needs update
        try {
            if (currentWord.isLearned) {
                await vocabularyApis.reviewWord({ wordId: currentWord.id, correct: false });
            } else {
                // Even for new words, if we forget, we might want to track it, 
                // but typically 'learn' is only called on success. 
                // However, user requirement says "Review records this word". 
                // Current backend 'reviewWord' might fail if word is not in user_word_progress.
                // If it's a NEW word, we haven't called 'learnWord' yet.
                // So we do nothing API-wise for NEW words until they are 'Known'.
                // If it's a REVIEW word, we penalize it.
                if (currentWord.queueType === 'review') {
                    await vocabularyApis.reviewWord({ wordId: currentWord.id, correct: false });
                }
            }
        } catch (e) {
            console.error(e);
        }

    }, [currentWord, currentIndex]);

    // Action: Know
    // Returns true if we should advance immediately (mastered), false if we just showed definition (wait for timer)
    const handleKnow = useCallback(async () => {
        if (!currentWord) return;

        try {
            // Case 1: Fresh Word (New or Review, never forgotten in this session)
            if (!currentWord.isRequeued) {
                if (currentWord.queueType === 'new') {
                    // New Word -> Learn
                    await vocabularyApis.learnWord({ wordId: currentWord.id, courseId });
                    setStats(prev => ({
                        ...prev,
                        newCount: Math.max(0, prev.newCount - 1),
                        masteredCount: prev.masteredCount + 1
                    }));
                } else {
                    // Review Word -> Review Correct
                    await vocabularyApis.reviewWord({ wordId: currentWord.id, correct: true });
                    setStats(prev => ({
                        ...prev,
                        reviewCount: Math.max(0, prev.reviewCount - 1),
                        masteredCount: prev.masteredCount + 1
                    }));
                }
                console.log('Word Mastered (Fresh):', currentWord.word);
            } 
            // Case 2: Requeued Word (Previously Forgotten in this session)
            else {
                const currentStreak = currentWord.consecutiveCorrect || 0;

                if (currentStreak === 0) {
                    // First time knowing after forgot -> Re-queue for confirmation
                    setQueue(prev => {
                        const newQueue = [...prev];
                        const insertIndex = Math.min(currentIndex + 7, newQueue.length); 
                        
                        const requeuedItem: QueueItem = {
                            ...currentWord,
                            isRequeued: true,
                            consecutiveCorrect: currentStreak + 1
                        };
                        
                        newQueue.splice(insertIndex, 0, requeuedItem);
                        return newQueue;
                    });
                    console.log('Word requeued for confirmation:', currentWord.word);
                } else {
                    // Second time knowing -> Master
                    if (currentWord.isLearned || currentWord.queueType === 'review') {
                         await vocabularyApis.reviewWord({ wordId: currentWord.id, correct: true });
                    } else {
                         await vocabularyApis.learnWord({ wordId: currentWord.id, courseId });
                    }
    
                    setStats(prev => ({
                        ...prev,
                        // If it was requeued, it might have been counted as 'review' in stats when moved from 'new'
                        // Or if it was originally 'review', it stayed 'review'.
                        // In handleForgot: New -> Review. Review -> Review.
                        // So here we always decrement reviewCount.
                        reviewCount: Math.max(0, prev.reviewCount - 1),
                        masteredCount: prev.masteredCount + 1
                    }));
                    console.log('Word Mastered (After Requeue):', currentWord.word);
                }
            }
        } catch (e) {
            console.error(e);
        }
    }, [currentWord, courseId, currentIndex]);

    const nextWord = useCallback(() => {
        if (currentIndex < queue.length - 1) {
            setCurrentIndex(prev => prev + 1);
        } else {
            setIsFinished(true);
        }
    }, [currentIndex, queue.length]);

    return {
        loading,
        currentWord,
        stats,
        isFinished,
        handleForgot,
        handleKnow,
        nextWord,
        totalInitial: queue.length // Approximate
    };
};
