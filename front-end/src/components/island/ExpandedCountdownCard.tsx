import React, { useState, useEffect, useRef, useCallback } from 'react';
import type { CountdownEvent, CountdownEventType, CountdownMode } from '../../types/countdown';
import { calcEventDays } from '../../utils/countdownCalc';
import { saveCountdownEvents } from '../../api/countdownApi';
import userApis from '../../api/userApis';
import { resolveApiAssetUrl } from '../../utils/resolveApiAssetUrl';

// Schema defaults for the background-image fields added in task 016. Older
// persisted events (and freshly constructed ones) may lack these, so reads fall
// back to these values.
const BG_OFFSET_DEFAULT = { x: 50, y: 50 };
const TEXT_COLOR_DEFAULT = '#FFFFFF';
// Frosted-glass blur intensity defaults (px) for the list/detail overlays
// (task 019). Range 0–20. Reads fall back to these for older events.
const LIST_BLUR_DEFAULT = 6;
const DETAIL_BLUR_DEFAULT = 8;
// Background-image zoom/scale default + bounds (task 022). 1.0 → 'cover'.
// Adjusted via the edit-page preview card's scroll wheel.
const BG_IMAGE_SCALE_DEFAULT = 1.0;
const BG_IMAGE_SCALE_MIN = 0.3;
const BG_IMAGE_SCALE_MAX = 3.0;

// Compute the CSS background-size for an image card given the saved scale.
// scale === 1.0 (or absent) → 'cover' (preserves the pre-task-022 look);
// otherwise `${scale * 100}% auto` so <1 shrinks the image (reveals more) and
// >1 zooms in. Used identically by the preview, list, and detail cards.
function bgSizeForScale(scale?: number): string {
    return !scale || scale === BG_IMAGE_SCALE_DEFAULT ? 'cover' : `${scale * 100}% auto`;
}
// generateSquirclePath is imported to keep the squircle vocabulary available for
// tasks 012/013 (detail/add cards render at measured sizes). The list rows here
// have no measured width at render time, so per task 011 step 5 we intentionally
// fall back to CSS `border-radius:12px; overflow:hidden` for the row squircle.
import {
    generateSquirclePath,
    generateFullSquirclePath,
    SQUIRCLE_SMOOTHNESS_EXPANDED,
} from '../islandGeometry';

// Keep a reference so the import is not flagged as unused while the measured-size
// SVG clipPath variant is deferred to later tasks (012/013).
void generateSquirclePath;

// ── Dispatch typing ──────────────────────────────────────────────
// useIslandState's IslandAction union is not exported, so we declare the
// subset of actions this card dispatches. A `Dispatch<IslandAction>` from the
// parent is assignable to `Dispatch<CountdownAction>` (function params are
// contravariant), so passing the real dispatch through type-checks cleanly.
type CountdownPage = 'list' | 'detail' | 'add' | 'edit' | 'datepicker';

type CountdownAction =
    | { type: 'SET_COUNTDOWN_PAGE'; payload: CountdownPage }
    | { type: 'SET_COUNTDOWN_DATEPICKER_RETURN'; payload: 'add' | 'edit' | null }
    | { type: 'SET_COUNTDOWN_SELECTED_ID'; payload: string | null }
    | { type: 'SET_COUNTDOWN_FORM_DRAFT'; payload: Partial<CountdownEvent> | null }
    | { type: 'SET_COUNTDOWN_EVENTS'; payload: CountdownEvent[] };

interface ExpandedCountdownCardProps {
    countdownPage: CountdownPage;
    countdownEvents: CountdownEvent[];
    countdownSelectedId?: string | null;
    // Optional: the in-progress form draft (Partial<CountdownEvent>) held in
    // island state so a form survives an island collapse. The widget does not
    // pass this yet — see discoveries — so seeding-from-draft is a no-op until
    // `countdownFormDraft={state.countdownFormDraft}` is wired in the parent.
    countdownFormDraft?: Partial<CountdownEvent> | null;
    // Which form page the dedicated datepicker page returns to (task 021).
    countdownDatePickerReturn?: 'add' | 'edit' | null;
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

                        // Background-image rendering (task 018). bgImageUrl already
                        // holds a resolved absolute URL — use it directly. Older
                        // events may lack bgImageOffset/textColor, so default them.
                        const hasImage = event.bgImageUrl != null && event.bgImageUrl !== '';
                        const offset = event.bgImageOffset ?? BG_OFFSET_DEFAULT;
                        const textColor = event.textColor ?? TEXT_COLOR_DEFAULT;

                        if (hasImage) {
                            // Three-layer treatment: absolute image → frosted-glass
                            // overlay (blur 6, rgba(0,0,0,0.38), pointerEvents:none so
                            // it never blocks the row's navigation) → relative z-10 text
                            // in the event's textColor. Row keeps its onClick navigation.
                            return (
                                <div
                                    key={event.id}
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        dispatch({ type: 'SET_COUNTDOWN_SELECTED_ID', payload: event.id });
                                        dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'detail' });
                                    }}
                                    className="relative flex items-center gap-3 px-3 py-2 cursor-pointer"
                                    style={{ borderRadius: 12, overflow: 'hidden' }}
                                >
                                    {/* Image layer */}
                                    <div
                                        style={{
                                            position: 'absolute',
                                            inset: 0,
                                            backgroundImage: `url('${resolveApiAssetUrl(event.bgImageUrl)}')`,
                                            backgroundPosition: `${offset.x}% ${offset.y}%`,
                                            backgroundSize: bgSizeForScale(event.bgImageScale),
                                            backgroundRepeat: 'no-repeat',
                                        }}
                                    />
                                    {/* Frosted-glass overlay */}
                                    <div
                                        style={{
                                            position: 'absolute',
                                            inset: 0,
                                            backdropFilter: `blur(${event.listBlurIntensity ?? LIST_BLUR_DEFAULT}px)`,
                                            WebkitBackdropFilter: `blur(${event.listBlurIntensity ?? LIST_BLUR_DEFAULT}px)`,
                                            background: 'rgba(0,0,0,0.38)',
                                            pointerEvents: 'none',
                                        }}
                                    />

                                    <span className="relative z-10 text-[22px] leading-none shrink-0">
                                        {TYPE_ICON[event.type] ?? '⭐'}
                                    </span>

                                    <div className="relative z-10 flex flex-col flex-1 min-w-0 gap-px">
                                        <span
                                            className="text-[13px] font-medium truncate"
                                            style={{ color: textColor }}
                                        >
                                            {event.name || '未命名'}
                                        </span>
                                        <span
                                            className="text-[10px] font-medium truncate"
                                            style={{ color: textColor, opacity: 0.75 }}
                                        >
                                            {statusLabel}
                                        </span>
                                        <span
                                            className="text-[10px] font-medium truncate"
                                            style={{ color: textColor, opacity: 0.6 }}
                                        >
                                            {dateLabel} {formatCnDate(event.date)}
                                        </span>
                                    </div>

                                    <div className="relative z-10 flex items-baseline gap-0.5 shrink-0">
                                        <span
                                            className="text-[22px] font-bold leading-none tracking-tight"
                                            style={{ color: textColor }}
                                        >
                                            {Math.abs(days)}
                                        </span>
                                        <span
                                            className="text-[11px] font-semibold"
                                            style={{ color: textColor }}
                                        >
                                            天
                                        </span>
                                    </div>
                                </div>
                            );
                        }

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

// ── Add / Edit form ──────────────────────────────────────────────
// Preset color swatches (8) offered in the form. First entry is the default.
const COLOR_PRESETS = [
    '#FF8800', '#FF5A5F', '#FFC400', '#34C759',
    '#00B8D9', '#5B6CFF', '#AF52DE', '#FF2D92',
];
const DEFAULT_COLOR = COLOR_PRESETS[0];

// Text-color swatches for the '文字颜色' picker (task 017). Same 8-swatch layout
// as COLOR_PRESETS but leads with white and black — the two most common legible
// choices over arbitrary imagery — which the event-color palette lacks.
const TEXT_COLOR_PRESETS = [
    '#FFFFFF', '#000000', '#FF8800', '#FF5A5F',
    '#FFC400', '#34C759', '#00B8D9', '#5B6CFF',
];

