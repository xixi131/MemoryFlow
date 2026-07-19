import React from 'react';
import type { CountdownEvent } from '../../types/countdown';
import { calcEventDays } from '../../utils/countdownCalc';
// generateSquirclePath is imported to keep the squircle vocabulary available for
// tasks 012/013 (detail/add cards render at measured sizes). The list rows here
// have no measured width at render time, so per task 011 step 5 we intentionally
// fall back to CSS `border-radius:12px; overflow:hidden` for the row squircle.
import { generateSquirclePath } from '../islandGeometry';

// Keep a reference so the import is not flagged as unused while the measured-size
// SVG clipPath variant is deferred to later tasks (012/013).
void generateSquirclePath;

// ── Dispatch typing ──────────────────────────────────────────────
// useIslandState's IslandAction union is not exported, so we declare the
// subset of actions this card dispatches. A `Dispatch<IslandAction>` from the
// parent is assignable to `Dispatch<CountdownAction>` (function params are
// contravariant), so passing the real dispatch through type-checks cleanly.
type CountdownPage = 'list' | 'detail' | 'add' | 'edit';

type CountdownAction =
    | { type: 'SET_COUNTDOWN_PAGE'; payload: CountdownPage }
    | { type: 'SET_COUNTDOWN_SELECTED_ID'; payload: string | null }
    | { type: 'SET_COUNTDOWN_FORM_DRAFT'; payload: Partial<CountdownEvent> | null };

interface ExpandedCountdownCardProps {
    countdownPage: CountdownPage;
    countdownEvents: CountdownEvent[];
    countdownSelectedId?: string | null;
    dispatch: React.Dispatch<CountdownAction>;
}

// Type → emoji icon. Mirrors the compact activity glyphs.
const TYPE_ICON: Record<CountdownEvent['type'], string> = {
    birthday: '🎂',
    anniversary: '💕',
    custom: '⭐',
};

/** Local (not UTC) today as YYYY-MM-DD, matching calcEventDays' day math. */
function localTodayStr(): string {
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
}

/** 'YYYY-MM-DD' → 'YYYY年M月D日' (no zero padding on month/day). */
function formatCnDate(iso: string): string {
    const [y, m, d] = iso.split('-').map((n) => parseInt(n, 10));
    if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d)) return iso;
    return `${y}年${m}月${d}日`;
}

const AddButton: React.FC<{ dispatch: React.Dispatch<CountdownAction>; compact?: boolean }> = ({
    dispatch,
    compact = false,
}) => (
    <button
        onClick={(e) => {
            e.stopPropagation();
            dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'add' });
            dispatch({ type: 'SET_COUNTDOWN_FORM_DRAFT', payload: null });
        }}
        className={`flex items-center justify-center gap-1 shrink-0 rounded-full transition-colors ${
            compact ? 'px-4 py-1.5' : 'w-8 h-8'
        }`}
        style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.9)' }}
    >
        <span className="material-symbols-outlined text-[18px] leading-none">add</span>
        {compact && <span className="text-[12px] font-semibold">添加倒数日</span>}
    </button>
);

const CountdownListPage: React.FC<ExpandedCountdownCardProps> = ({ countdownEvents, dispatch }) => {
    const todayStr = localTodayStr();

    if (countdownEvents.length === 0) {
        return (
            <div className="flex flex-col items-center justify-center h-full gap-3">
                <span className="text-[13px] font-semibold" style={{ color: 'rgba(255,255,255,0.66)' }}>
                    还没有倒数日
                </span>
                <AddButton dispatch={dispatch} compact />
            </div>
        );
    }

    return (
        <div className="h-full flex flex-col">
            {/* Scrollable list region — hide scrollbar via inline style (no global util). */}
            <div className="flex-1 min-h-0 overflow-y-auto pr-1" style={{ scrollbarWidth: 'none' }}>
                <div className="flex flex-col gap-[7px]">
                    {countdownEvents.map((event) => {
                        const { days, status } = calcEventDays(event, todayStr);

                        // Status label per step 3.
                        let statusLabel: string;
                        if (status === 'today') statusLabel = '就是今天';
                        else if (event.countMode === 'countup') statusLabel = '已经';
                        else if (status === 'past') statusLabel = '已过去';
                        else statusLabel = '还有';

                        const dateLabel = event.countMode === 'countup' ? '起始日' : '目标日';

                        return (
                            <div
                                key={event.id}
                                onClick={(e) => {
                                    e.stopPropagation();
                                    dispatch({ type: 'SET_COUNTDOWN_SELECTED_ID', payload: event.id });
                                    dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'detail' });
                                }}
                                // Squircle fallback (task 011 step 5): rows have no measured
                                // width at render, so use CSS rounding + clip instead of a
                                // generateSquirclePath clip-path.
                                className="flex items-center gap-3 px-3 py-2 cursor-pointer"
                                style={{
                                    borderRadius: 12,
                                    overflow: 'hidden',
                                    background: 'rgba(255,255,255,0.06)',
                                }}
                            >
                                <span className="text-[22px] leading-none shrink-0">
                                    {TYPE_ICON[event.type] ?? '⭐'}
                                </span>

                                <div className="flex flex-col flex-1 min-w-0 gap-px">
                                    <span
                                        className="text-[13px] font-medium truncate"
                                        style={{ color: 'rgba(255,255,255,0.92)' }}
                                    >
                                        {event.name || '未命名'}
                                    </span>
                                    <span
                                        className="text-[10px] font-medium truncate"
                                        style={{ color: 'rgba(255,255,255,0.5)' }}
                                    >
                                        {statusLabel}
                                    </span>
                                    <span
                                        className="text-[10px] font-medium truncate"
                                        style={{ color: 'rgba(255,255,255,0.38)' }}
                                    >
                                        {dateLabel} {formatCnDate(event.date)}
                                    </span>
                                </div>

                                <div className="flex items-baseline gap-0.5 shrink-0">
                                    <span
                                        className="text-[22px] font-bold leading-none tracking-tight"
                                        style={{ color: event.color }}
                                    >
                                        {Math.abs(days)}
                                    </span>
                                    <span
                                        className="text-[11px] font-semibold"
                                        style={{ color: event.color }}
                                    >
                                        天
                                    </span>
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>

            {/* Fixed bottom add row. */}
            <div className="flex justify-end pt-2 shrink-0">
                <AddButton dispatch={dispatch} />
            </div>
        </div>
    );
};

const ExpandedCountdownCard: React.FC<ExpandedCountdownCardProps> = (props) => {
    // Exhaustive page switch. 'detail' | 'add' | 'edit' are owned by tasks 013/012;
    // render minimal placeholders for now so the switch stays type-safe.
    switch (props.countdownPage) {
        case 'list':
            return <CountdownListPage {...props} />;
        case 'detail':
        case 'add':
        case 'edit':
            // TODO(012/013): detail / add / edit pages.
            return null;
        default: {
            // Exhaustiveness guard — compile error if a CountdownPage is unhandled.
            const _exhaustive: never = props.countdownPage;
            return _exhaustive;
        }
    }
};

export default ExpandedCountdownCard;
