import React, { useState } from 'react';
import { motion } from 'framer-motion';
import type { WidgetData } from '../useIslandState';

interface ExpandedReviewCardProps {
    data: WidgetData;
    isExpanded: boolean;
}

// Matches mac IslandExpandedReviewContentLayout.headerCollapseDistance = 54
const HEADER_COLLAPSE_DISTANCE = 54;

// Mac IslandExpandedReviewContentLayout.minimumGridSlots — the review grid always
// reserves a fixed area, padding with empty placeholder slots so a single subject
// doesn't collapse the card down to one row and expose the island's bottom edge.
const MIN_GRID_SLOTS = 8;

// book.closed.fill equivalent — SF Symbols style closed book glyph
const BookClosedFill: React.FC = () => (
    <svg
        width="11"
        height="11"
        viewBox="0 0 16 16"
        fill="currentColor"
        className="text-blue-400 shrink-0"
        aria-hidden="true"
    >
        <path d="M4.25 1.5C3.01 1.5 2 2.51 2 3.75v8.5C2 13.49 3.01 14.5 4.25 14.5H13a1 1 0 0 0 1-1V2.5a1 1 0 0 0-1-1H4.25Zm0 11a.75.75 0 0 1 0-1.5H12.5v1.5H4.25Z" />
    </svg>
);

const ExpandedReviewCard: React.FC<ExpandedReviewCardProps> = ({ data, isExpanded }) => {
    const activeSubjects = data.subjects.filter(s => s.pendingReviewCount > 0);
    const [scrollTop, setScrollTop] = useState(0);

    // Real subjects first, then empty placeholder slots up to the fixed minimum so the
    // grid always fills a consistent area regardless of how few subjects are pending.
    const subjectSlots = [
        ...activeSubjects.map(s => ({ id: s.id, title: s.title, isPlaceholder: false })),
        ...Array.from({ length: Math.max(MIN_GRID_SLOTS - activeSubjects.length, 0) }, (_, i) => ({
            id: `placeholder-${i}`,
            title: '',
            isPlaceholder: true,
        })),
    ];

    // Mac: min(max(scrollOffset / headerCollapseDistance, 0), 1)
    const collapseProgress = Math.min(Math.max(scrollTop / HEADER_COLLAPSE_DISTANCE, 0), 1);

    return (
        <div className="relative flex flex-col h-full">
            {/* ── ScrollView (vertical) ─────────────────────────────── */}
            <div
                className="flex-1 min-h-0 overflow-y-auto no-scrollbar"
                onScroll={(e) => setScrollTop((e.target as HTMLDivElement).scrollTop)}
            >
                <div className="flex flex-col gap-4 pb-2">
                    {/* Counter row — collapses on scroll (mac reviewCounterRow) */}
                    <div
                        className="flex gap-2 origin-top-left"
                        style={{
                            transform: `scale(${1 - collapseProgress * 0.18})`,
                            opacity: 1 - collapseProgress * 0.5,
                        }}
                    >
                        <div className="flex-1 flex flex-col items-start gap-0.5">
                            <span className="text-[34px] font-bold text-white leading-none tracking-tight">
                                {Math.max(data.totalPendingReviews, 0)}
                            </span>
                            <span className="text-[13px] font-semibold text-white/[0.68] leading-none">待复习</span>
                        </div>
                        <div className="flex-1 flex flex-col items-start gap-0.5">
                            <span className="text-[34px] font-bold text-white leading-none tracking-tight">
                                {Math.max(data.totalCompletedToday, 0)}
                            </span>
                            <span className="text-[13px] font-semibold text-white/[0.68] leading-none">今日完成</span>
                        </div>
                    </div>

                    {/* Subject grid — staggered 0.9-scale spring entrance (mac subjectCard) */}
                    <motion.div
                        className="grid grid-cols-2 gap-2 w-full"
                        variants={{
                            hidden: { opacity: 0 },
                            visible: { opacity: 1, transition: { staggerChildren: 0.05, delayChildren: 0.1 } },
                        }}
                        initial="hidden"
                        animate={isExpanded ? 'visible' : 'hidden'}
                    >
                        {subjectSlots.map((slot) => (
                            <motion.div
                                key={slot.id}
                                variants={{
                                    hidden: { opacity: 0, scale: 0.9 },
                                    visible: { opacity: 1, scale: 1, transition: { type: 'spring', stiffness: 300, damping: 20 } },
                                }}
                                className={
                                    slot.isPlaceholder
                                        ? 'h-[42px] rounded-[9px] bg-white/[0.05]'
                                        : 'flex items-center gap-[7px] h-[42px] px-[9px] rounded-[9px] bg-white/10 cursor-default'
                                }
                            >
                                {!slot.isPlaceholder && (
                                    <>
                                        <BookClosedFill />
                                        <span className="min-w-0 text-[11px] font-semibold text-white/[0.86] truncate">{slot.title}</span>
                                    </>
                                )}
                            </motion.div>
                        ))}
                    </motion.div>
                </div>
            </div>

            {/* ── Top glass fade (h-90, fades down) — mac gates it behind scroll ── */}
            <div
                className="pointer-events-none absolute top-0 left-0 right-0 h-[90px] z-10"
                style={{
                    background: 'linear-gradient(to bottom, rgba(0,0,0,0.98) 0%, rgba(0,0,0,0) 100%)',
                    opacity: collapseProgress,
                }}
            />

            {/* ── Compact scroll header — fades in with collapse ────── */}
            <div
                className="pointer-events-none absolute top-0 left-0 right-0 z-20 flex gap-2 px-0.5 h-[38px] items-center"
                style={{ opacity: collapseProgress }}
            >
                <div className="flex-1 flex items-baseline gap-[5px]">
                    <span className="text-[18px] font-bold text-white leading-none">{Math.max(data.totalPendingReviews, 0)}</span>
                    <span className="text-[11px] font-semibold text-white/[0.68] leading-none">待复习</span>
                </div>
                <div className="flex-1 flex items-baseline gap-[5px]">
                    <span className="text-[18px] font-bold text-white leading-none">{Math.max(data.totalCompletedToday, 0)}</span>
                    <span className="text-[11px] font-semibold text-white/[0.68] leading-none">今日完成</span>
                </div>
            </div>

            {/* ── Bottom glass fade (h-20, fades up) ────────────────── */}
            <div
                className="pointer-events-none absolute bottom-0 left-0 right-0 h-[20px] z-10"
                style={{ background: 'linear-gradient(to top, rgba(0,0,0,0.98) 0%, rgba(0,0,0,0) 100%)' }}
            />
        </div>
    );
};

export default ExpandedReviewCard;
