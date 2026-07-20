import React from 'react';
import { motion } from 'framer-motion';
import {
    ACTIVITY_OPEN_CONTENT_DURATION_SECONDS,
    ACTIVITY_OPEN_CONTENT_DELAY_SECONDS,
} from '../islandGeometry';
import type { WidgetData, TodoPreviewData } from '../useIslandState';
import type { CountdownEvent } from '../../types/countdown';
import { calcEventDays } from '../../utils/countdownCalc';

// Open-book glyph — mirrors mac-island IslandReviewOpenBookGlyph (fanned pages + spine),
// stroked in review blue (#60a5fa, 1.5px round cap/join) to match the Mac activity tint.
// Replaces the old amber notebook icon which matched neither the Mac shape nor color.
const ReviewModeIcon: React.FC = () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path
            d="M12 5.2C8.6 2.9 5.2 2.9 2.4 4.4L2.4 17.8C5.2 16.6 8.6 16.6 12 18.6M12 5.2C15.4 2.9 18.8 2.9 21.6 4.4L21.6 17.8C18.8 16.6 15.4 16.6 12 18.6M12 5.2L12 18.6"
            stroke="#60a5fa"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            vectorEffect="non-scaling-stroke"
        />
    </svg>
);

interface AppActivityContentProps {
    appDisplayMode: 'review' | 'todo' | 'countdown';
    data: WidgetData;
    todoPreview: TodoPreviewData;
    countdownEvents: CountdownEvent[];
    activityOpenAnimToken: number;
    isActivityOpenTransition: boolean;
    onIconPointerDown: (e: React.PointerEvent<HTMLButtonElement>) => void;
    onIconPointerEnd: (e: React.PointerEvent<HTMLButtonElement>) => void;
}

const AppActivityContent: React.FC<AppActivityContentProps> = ({
    appDisplayMode,
    data,
    todoPreview,
    countdownEvents,
    activityOpenAnimToken,
    isActivityOpenTransition,
    onIconPointerDown,
    onIconPointerEnd,
}) => {
    // ── Countdown compact summary (task 010) ─────────────────────────────
    // Pick the display event: nearest upcoming countdown → first countup →
    // first event. Empty list renders the "add" prompt with no number.
    let countdownEmpty = false;
    let countdownName = '';
    let countdownText = '';
    let countdownColor: string | undefined;
    if (appDisplayMode === 'countdown') {
        if (countdownEvents.length === 0) {
            countdownEmpty = true;
        } else {
            const now = new Date();
            const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
            let best: CountdownEvent | null = null;
            let bestDays = Infinity;
            for (const evt of countdownEvents) {
                if (evt.countMode !== 'countdown') continue;
                const r = calcEventDays(evt, todayStr);
                if (r.status === 'upcoming' && r.days > 0 && r.days < bestDays) {
                    bestDays = r.days;
                    best = evt;
                }
            }
            if (!best) best = countdownEvents.find((e) => e.countMode === 'countup') ?? countdownEvents[0];
            const result = calcEventDays(best, todayStr);
            const rawName = best.name ?? '';
            countdownName = rawName.length > 6 ? `${rawName.slice(0, 6)}…` : rawName;
            countdownText = result.status === 'today' ? '今天' : `${result.days}天`;
            countdownColor = best.color;
        }
    }

    return (
    <motion.div
        key={`app-activity-${appDisplayMode}-${activityOpenAnimToken}`}
        initial={isActivityOpenTransition ? { opacity: 0, filter: 'blur(4px)' } : false}
        animate={{ opacity: 1, filter: 'blur(0px)' }}
        transition={isActivityOpenTransition
            ? { duration: ACTIVITY_OPEN_CONTENT_DURATION_SECONDS, delay: ACTIVITY_OPEN_CONTENT_DELAY_SECONDS, ease: 'easeOut' }
            : { duration: 0.12 }}
        className="w-full h-full"
    >
        <div className="flex items-center justify-between w-full h-full px-3">
            <div className="flex items-center gap-2 min-w-0">
                <button
                    type="button"
                    onPointerDown={onIconPointerDown}
                    onPointerUp={onIconPointerEnd}
                    onPointerLeave={onIconPointerEnd}
                    onPointerCancel={onIconPointerEnd}
                    onClick={(e) => e.stopPropagation()}
                    onContextMenu={(e) => e.preventDefault()}
                    title={appDisplayMode === 'todo' ? '长按切换到复习模式' : appDisplayMode === 'countdown' ? '长按切换模式' : '长按切换到待办模式'}
                    className="flex items-center justify-center rounded-md text-white/90 active:scale-95 transition-transform"
                >
                    {appDisplayMode === 'todo' ? (
                        <span className="material-symbols-outlined text-sm" style={{ color: 'rgb(255,149,0)' }}>checklist</span>
                    ) : appDisplayMode === 'countdown' ? (
                        <span className="material-symbols-outlined text-sm text-emerald-300">event</span>
                    ) : (
                        <div className="flex items-center justify-center">
                            <ReviewModeIcon />
                        </div>
                    )}
                </button>
            </div>
            {appDisplayMode === 'countdown' ? (
                <span className="text-[12px] font-bold text-white/[0.84] leading-none flex items-center gap-1 min-w-0 max-w-[130px]">
                    {countdownEmpty ? (
                        <span className="truncate">添加倒数日</span>
                    ) : (
                        <>
                            <span className="truncate">{countdownName}</span>
                            <span style={{ color: countdownColor }}>{countdownText}</span>
                        </>
                    )}
                </span>
            ) : (
                <span className="text-[12px] font-bold text-white/[0.84] leading-none">
                    {appDisplayMode === 'todo'
                        ? `${Math.max(todoPreview.pending, 0)}`
                        : `${Math.max(data.totalPendingReviews, 0)}`}
                </span>
            )}
        </div>
    </motion.div>
    );
};

export default AppActivityContent;