// Preview card is a fixed 200×110 box; drag math converts pixel deltas to the
// same percentage space used by backgroundPosition.
const CARD_W = 200;
const CARD_H = 110;
const clamp = (v: number, lo: number, hi: number): number => Math.min(hi, Math.max(lo, v));

const TYPE_OPTIONS: { value: CountdownEventType; label: string }[] = [
    { value: 'birthday', label: '生日' },
    { value: 'anniversary', label: '纪念日' },
    { value: 'custom', label: '自定义' },
];

const MODE_OPTIONS: { value: CountdownMode; label: string }[] = [
    { value: 'countdown', label: '倒计时' },
    { value: 'countup', label: '正数日' },
];

// Local, id-less form shape (id is only assembled at save time / read from the
// edited event).
interface CountdownFormState {
    name: string;
    type: CountdownEventType;
    countMode: CountdownMode;
    date: string;
    repeat: boolean;
    color: string;
    bgImageUrl: string | null;
    bgImageOffset: { x: number; y: number };
    textColor: string;
    listBlurIntensity: number;
    detailBlurIntensity: number;
    bgImageScale: number;
}

const ADD_DEFAULTS: CountdownFormState = {
    name: '',
    type: 'custom',
    countMode: 'countdown',
    date: '',
    repeat: false,
    color: DEFAULT_COLOR,
    bgImageUrl: null,
    bgImageOffset: { ...BG_OFFSET_DEFAULT },
    textColor: TEXT_COLOR_DEFAULT,
    listBlurIntensity: LIST_BLUR_DEFAULT,
    detailBlurIntensity: DETAIL_BLUR_DEFAULT,
    bgImageScale: BG_IMAGE_SCALE_DEFAULT,
};

/** Seed the local form: edit → selected event (draft overrides); add → draft or defaults. */
function seedForm(
    mode: 'add' | 'edit',
    events: CountdownEvent[],
    selectedId: string | null,
    draft: Partial<CountdownEvent> | null,
): CountdownFormState {
    if (mode === 'edit') {
        const evt = events.find((e) => e.id === selectedId);
        const base: CountdownFormState = evt
            ? {
                  name: evt.name,
                  type: evt.type,
                  countMode: evt.countMode,
                  date: evt.date,
                  repeat: evt.repeat,
                  color: evt.color,
                  bgImageUrl: evt.bgImageUrl ?? null,
                  bgImageOffset: evt.bgImageOffset ?? { ...BG_OFFSET_DEFAULT },
                  textColor: evt.textColor ?? TEXT_COLOR_DEFAULT,
                  listBlurIntensity: evt.listBlurIntensity ?? LIST_BLUR_DEFAULT,
                  detailBlurIntensity: evt.detailBlurIntensity ?? DETAIL_BLUR_DEFAULT,
                  bgImageScale: evt.bgImageScale ?? BG_IMAGE_SCALE_DEFAULT,
              }
            : { ...ADD_DEFAULTS };
        return draft ? ({ ...base, ...draft } as CountdownFormState) : base;
    }
    return draft ? ({ ...ADD_DEFAULTS, ...draft } as CountdownFormState) : { ...ADD_DEFAULTS };
}

// ── Live preview card (task 016) ─────────────────────────────────
// Renders at ~200×110 in the edit/add form's left column. Mirrors the detail
// card: color band + dark body when no bg image; full-bleed image with custom
// text color when an image is set.
const CountdownPreviewCard: React.FC<{
    form: CountdownFormState;
    todayStr: string;
    // Drag-to-pan wiring (task 017). Only meaningful when a bg image is set.
    onMouseDown?: (e: React.MouseEvent) => void;
    onMouseMove?: (e: React.MouseEvent) => void;
    onMouseUp?: (e: React.MouseEvent) => void;
    onMouseLeave?: (e: React.MouseEvent) => void;
    isDragging?: boolean;
    showDragHint?: boolean;
    // Scroll-wheel zoom wiring (task 022). Only meaningful when a bg image is set.
    onWheel?: (e: React.WheelEvent) => void;
    // Transient scale-indicator pill: visible flag + the value to show (e.g. 1.2).
    scaleIndicatorVisible?: boolean;
    scaleIndicatorValue?: number;
}> = ({
    form,
    todayStr,
    onMouseDown,
    onMouseMove,
    onMouseUp,
    onMouseLeave,
    isDragging = false,
    showDragHint = false,
    onWheel,
    scaleIndicatorVisible = false,
    scaleIndicatorValue = BG_IMAGE_SCALE_DEFAULT,
}) => {
    // Reuse the shared day-count helper; guard the empty-date case (form not yet
    // filled) so parseUtcDate never sees NaN.
    const dayNumber =
        form.date === ''
            ? null
            : Math.abs(
                  calcEventDays(
                      {
                          id: '',
                          name: form.name,
                          type: form.type,
                          countMode: form.countMode,
                          date: form.date,
                          repeat: form.repeat,
                          color: form.color,
                      },
                      todayStr,
                  ).days,
              );

    const dateStr = form.date === '' ? '选择日期' : formatCnDate(form.date);
    const title = form.name.trim() === '' ? '事件名称' : form.name;
    const hasImage = form.bgImageUrl != null && form.bgImageUrl !== '';

    if (hasImage) {
        return (
            <div
                onMouseDown={onMouseDown}
                onMouseMove={onMouseMove}
                onMouseUp={onMouseUp}
                onMouseLeave={onMouseLeave}
                onWheel={onWheel}
                style={{
                    width: 200,
                    height: 110,
                    borderRadius: 16,
                    overflow: 'hidden',
                    position: 'relative',
                    backgroundImage: `url('${resolveApiAssetUrl(form.bgImageUrl)}')`,
                    backgroundSize: bgSizeForScale(form.bgImageScale),
                    backgroundPosition: `${form.bgImageOffset.x}% ${form.bgImageOffset.y}%`,
                    backgroundRepeat: 'no-repeat',
                    // grab normally, grabbing while a drag is in progress (step 3).
                    cursor: isDragging ? 'grabbing' : 'grab',
                    userSelect: 'none',
                }}
            >
                {/* No color band. Text color is user-chosen; a soft shadow keeps it
                    legible over arbitrary imagery without introducing a band. */}
                <div
                    className="flex flex-col justify-between h-full px-3 py-2"
                    style={{ color: form.textColor, textShadow: '0 1px 3px rgba(0,0,0,0.45)' }}
                >
                    <span className="text-[12px] font-semibold truncate">{title}</span>
                    <div className="flex items-baseline gap-0.5">
                        <span className="text-[36px] font-bold leading-none tracking-tight">
                            {dayNumber ?? '—'}
                        </span>
                        <span className="text-[12px] font-semibold">天</span>
                    </div>
                    <span className="text-[10px] font-medium truncate">{dateStr}</span>
                </div>

                {/* First-attachment hint overlay (step 3): shown for 2s, then removed
                    by the parent's timeout. pointerEvents:none so it never blocks the drag. */}
                {showDragHint && (
                    <div
                        className="absolute inset-0 flex items-center justify-center"
                        style={{ pointerEvents: 'none', background: 'rgba(0,0,0,0.28)' }}
                    >
                        <span
                            className="text-[11px] font-semibold px-2 py-1 rounded-full"
                            style={{ color: '#fff', background: 'rgba(0,0,0,0.45)' }}
                        >
                            拖动调整显示区域
                        </span>
                    </div>
                )}

                {/* Transient scale indicator (task 022): bottom-right pill showing
                    the current zoom (e.g. 1.2×). Always mounted so it can fade; the
                    parent toggles scaleIndicatorVisible on each wheel event and clears
                    it ~1.2s after scrolling stops. pointerEvents:none so it never
                    blocks the wheel/drag. */}
                <div
                    className="absolute text-[11px] font-semibold px-2 py-0.5 rounded-full"
                    style={{
                        right: 6,
                        bottom: 6,
                        color: '#fff',
                        background: 'rgba(0,0,0,0.5)',
                        pointerEvents: 'none',
                        opacity: scaleIndicatorVisible ? 1 : 0,
                        transition: 'opacity 0.4s ease',
                    }}
                >
                    {scaleIndicatorValue.toFixed(1)}×
                </div>
            </div>
        );
    }

    return (
        <div
            style={{
                width: 200,
                height: 110,
                borderRadius: 16,
                overflow: 'hidden',
                background: 'rgba(255,255,255,0.06)',
                display: 'flex',
                flexDirection: 'column',
            }}
        >
            {/* Color band with title. */}
            <div
                className="flex items-center px-3 shrink-0"
                style={{ height: 26, background: form.color }}
            >
                <span className="text-[12px] font-semibold truncate" style={{ color: '#fff' }}>
                    {title}
                </span>
            </div>
            {/* Dark body: big day number + unit, date at the bottom. */}
            <div className="flex-1 flex flex-col items-center justify-center px-3">
                <div className="flex items-baseline gap-0.5">
                    <span
                        className="text-[36px] font-bold leading-none tracking-tight"
                        style={{ color: form.color }}
                    >
                        {dayNumber ?? '—'}
                    </span>
                    <span className="text-[12px] font-semibold" style={{ color: form.color }}>
                        天
                    </span>
                </div>
                <span
                    className="text-[10px] font-medium mt-1 truncate"
                    style={{ color: 'rgba(255,255,255,0.5)' }}
                >
                    {dateStr}
                </span>
            </div>
        </div>
    );
};

interface CountdownFormPageProps {
    mode: 'add' | 'edit';
    countdownEvents: CountdownEvent[];
    countdownSelectedId?: string | null;
    countdownFormDraft?: Partial<CountdownEvent> | null;
    dispatch: React.Dispatch<CountdownAction>;
}

const CountdownFormPage: React.FC<CountdownFormPageProps> = ({
    mode,
    countdownEvents,
    countdownSelectedId,
    countdownFormDraft,
    dispatch,
}) => {
    const todayStr = localTodayStr();
    const nameRef = useRef<HTMLInputElement>(null);

    const [form, setForm] = useState<CountdownFormState>(() =>
        seedForm(mode, countdownEvents, countdownSelectedId ?? null, countdownFormDraft ?? null),
    );
    const [showErrors, setShowErrors] = useState(false);
    const [confirmDiscard, setConfirmDiscard] = useState(false);
    // Background-image upload (task 016).
    const bgFileRef = useRef<HTMLInputElement>(null);
    const [uploadError, setUploadError] = useState(false);
    const [uploading, setUploading] = useState(false);
    // Two-step delete confirmation (edit mode only), moved here from the detail
    // page per Bug 5. Local state, not the reducer.
    const [confirmDelete, setConfirmDelete] = useState(false);

    // ── Drag-to-pan the bg image (task 017) ──────────────────────────
    // Active-tracking + start values live in a ref so mid-drag mousemoves read
    // stable start values and the handler wiring itself never triggers a
    // re-render. Only the dispatched bgImageOffset change re-renders (intended,
    // to move background-position). isDragging is a separate small state, used
    // ONLY to toggle the grab/grabbing cursor.
    const dragRef = useRef<{
        active: boolean;
        startX: number;
        startY: number;
        startOffset: { x: number; y: number };
    }>({ active: false, startX: 0, startY: 0, startOffset: { ...BG_OFFSET_DEFAULT } });
    const [isDragging, setIsDragging] = useState(false);

    // ── Scroll-wheel zoom of the bg image (task 022) ─────────────────
    // A transient pill shows the current scale during/just after scrolling. The
    // visible flag + displayed value are state (so the pill re-renders); a ref
    // holds the hide timeout so each wheel tick resets the ~1.2s fade-out.
    const [scaleIndicatorVisible, setScaleIndicatorVisible] = useState(false);
    const [scaleIndicatorValue, setScaleIndicatorValue] = useState(BG_IMAGE_SCALE_DEFAULT);
    const scaleHideTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
    useEffect(() => () => {
        if (scaleHideTimer.current) clearTimeout(scaleHideTimer.current);
    }, []);

    // First-attachment hint (step 3): show a 2s overlay label the first time an
    // image is attached. prevHadImage seeds from the initial form so an edit that
    // opens with a pre-existing image does NOT flash the hint; it only fires on a
    // no-image → image transition.
    const [showDragHint, setShowDragHint] = useState(false);
    const prevHadImage = useRef<boolean>(form.bgImageUrl != null && form.bgImageUrl !== '');
    useEffect(() => {
        const has = form.bgImageUrl != null && form.bgImageUrl !== '';
        if (has && !prevHadImage.current) {
            setShowDragHint(true);
            const t = setTimeout(() => setShowDragHint(false), 2000);
            prevHadImage.current = has;
            return () => clearTimeout(t);
        }
        prevHadImage.current = has;
    }, [form.bgImageUrl]);

    const hasBgImage = form.bgImageUrl != null && form.bgImageUrl !== '';

    const handlePreviewMouseDown = (e: React.MouseEvent) => {
        if (!hasBgImage) return;
        e.stopPropagation();
        dragRef.current = {
            active: true,
            startX: e.clientX,
            startY: e.clientY,
            startOffset: { ...form.bgImageOffset },
        };
        setIsDragging(true);
    };

    const handlePreviewMouseMove = (e: React.MouseEvent) => {
        if (!dragRef.current.active) return;
        const deltaX = e.clientX - dragRef.current.startX;
        const deltaY = e.clientY - dragRef.current.startY;
        const deltaPercentX = (deltaX / CARD_W) * 100;
        const deltaPercentY = (deltaY / CARD_H) * 100;
        // Pan convention: dragging the image RIGHT (deltaX > 0) should reveal
        // content to the LEFT — i.e. move the visible window toward the image's
        // start. With backgroundPosition percentages, a smaller x% shows more of
        // the left edge, so we SUBTRACT the delta. Same convention vertically:
        // dragging DOWN reveals content above → subtract from y%.
        const nextX = clamp(dragRef.current.startOffset.x - deltaPercentX, 0, 100);
        const nextY = clamp(dragRef.current.startOffset.y - deltaPercentY, 0, 100);
        update({ bgImageOffset: { x: nextX, y: nextY } });
    };

    const endPreviewDrag = () => {
        if (!dragRef.current.active) return;
        dragRef.current.active = false;
        setIsDragging(false);
    };

    // Scroll-wheel zoom over the preview card (task 022). stopPropagation is
    // required so the island's scroll region does not scroll while scaling;
    // preventDefault suppresses the page/island scroll for the same gesture.
    // Scrolling up (deltaY < 0) zooms in, down shrinks the image, clamped to
    // 0.3–3.0. Reuses update() so the change threads through form state AND the
    // dispatched SET_COUNTDOWN_FORM_DRAFT (same path as drag-to-pan).
    const handlePreviewWheel = (e: React.WheelEvent) => {
        if (!hasBgImage) return;
        e.preventDefault();
        e.stopPropagation();
        const currentScale = form.bgImageScale ?? BG_IMAGE_SCALE_DEFAULT;
        const delta = -e.deltaY * 0.003;
        const newScale = Math.min(
            BG_IMAGE_SCALE_MAX,
            Math.max(BG_IMAGE_SCALE_MIN, currentScale + delta),
        );
        update({ bgImageScale: newScale });
        setScaleIndicatorValue(newScale);
        setScaleIndicatorVisible(true);
        if (scaleHideTimer.current) clearTimeout(scaleHideTimer.current);
        scaleHideTimer.current = setTimeout(() => setScaleIndicatorVisible(false), 1200);
    };

    // Autofocus the name input on mount (step 1).
    useEffect(() => {
        nameRef.current?.focus();
    }, []);

    // Persist the in-progress draft on EVERY field change so it survives an
    // island collapse (step 2). Merged patch is written to island state.
    const update = (patch: Partial<CountdownFormState>) => {
        setForm((prev) => {
            const next = { ...prev, ...patch };
            dispatch({ type: 'SET_COUNTDOWN_FORM_DRAFT', payload: next });
            return next;
        });
    };

    // Trigger the hidden file input (must be a real <button> so the island's
    // pointerdown gesture handler — which only bails on closest('button') — does
    // not collapse the expanded island).
    const handleBgUploadClick = (e: React.MouseEvent) => {
        e.stopPropagation();
        bgFileRef.current?.click();
    };

    // Upload the picked image to the cloud server via the shared axios HTTP
    // infra (userApis.uploadImage → POST /upload/image). This dedicated image
    // endpoint only stores the file and returns its URL — unlike /upload/avatar
    // it does NOT touch the user's profile avatar. We pass the current
    // bgImageUrl as `oldUrl` so the server deletes the replaced image and does
    // not accumulate orphaned files. The response payload (see services/api.ts
    // response interceptor: returns response.data directly) carries the stored
    // path in `res.url`; resolve it to a renderable absolute URL and stash it.
    const handleBgFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        // Reset so re-picking the SAME file still fires onChange.
        e.target.value = '';
        if (!file) return;
        setUploadError(false);
        setUploading(true);
        try {
            const res: any = await userApis.uploadImage(file, form.bgImageUrl || undefined);
            if (res && res.url) {
                update({
                    bgImageUrl: resolveApiAssetUrl(res.url),
                    bgImageOffset: { ...BG_OFFSET_DEFAULT },
                });
            } else {
                setUploadError(true);
            }
        } catch {
            setUploadError(true);
        } finally {
            setUploading(false);
        }
    };

    // Smart defaults on TYPE change (step 2).
    const handleTypeChange = (type: CountdownEventType) => {
        if (type === 'birthday') update({ type, countMode: 'countdown', repeat: true });
        else if (type === 'anniversary') update({ type, countMode: 'countup', repeat: false });
        else update({ type }); // custom: leave countMode/repeat unchanged
    };

    const savedEvent =
        mode === 'edit' ? countdownEvents.find((e) => e.id === countdownSelectedId) ?? null : null;

    // Countup cannot target a future date (step 3). Compared against local today.
    const isFutureCountup =
        form.countMode === 'countup' && form.date !== '' && form.date > todayStr;

    const nameError = showErrors && form.name.trim() === '';
    const dateError = showErrors && form.date === '';

    // Yearly-repeat toggle shown for countdown mode OR birthday/anniversary types.
    const showRepeatToggle =
        form.countMode === 'countdown' || form.type === 'birthday' || form.type === 'anniversary';
    const dateLabel = form.countMode === 'countup' ? '起始日' : '目标日';

    const handleSave = async (e: React.MouseEvent) => {
        e.stopPropagation();
        // Required-field validation + countup future-date guard (steps 3 & 4).
        if (form.name.trim() === '' || form.date === '' || isFutureCountup) {
            setShowErrors(true);
            return;
        }

        if (mode === 'add') {
            const newEvent: CountdownEvent = {
                id: crypto.randomUUID(),
                name: form.name.trim(),
                type: form.type,
                countMode: form.countMode,
                date: form.date,
                repeat: form.repeat,
                color: form.color,
                bgImageUrl: form.bgImageUrl,
                bgImageOffset: form.bgImageOffset,
                textColor: form.textColor,
                listBlurIntensity: form.listBlurIntensity,
                detailBlurIntensity: form.detailBlurIntensity,
                bgImageScale: form.bgImageScale,
            };
            const next = [...countdownEvents, newEvent];
            await saveCountdownEvents(next);
            dispatch({ type: 'SET_COUNTDOWN_EVENTS', payload: next });
            dispatch({ type: 'SET_COUNTDOWN_FORM_DRAFT', payload: null });
            dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'list' });
            return;
        }

        // edit: target id from the selected id (fallback to draft's id).
        const targetId = countdownSelectedId ?? savedEvent?.id ?? countdownFormDraft?.id ?? null;
        if (!targetId) {
            setShowErrors(true);
            return;
        }
        const updated: CountdownEvent = {
            id: targetId,
            name: form.name.trim(),
            type: form.type,
            countMode: form.countMode,
            date: form.date,
            repeat: form.repeat,
            color: form.color,
            bgImageUrl: form.bgImageUrl,
            bgImageOffset: form.bgImageOffset,
            textColor: form.textColor,
            listBlurIntensity: form.listBlurIntensity,
            detailBlurIntensity: form.detailBlurIntensity,
            bgImageScale: form.bgImageScale,
        };
        const next = countdownEvents.map((ev) => (ev.id === targetId ? updated : ev));
        await saveCountdownEvents(next);
        dispatch({ type: 'SET_COUNTDOWN_EVENTS', payload: next });
        dispatch({ type: 'SET_COUNTDOWN_FORM_DRAFT', payload: null });
        dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'detail' });
    };

    // Dirty check (step 6): add → any user-entered content; edit → differs from saved.
    const isDirty = (() => {
        if (mode === 'edit') {
            if (!savedEvent) return form.name.trim() !== '' || form.date !== '';
            return (
                form.name !== savedEvent.name ||
                form.type !== savedEvent.type ||
                form.countMode !== savedEvent.countMode ||
                form.date !== savedEvent.date ||
                form.repeat !== savedEvent.repeat ||
                form.color !== savedEvent.color ||
                (form.bgImageUrl ?? null) !== (savedEvent.bgImageUrl ?? null) ||
                form.textColor !== (savedEvent.textColor ?? TEXT_COLOR_DEFAULT) ||
                form.bgImageOffset.x !== (savedEvent.bgImageOffset?.x ?? BG_OFFSET_DEFAULT.x) ||
                form.bgImageOffset.y !== (savedEvent.bgImageOffset?.y ?? BG_OFFSET_DEFAULT.y) ||
                form.listBlurIntensity !== (savedEvent.listBlurIntensity ?? LIST_BLUR_DEFAULT) ||
                form.detailBlurIntensity !== (savedEvent.detailBlurIntensity ?? DETAIL_BLUR_DEFAULT) ||
                form.bgImageScale !== (savedEvent.bgImageScale ?? BG_IMAGE_SCALE_DEFAULT)
            );
        }
        return (
            form.name.trim() !== '' ||
            form.date !== '' ||
            form.type !== ADD_DEFAULTS.type ||
            form.countMode !== ADD_DEFAULTS.countMode ||
            form.repeat !== ADD_DEFAULTS.repeat ||
            form.color !== ADD_DEFAULTS.color ||
            form.bgImageUrl !== null
        );
    })();

    const backTarget: CountdownPage = mode === 'add' ? 'list' : 'detail';

    const navigateBack = () => {
        dispatch({ type: 'SET_COUNTDOWN_FORM_DRAFT', payload: null });
        dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: backTarget });
    };

    const handleBack = (e: React.MouseEvent) => {
        e.stopPropagation();
        if (isDirty) {
            setConfirmDiscard(true);
            return;
        }
        navigateBack();
    };

    // Bug 5: delete the event from persistence and return to the list. Reuses the
    // same save/dispatch path the detail page's delete previously used.
    const handleDelete = async (e: React.MouseEvent) => {
        e.stopPropagation();
        const targetId = countdownSelectedId ?? savedEvent?.id ?? countdownFormDraft?.id ?? null;
        if (!targetId) return;
        const next = countdownEvents.filter((ev) => ev.id !== targetId);
        await saveCountdownEvents(next);
        dispatch({ type: 'SET_COUNTDOWN_EVENTS', payload: next });
        dispatch({ type: 'SET_COUNTDOWN_FORM_DRAFT', payload: null });
        dispatch({ type: 'SET_COUNTDOWN_SELECTED_ID', payload: null });
        dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'list' });
    };

    const pillStyle = (active: boolean): React.CSSProperties =>
        active
            ? { background: 'rgba(255,255,255,0.16)', color: 'rgba(255,255,255,0.95)' }
            : { background: 'rgba(255,255,255,0.06)', color: 'rgba(255,255,255,0.6)' };

    return (
        <div className="h-full flex flex-col">
            {/* Header: back · title · save */}
            <div className="flex items-center justify-between shrink-0 pb-2">
                <button
                    onClick={handleBack}
                    className="flex items-center justify-center w-7 h-7 rounded-full transition-colors"
                    style={{ background: 'rgba(255,255,255,0.08)', color: 'rgba(255,255,255,0.85)' }}
                >
                    <span className="material-symbols-outlined text-[18px] leading-none">
                        chevron_left
                    </span>
                </button>
                <span className="text-[13px] font-semibold" style={{ color: 'rgba(255,255,255,0.9)' }}>
                    {mode === 'add' ? '新建倒数日' : '编辑倒数日'}
                </span>
                <button
                    onClick={handleSave}
                    className="px-3 py-1 rounded-full text-[12px] font-semibold transition-colors"
                    style={{ background: form.color, color: '#fff' }}
                >
                    保存
                </button>
            </div>

            {/* Two-column body (task 016): live preview + bg-image upload on the
                LEFT, the scrollable form fields on the RIGHT. Fits inside the now
                540px-wide island (task 014). */}
            <div className="flex-1 min-h-0 flex gap-3 pt-2">
                {/* Left column: preview card + upload control. */}
                <div className="shrink-0 flex flex-col gap-2" style={{ width: 200 }}>
                    <CountdownPreviewCard
                        form={form}
                        todayStr={todayStr}
                        onMouseDown={handlePreviewMouseDown}
                        onMouseMove={handlePreviewMouseMove}
                        onMouseUp={endPreviewDrag}
                        onMouseLeave={endPreviewDrag}
                        isDragging={isDragging}
                        showDragHint={showDragHint}
                        onWheel={handlePreviewWheel}
                        scaleIndicatorVisible={scaleIndicatorVisible}
                        scaleIndicatorValue={scaleIndicatorValue}
                    />

                    {/* Hidden native file input, triggered by the button below. */}
                    <input
                        ref={bgFileRef}
                        type="file"
                        accept="image/*"
                        onChange={handleBgFileChange}
                        style={{ display: 'none' }}
                    />
                    <button
                        onClick={handleBgUploadClick}
                        disabled={uploading}
                        className="flex items-center justify-center gap-1 py-1.5 rounded-full text-[12px] font-semibold transition-colors"
                        style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.9)' }}
                    >
                        <span className="material-symbols-outlined text-[16px] leading-none">
                            image
                        </span>
                        {uploading ? '上传中…' : form.bgImageUrl ? '更换背景图' : '添加背景图'}
                    </button>

                    {form.bgImageUrl && (
                        <button
                            onClick={(e) => {
                                e.stopPropagation();
                                update({ bgImageUrl: null });
                            }}
                            className="text-[11px] font-medium"
                            style={{ color: 'rgba(255,255,255,0.55)', background: 'transparent' }}
                        >
                            移除背景图
                        </button>
                    )}

                    {uploadError && (
                        <span className="text-[11px] font-medium" style={{ color: '#FF5A5F' }}>
                            上传失败，请重试
                        </span>
                    )}

                    {/* Frosted-glass blur intensity sliders (task 019). EDIT page only,
                        and only when a background image is set — the blur is applied to
                        the image overlay in list/detail rendering. Each is a full-width
                        native range restyled to a thin dark track + circular thumb via
                        the scoped .cd-blur-slider CSS below. The current px value sits to
                        the right of each slider. The countdown root already stops
                        pointerdown, but we also stop it here so dragging the range never
                        bubbles to the island's collapse gesture. */}
                    {mode === 'edit' && hasBgImage && (
                        <div
                            className="flex flex-col gap-2 pt-1"
                            onPointerDown={(e) => e.stopPropagation()}
                            onMouseDown={(e) => e.stopPropagation()}
                        >
                            <style>{`
                                .cd-blur-slider {
                                    -webkit-appearance: none;
                                    appearance: none;
                                    height: 4px;
                                    border-radius: 9999px;
                                    background: rgba(255,255,255,0.16);
                                    outline: none;
                                    cursor: pointer;
                                }
                                .cd-blur-slider::-webkit-slider-thumb {
                                    -webkit-appearance: none;
                                    appearance: none;
                                    width: 14px;
                                    height: 14px;
                                    border-radius: 9999px;
                                    background: #fff;
                                    border: none;
                                    box-shadow: 0 1px 3px rgba(0,0,0,0.4);
                                    cursor: pointer;
                                }
                                .cd-blur-slider::-moz-range-thumb {
                                    width: 14px;
                                    height: 14px;
                                    border-radius: 9999px;
                                    background: #fff;
                                    border: none;
                                    box-shadow: 0 1px 3px rgba(0,0,0,0.4);
                                    cursor: pointer;
                                }
                            `}</style>

                            {/* List-card blur */}
                            <div className="flex flex-col gap-1">
                                <span
                                    className="text-[11px] font-medium"
                                    style={{ color: 'rgba(255,255,255,0.5)' }}
                                >
                                    首页卡片模糊
                                </span>
                                <div className="flex items-center gap-2">
                                    <input
                                        type="range"
                                        min="0"
                                        max="20"
                                        step="1"
                                        value={form.listBlurIntensity}
                                        onChange={(e) => {
                                            e.stopPropagation();
                                            update({ listBlurIntensity: Number(e.target.value) });
                                        }}
                                        className="cd-blur-slider flex-1 min-w-0"
                                    />
                                    <span
                                        className="text-[11px] font-semibold text-right"
                                        style={{ color: 'rgba(255,255,255,0.7)', minWidth: 30 }}
                                    >
                                        {form.listBlurIntensity}px
                                    </span>
                                </div>
                            </div>

                            {/* Detail-card blur */}
                            <div className="flex flex-col gap-1">
                                <span
                                    className="text-[11px] font-medium"
                                    style={{ color: 'rgba(255,255,255,0.5)' }}
                                >
                                    详情模糊
                                </span>
                                <div className="flex items-center gap-2">
                                    <input
                                        type="range"
                                        min="0"
                                        max="20"
                                        step="1"
                                        value={form.detailBlurIntensity}
                                        onChange={(e) => {
                                            e.stopPropagation();
                                            update({ detailBlurIntensity: Number(e.target.value) });
                                        }}
                                        className="cd-blur-slider flex-1 min-w-0"
                                    />
                                    <span
                                        className="text-[11px] font-semibold text-right"
                                        style={{ color: 'rgba(255,255,255,0.7)', minWidth: 30 }}
                                    >
                                        {form.detailBlurIntensity}px
                                    </span>
                                </div>
                            </div>
                        </div>
                    )}
                </div>

                {/* Right column: scrollable form fields — no outer padding, hidden
                    scrollbar. scrollPaddingTop keeps the name input clear of the
                    scroll container's top edge (Bug 1); pl-1/pb-6 keep left-edge and
                    bottom content (color swatches, delete) from clipping (Bug 4). */}
                <div
                    className="flex-1 min-h-0 overflow-y-auto pr-1 pl-1 pb-6 flex flex-col gap-3"
                    style={{ scrollbarWidth: 'none', scrollPaddingTop: 8 }}
                >
                {/* Name */}
                <input
                    ref={nameRef}
                    value={form.name}
                    placeholder="事件名称"
                    onClick={(e) => e.stopPropagation()}
                    onChange={(e) => {
                        e.stopPropagation();
                        update({ name: e.target.value });
                    }}
                    className={`w-full px-3 py-2 rounded-xl text-[13px] font-semibold outline-none border-2 focus:ring-0 ${
                        nameError ? 'border-[#FF5A5F]' : 'border-transparent focus:border-blue-500'
                    }`}
                    style={{
                        background: 'rgba(255,255,255,0.06)',
                        color: 'rgba(255,255,255,0.92)',
                    }}
                />

                {/* Type selector */}
                <div className="flex gap-2">
                    {TYPE_OPTIONS.map((opt) => (
                        <button
                            key={opt.value}
                            onClick={(e) => {
                                e.stopPropagation();
                                handleTypeChange(opt.value);
                            }}
                            className="flex-1 py-1.5 rounded-full text-[12px] font-semibold transition-colors"
                            style={pillStyle(form.type === opt.value)}
                        >
                            {opt.label}
                        </button>
                    ))}
                </div>

                {/* Count-mode toggle */}
                <div className="flex gap-2">
                    {MODE_OPTIONS.map((opt) => (
                        <button
                            key={opt.value}
                            onClick={(e) => {
                                e.stopPropagation();
                                update({ countMode: opt.value });
                            }}
                            className="flex-1 py-1.5 rounded-full text-[12px] font-semibold transition-colors"
                            style={pillStyle(form.countMode === opt.value)}
                        >
                            {opt.label}
                        </button>
                    ))}
                </div>

                {/* Date field (task 021): a plain styled button that navigates to the
                    dedicated full-island datepicker page instead of opening an overlay
                    popup. It records which form page to return to, then switches to the
                    'datepicker' page; the datepicker writes the chosen ISO date back into
                    the form draft's `date` field and navigates back here. */}
                <div className="flex flex-col gap-1">
                    <span className="text-[11px] font-medium" style={{ color: 'rgba(255,255,255,0.5)' }}>
                        {dateLabel}
                    </span>
                    <button
                        onClick={(e) => {
                            e.stopPropagation();
                            dispatch({ type: 'SET_COUNTDOWN_DATEPICKER_RETURN', payload: mode });
                            dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'datepicker' });
                        }}
                        className="flex items-center px-3 py-2 rounded-xl text-[14px] font-semibold transition-colors"
                        style={{
                            width: 'fit-content',
                            background: 'rgba(255,255,255,0.06)',
                            color: form.date === '' ? 'rgba(255,255,255,0.5)' : 'rgba(255,255,255,0.92)',
                            boxShadow: dateError ? '0 0 0 1px #FF5A5F' : 'none',
                        }}
                    >
                        {form.date === '' ? '选择日期' : formatCnDate(form.date)}
                    </button>
                    {dateError && (
                        <span className="text-[11px] font-medium" style={{ color: '#FF5A5F' }}>
                            请选择{dateLabel}
                        </span>
                    )}
                    {isFutureCountup && (
                        <span className="text-[11px] font-medium" style={{ color: '#FF5A5F' }}>
                            正数日不能选择未来日期
                        </span>
                    )}
                </div>

                {/* Yearly-repeat toggle */}
                {showRepeatToggle && (
                    <button
                        onClick={(e) => {
                            e.stopPropagation();
                            update({ repeat: !form.repeat });
                        }}
                        className="flex items-center justify-between px-3 py-2 rounded-xl transition-colors"
                        style={{ background: 'rgba(255,255,255,0.06)' }}
                    >
                        <span className="text-[12px] font-medium" style={{ color: 'rgba(255,255,255,0.8)' }}>
                            每年重复
                        </span>
                        <span
                            className="flex items-center rounded-full transition-colors"
                            style={{
                                width: 34,
                                height: 20,
                                padding: 2,
                                justifyContent: form.repeat ? 'flex-end' : 'flex-start',
                                background: form.repeat ? form.color : 'rgba(255,255,255,0.18)',
                            }}
                        >
                            <span
                                style={{
                                    width: 16,
                                    height: 16,
                                    borderRadius: '9999px',
                                    background: '#fff',
                                }}
                            />
                        </span>
                    </button>
                )}

                {/* Color swatches */}
                <div className="flex gap-2 flex-wrap">
                    {COLOR_PRESETS.map((c) => (
                        <button
                            key={c}
                            onClick={(e) => {
                                e.stopPropagation();
                                update({ color: c });
                            }}
                            className="rounded-full transition-transform"
                            style={{
                                width: 26,
                                height: 26,
                                background: c,
                                boxShadow:
                                    form.color === c
                                        ? '0 0 0 2px rgba(255,255,255,0.9)'
                                        : '0 0 0 1px rgba(255,255,255,0.1)',
                            }}
                        />
                    ))}
                </div>

                {/* Text-color picker (task 017): shown ONLY when a background image
                    is set. Same swatch markup as the event-color picker, targeting
                    textColor. The preview title + number reflect it immediately. */}
                {hasBgImage && (
                    <div className="flex flex-col gap-1">
                        <span
                            className="text-[11px] font-medium"
                            style={{ color: 'rgba(255,255,255,0.5)' }}
                        >
                            文字颜色
                        </span>
                        <div className="flex gap-2 flex-wrap">
                            {TEXT_COLOR_PRESETS.map((c) => (
                                <button
                                    key={c}
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        update({ textColor: c });
                                    }}
                                    className="rounded-full transition-transform"
                                    style={{
                                        width: 26,
                                        height: 26,
                                        background: c,
                                        boxShadow:
                                            form.textColor === c
                                                ? '0 0 0 2px rgba(255,255,255,0.9)'
                                                : '0 0 0 1px rgba(255,255,255,0.1)',
                                    }}
                                />
                            ))}
                        </div>
                    </div>
                )}

                {/* Delete (edit only): red text button → two-step inline confirm.
                    Moved here from the detail page per Bug 5. Both states are real
                    <button>s so the island's pointer-capture doesn't collapse it. */}
                {mode === 'edit' && (
                    <div className="flex items-center justify-center pt-2 pb-1">
                        {confirmDelete ? (
                            <div className="flex items-center gap-2">
                                <span
                                    className="text-[12px] font-semibold"
                                    style={{ color: 'rgba(255,255,255,0.85)' }}
                                >
                                    确认删除？
                                </span>
                                <button
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        setConfirmDelete(false);
                                    }}
                                    className="px-3 py-1 rounded-full text-[12px] font-semibold"
                                    style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}
                                >
                                    取消
                                </button>
                                <button
                                    onClick={handleDelete}
                                    className="px-3 py-1 rounded-full text-[12px] font-semibold"
                                    style={{ background: '#FF5A5F', color: '#fff' }}
                                >
                                    确认
                                </button>
                            </div>
                        ) : (
                            <button
                                onClick={(e) => {
                                    e.stopPropagation();
                                    setConfirmDelete(true);
                                }}
                                className="text-[12px] font-semibold"
                                style={{ color: '#FF5A5F', background: 'transparent' }}
                            >
                                删除事件
                            </button>
                        )}
                    </div>
                )}
                </div>
            </div>

            {/* Discard-confirmation row (dirty back/cancel) */}
            {confirmDiscard && (
                <div className="flex items-center justify-between gap-2 shrink-0 pt-2">
                    <span className="text-[12px] font-semibold" style={{ color: 'rgba(255,255,255,0.85)' }}>
                        放弃修改？
                    </span>
                    <div className="flex gap-2">
                        <button
                            onClick={(e) => {
                                e.stopPropagation();
                                setConfirmDiscard(false);
                            }}
                            className="px-3 py-1 rounded-full text-[12px] font-semibold"
                            style={{ background: 'rgba(255,255,255,0.1)', color: 'rgba(255,255,255,0.8)' }}
                        >
                            取消
                        </button>
                        <button
                            onClick={(e) => {
                                e.stopPropagation();
                                navigateBack();
                            }}
                            className="px-3 py-1 rounded-full text-[12px] font-semibold"
                            style={{ background: '#FF5A5F', color: '#fff' }}
                        >
                            确定
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
};

// ── Detail page ──────────────────────────────────────────────────
interface CountdownDetailPageProps {
    countdownEvents: CountdownEvent[];
    countdownSelectedId?: string | null;
    dispatch: React.Dispatch<CountdownAction>;
}

const CountdownDetailPage: React.FC<CountdownDetailPageProps> = ({
    countdownEvents,
    countdownSelectedId,
    dispatch,
}) => {
    const todayStr = localTodayStr();

    const currentEvent =
        countdownEvents.find((e) => e.id === countdownSelectedId) ?? null;

    // Squircle clip-path measurement (task 020). The card is width:100% (capped
    // at 260) × height 200 — not strictly fixed — so we measure the rendered card
    // with a ResizeObserver (attached via a callback ref so it re-observes when
    // the image/non-image branch swaps) and regenerate the clip path at the real
    // pixel size. clipPathUnits='userSpaceOnUse' means the path is expressed in
    // the card's own pixel coordinate system.
    const [cardSize, setCardSize] = useState({ width: 260, height: 200 });
    const roRef = useRef<ResizeObserver | null>(null);
    const cardRef = useCallback((node: HTMLDivElement | null) => {
        roRef.current?.disconnect();
        if (!node) return;
        const ro = new ResizeObserver((entries) => {
            const box = entries[0].contentRect;
            setCardSize({
                width: Math.round(box.width),
                height: Math.round(box.height),
            });
        });
        ro.observe(node);
        roRef.current = ro;
    }, []);

    // Guard against a stale selected id (event deleted elsewhere): bounce to list.
    // Done in an effect so we don't dispatch during render.
    useEffect(() => {
        if (!currentEvent) {
            dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'list' });
        }
    }, [currentEvent, dispatch]);

    if (!currentEvent) return null;

    const { days, status } = calcEventDays(currentEvent, todayStr);
    const isCountup = currentEvent.countMode === 'countup';

    // Display-state derivation (step 3):
    // - status 'today'      → big "就是今天" text, no number
    // - countdown 'past'    → "已过去" prefix above, number = |days|
    // - otherwise (upcoming / countup) → number = |days| (countup is always positive)
    const showTodayText = status === 'today';
    const showPastPrefix = !isCountup && status === 'past';
    const bigNumber = Math.abs(days);

    const dateRowLabel = isCountup ? '起始日' : '目标日';

    // Background-image rendering (task 018). bgImageUrl holds a resolved absolute
    // URL; guard the optional offset/textColor for older events.
    const hasImage = currentEvent.bgImageUrl != null && currentEvent.bgImageUrl !== '';
    const offset = currentEvent.bgImageOffset ?? BG_OFFSET_DEFAULT;
    const textColor = currentEvent.textColor ?? TEXT_COLOR_DEFAULT;

    const handleBack = (e: React.MouseEvent) => {
        e.stopPropagation();
        dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'list' });
        dispatch({ type: 'SET_COUNTDOWN_SELECTED_ID', payload: null });
    };

    const handleEdit = (e: React.MouseEvent) => {
        e.stopPropagation();
        dispatch({ type: 'SET_COUNTDOWN_FORM_DRAFT', payload: currentEvent });
        dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: 'edit' });
    };

    return (
        <div className="h-full flex flex-col">
            {/* Top bar: back (←) · edit (✏) */}
            <div className="flex items-center justify-between shrink-0 pb-2">
                <button
                    onClick={handleBack}
                    className="flex items-center justify-center w-7 h-7 rounded-full transition-colors"
                    style={{ background: 'rgba(255,255,255,0.08)', color: 'rgba(255,255,255,0.85)' }}
                >
                    <span className="material-symbols-outlined text-[18px] leading-none">
                        chevron_left
                    </span>
                </button>
                <button
                    onClick={handleEdit}
                    className="flex items-center justify-center w-7 h-7 rounded-full transition-colors"
                    style={{ background: 'rgba(255,255,255,0.08)', color: 'rgba(255,255,255,0.85)' }}
                >
                    <span className="material-symbols-outlined text-[18px] leading-none">edit</span>
                </button>
            </div>

            {/* Centered squircle card (task 020). A measured superellipse clip-path
                replaces the old borderRadius:24 + overflow:hidden so all four corners
                read as a true squircle; the clip on the container also clips the
                absolute image/overlay children. Layout: title (top, centered, 16px
                pt) → day number (vertically centered) → date (absolute bottom, 16px
                pb). The '天' unit label was removed. */}
            <div className="flex-1 min-h-0 flex items-center justify-center">
                {/* Zero-size SVG holding the clipPath def; rendered immediately before
                    the card. Path is regenerated at the card's measured pixel size. */}
                <svg width={0} height={0} aria-hidden style={{ position: 'absolute' }}>
                    <defs>
                        <clipPath id="cd-detail-card" clipPathUnits="userSpaceOnUse">
                            <path
                                d={generateFullSquirclePath(
                                    cardSize.width,
                                    cardSize.height,
                                    24,
                                    SQUIRCLE_SMOOTHNESS_EXPANDED,
                                )}
                            />
                        </clipPath>
                    </defs>
                </svg>

                {hasImage ? (
                    // Three-layer treatment (task 018): image + frosted-glass. The
                    // container's clip-path clips all three layers to the squircle.
                    <div
                        ref={cardRef}
                        style={{
                            position: 'relative',
                            width: '100%',
                            maxWidth: 260,
                            height: 200,
                            clipPath: 'url(#cd-detail-card)',
                        }}
                    >
                        {/* Image layer */}
                        <div
                            style={{
                                position: 'absolute',
                                inset: 0,
                                backgroundImage: `url('${resolveApiAssetUrl(currentEvent.bgImageUrl)}')`,
                                backgroundPosition: `${offset.x}% ${offset.y}%`,
                                backgroundSize: bgSizeForScale(currentEvent.bgImageScale),
                                backgroundRepeat: 'no-repeat',
                            }}
                        />
                        {/* Frosted-glass overlay (blur 8, rgba(0,0,0,0.40)). */}
                        <div
                            style={{
                                position: 'absolute',
                                inset: 0,
                                backdropFilter: `blur(${currentEvent.detailBlurIntensity ?? DETAIL_BLUR_DEFAULT}px)`,
                                WebkitBackdropFilter: `blur(${currentEvent.detailBlurIntensity ?? DETAIL_BLUR_DEFAULT}px)`,
                                background: 'rgba(0,0,0,0.40)',
                                pointerEvents: 'none',
                            }}
                        />

                        {/* Text content — all in the event's textColor. */}
                        <div
                            className="relative z-10 h-full"
                            style={{ color: textColor, textShadow: '0 1px 3px rgba(0,0,0,0.45)' }}
                        >
                            {/* Title: top, centered, 16px top padding. */}
                            <div
                                className="absolute left-0 right-0 top-0 text-center px-4"
                                style={{ paddingTop: 16 }}
                            >
                                <span className="block truncate text-[14px] font-semibold">
                                    {currentEvent.name || '未命名'}
                                </span>
                            </div>

                            {/* Day number: vertically centered in remaining space. */}
                            <div className="absolute inset-0 flex flex-col items-center justify-center px-4">
                                {showPastPrefix && (
                                    <span className="text-[13px] font-medium" style={{ opacity: 0.85 }}>
                                        已过去
                                    </span>
                                )}

                                {showTodayText ? (
                                    <span
                                        className="font-bold leading-none tracking-tight"
                                        style={{ fontSize: 40 }}
                                    >
                                        就是今天
                                    </span>
                                ) : (
                                    <span
                                        className="font-bold leading-none tracking-tight"
                                        style={{ fontSize: 56 }}
                                    >
                                        {bigNumber}
                                    </span>
                                )}
                            </div>

                            {/* Date: pinned to the card's bottom edge, 16px bottom padding. */}
                            <div
                                className="absolute left-0 right-0 bottom-0 text-center px-4"
                                style={{ paddingBottom: 16 }}
                            >
                                <span className="block truncate text-[11px] font-medium" style={{ opacity: 0.85 }}>
                                    {dateRowLabel}：{formatCnDate(currentEvent.date)}
                                </span>
                            </div>
                        </div>
                    </div>
                ) : (
                    <div
                        ref={cardRef}
                        style={{
                            position: 'relative',
                            width: '100%',
                            maxWidth: 260,
                            height: 200,
                            clipPath: 'url(#cd-detail-card)',
                            background: 'rgba(255,255,255,0.06)',
                        }}
                    >
                        {/* Title: top, centered, 16px top padding. The colored top
                            band was replaced by the squircle-clipped card; the event
                            color accent lives on the day number below. */}
                        <div
                            className="absolute left-0 right-0 top-0 text-center px-4"
                            style={{ paddingTop: 16 }}
                        >
                            <span
                                className="block truncate text-[14px] font-semibold"
                                style={{ color: '#fff' }}
                            >
                                {currentEvent.name || '未命名'}
                            </span>
                        </div>

                        {/* Day number: vertically centered in remaining space. */}
                        <div className="absolute inset-0 flex flex-col items-center justify-center px-4">
                            {showPastPrefix && (
                                <span
                                    className="text-[13px] font-medium"
                                    style={{ color: 'rgba(255,255,255,0.6)' }}
                                >
                                    已过去
                                </span>
                            )}

                            {showTodayText ? (
                                <span
                                    className="font-bold leading-none tracking-tight"
                                    style={{ fontSize: 40, color: currentEvent.color }}
                                >
                                    就是今天
                                </span>
                            ) : (
                                <span
                                    className="font-bold leading-none tracking-tight"
                                    style={{ fontSize: 56, color: currentEvent.color }}
                                >
                                    {bigNumber}
                                </span>
                            )}
                        </div>

                        {/* Date: pinned to the card's bottom edge, 16px bottom padding. */}
                        <div
                            className="absolute left-0 right-0 bottom-0 text-center px-4"
                            style={{ paddingBottom: 16 }}
                        >
                            <span
                                className="block truncate text-[11px] font-medium"
                                style={{ color: 'rgba(255,255,255,0.5)' }}
                            >
                                {dateRowLabel}：{formatCnDate(currentEvent.date)}
                            </span>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

// ── Full-island date-selection page (task 021) ───────────────────
// Replaces the old overlay DatePicker: a pure-black, full-island calendar page
// that writes the chosen ISO date back into the form draft and returns to the
// originating form page. Every interactive control is a real <button> (auto-safe
// against the island's pointerdown collapse gesture) and also calls
// e.stopPropagation().
const WEEKDAY_LABELS = ['日', '一', '二', '三', '四', '五', '六'];
const DATEPICKER_FALLBACK_COLOR = '#4A9EFF';

interface CountdownDatePickerPageProps {
    countdownFormDraft?: Partial<CountdownEvent> | null;
    countdownDatePickerReturn?: 'add' | 'edit' | null;
    dispatch: React.Dispatch<CountdownAction>;
}

const CountdownDatePickerPage: React.FC<CountdownDatePickerPageProps> = ({
    countdownFormDraft,
    countdownDatePickerReturn,
    dispatch,
}) => {
    const returnPage: 'add' | 'edit' = countdownDatePickerReturn ?? 'add';
    const selectedIso = countdownFormDraft?.date ?? '';
    const eventColor = countdownFormDraft?.color || DATEPICKER_FALLBACK_COLOR;
    const todayStr = localTodayStr();

    // Viewed month — seed from the currently-selected date, else today. Local
    // state so month nav never touches the form draft (only a day pick does).
    const seedIso = selectedIso !== '' ? selectedIso : todayStr;
    const [seedY, seedM] = seedIso.split('-').map((n) => parseInt(n, 10));
    const [viewYear, setViewYear] = useState(seedY);
    const [viewMonth, setViewMonth] = useState(seedM - 1); // 0-based

    const goPrevMonth = (e: React.MouseEvent) => {
        e.stopPropagation();
        if (viewMonth === 0) {
            setViewMonth(11);
            setViewYear(viewYear - 1);
        } else {
            setViewMonth(viewMonth - 1);
        }
    };
    const goNextMonth = (e: React.MouseEvent) => {
        e.stopPropagation();
        if (viewMonth === 11) {
            setViewMonth(0);
            setViewYear(viewYear + 1);
        } else {
            setViewMonth(viewMonth + 1);
        }
    };

    const handleBack = (e: React.MouseEvent) => {
        e.stopPropagation();
        dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: returnPage });
    };

    const isoFor = (day: number): string =>
        `${viewYear}-${String(viewMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

    const handlePickDay = (e: React.MouseEvent, day: number) => {
        e.stopPropagation();
        const iso = isoFor(day);
        // Merge into the existing draft so a name/type the user already entered
        // survives the form's unmount/remount round-trip (form re-seeds from draft).
        dispatch({
            type: 'SET_COUNTDOWN_FORM_DRAFT',
            payload: { ...(countdownFormDraft ?? {}), date: iso },
        });
        dispatch({ type: 'SET_COUNTDOWN_PAGE', payload: returnPage });
    };

    // 6-row × 7-col grid: leading blanks for the weekday of the 1st, then day
    // numbers, padded out to 42 cells.
    const firstWeekday = new Date(viewYear, viewMonth, 1).getDay(); // 0=Sun
    const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
    const cells: (number | null)[] = [];
    for (let i = 0; i < firstWeekday; i++) cells.push(null);
    for (let d = 1; d <= daysInMonth; d++) cells.push(d);
    while (cells.length < 42) cells.push(null);

    const arrowBtnStyle: React.CSSProperties = {
        background: 'rgba(255,255,255,0.08)',
        color: 'rgba(255,255,255,0.85)',
    };

    return (
        <div
            className="flex flex-col"
            style={{
                background: '#000000',
                // Break out of the expanded content's px-9 py-5 padding so the page
                // paints the full 540×420 island. Rounded to sit inside the squircle
                // shell; the parent content wrapper is overflow-hidden.
                margin: '-20px -36px',
                width: 'calc(100% + 72px)',
                height: 'calc(100% + 40px)',
                borderRadius: 60,
                padding: '18px 24px',
                overflow: 'hidden',
            }}
        >
            {/* Top row: back (far left) · centered month nav */}
            <div className="relative flex items-center justify-center shrink-0" style={{ height: 36 }}>
                <button
                    onClick={handleBack}
                    className="absolute left-0 flex items-center justify-center w-8 h-8 rounded-full text-[20px] leading-none transition-colors"
                    style={arrowBtnStyle}
                >
                    ‹
                </button>
                <div className="flex items-center gap-4">
                    <button
                        onClick={goPrevMonth}
                        className="flex items-center justify-center w-7 h-7 rounded-full text-[18px] leading-none transition-colors"
                        style={arrowBtnStyle}
                    >
                        ‹
                    </button>
                    <span className="text-[15px] font-semibold" style={{ color: 'rgba(255,255,255,0.95)' }}>
                        {viewYear}年{viewMonth + 1}月
                    </span>
                    <button
                        onClick={goNextMonth}
                        className="flex items-center justify-center w-7 h-7 rounded-full text-[18px] leading-none transition-colors"
                        style={arrowBtnStyle}
                    >
                        ›
                    </button>
                </div>
            </div>

            {/* Weekday header */}
            <div
                className="grid shrink-0 pt-3"
                style={{ gridTemplateColumns: 'repeat(7, 44px)', justifyContent: 'center' }}
            >
                {WEEKDAY_LABELS.map((w) => (
                    <div
                        key={w}
                        className="flex items-center justify-center text-[11px] font-medium"
                        style={{ height: 24, color: 'rgba(255,255,255,0.4)' }}
                    >
                        {w}
                    </div>
                ))}
            </div>

            {/* Day grid: 6 rows × 7 cols, cells 44×32. */}
            <div
                className="grid pt-1"
                style={{
                    gridTemplateColumns: 'repeat(7, 44px)',
                    gridAutoRows: '32px',
                    justifyContent: 'center',
                }}
            >
                {cells.map((day, idx) => {
                    if (day === null) {
                        return <div key={idx} style={{ width: 44, height: 32 }} />;
                    }
                    const iso = isoFor(day);
                    const isSelected = iso === selectedIso;
                    const isToday = iso === todayStr;
                    return (
                        <button
                            key={idx}
                            onClick={(e) => handlePickDay(e, day)}
                            className="flex items-center justify-center"
                            style={{ width: 44, height: 32, background: 'transparent' }}
                        >
                            <span
                                className="flex items-center justify-center text-[13px] font-medium"
                                style={{
                                    width: 30,
                                    height: 30,
                                    borderRadius: 9999,
                                    background: isSelected ? eventColor : 'transparent',
                                    color: isSelected ? '#fff' : 'rgba(255,255,255,0.85)',
                                    // TODAY: subtle white ring (skipped when it's the
                                    // selected cell, which already reads as filled).
                                    boxShadow:
                                        !isSelected && isToday
                                            ? 'inset 0 0 0 1px rgba(255,255,255,0.28)'
                                            : 'none',
                                }}
                            >
                                {day}
                            </span>
                        </button>
                    );
                })}
            </div>
        </div>
    );
};

const ExpandedCountdownCard: React.FC<ExpandedCountdownCardProps> = (props) => {
    // Exhaustive page switch.
    let content: React.ReactNode;
    switch (props.countdownPage) {
        case 'list':
            content = <CountdownListPage {...props} />;
            break;
        case 'add':
        case 'edit':
            content = (
                <CountdownFormPage
                    mode={props.countdownPage}
                    countdownEvents={props.countdownEvents}
                    countdownSelectedId={props.countdownSelectedId}
                    countdownFormDraft={props.countdownFormDraft}
                    dispatch={props.dispatch}
                />
            );
            break;
        case 'datepicker':
            content = (
                <CountdownDatePickerPage
                    countdownFormDraft={props.countdownFormDraft}
                    countdownDatePickerReturn={props.countdownDatePickerReturn}
                    dispatch={props.dispatch}
                />
            );
            break;
        case 'detail':
            content = (
                <CountdownDetailPage
                    countdownEvents={props.countdownEvents}
                    countdownSelectedId={props.countdownSelectedId}
                    dispatch={props.dispatch}
                />
            );
            break;
        default: {
            // Exhaustiveness guard — compile error if a CountdownPage is unhandled.
            const _exhaustive: never = props.countdownPage;
            content = _exhaustive;
        }
    }

    // The island's gesture handler (DynamicIslandWidget handlePointerDown) captures
    // the pointer on any pointerdown that reaches it and collapses on release —
    // it only bails when the target is inside a <button> (`closest('button')`).
    // Countdown rows and several controls are <div>s, so a bubble-phase onClick
    // stopPropagation is too late. Stop pointerdown at the countdown root so the
    // ENTIRE content area (list rows, form fields, detail buttons) can be tapped
    // without collapsing the island. Interactive elements still receive their click.
    return (
        <div className="w-full h-full" onPointerDown={(e) => e.stopPropagation()}>
            {content}
        </div>
    );
};

export default ExpandedCountdownCard;
