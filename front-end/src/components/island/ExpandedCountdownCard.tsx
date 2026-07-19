import React, { useState, useEffect, useRef } from 'react';
import type { CountdownEvent, CountdownEventType, CountdownMode } from '../../types/countdown';
import { calcEventDays } from '../../utils/countdownCalc';
import DatePicker from '../DatePicker';
import { saveCountdownEvents } from '../../api/countdownApi';
import userApis from '../../api/userApis';
import { resolveApiAssetUrl } from '../../utils/resolveApiAssetUrl';

// Schema defaults for the background-image fields added in task 016. Older
// persisted events (and freshly constructed ones) may lack these, so reads fall
// back to these values.
const BG_OFFSET_DEFAULT = { x: 50, y: 50 };
const TEXT_COLOR_DEFAULT = '#FFFFFF';
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
}> = ({
    form,
    todayStr,
    onMouseDown,
    onMouseMove,
    onMouseUp,
    onMouseLeave,
    isDragging = false,
    showDragHint = false,
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
                style={{
                    width: 200,
                    height: 110,
                    borderRadius: 16,
                    overflow: 'hidden',
                    position: 'relative',
                    backgroundImage: `url('${form.bgImageUrl}')`,
                    backgroundSize: 'cover',
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
    // infra (userApis.uploadAvatar → POST /upload/avatar). The response payload
    // (see services/api.ts response interceptor: returns response.data directly)
    // carries the stored path in `res.url`; resolve it to a renderable absolute
    // URL and stash it in the draft.
    const handleBgFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        // Reset so re-picking the SAME file still fires onChange.
        e.target.value = '';
        if (!file) return;
        setUploadError(false);
        setUploading(true);
        try {
            const res: any = await userApis.uploadAvatar(file);
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
                form.bgImageOffset.y !== (savedEvent.bgImageOffset?.y ?? BG_OFFSET_DEFAULT.y)
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

                {/* Date picker */}
                <div className="flex flex-col gap-1">
                    <span className="text-[11px] font-medium" style={{ color: 'rgba(255,255,255,0.5)' }}>
                        {dateLabel}
                    </span>
                    {/* Bug 3: restyle DatePicker's trigger into a compact dark chip.
                        DatePicker.tsx exposes no icon-suppression prop and renders a
                        light bg-white pill, so we override its trigger via scoped CSS.
                        Selectors target ONLY the trigger (`.relative > button`) so the
                        popover's own chevron icons stay visible. */}
                    <div
                        onClick={(e) => e.stopPropagation()}
                        onMouseDown={(e) => e.stopPropagation()}
                        className="cd-datepicker rounded-xl"
                        style={{
                            width: 'fit-content',
                            boxShadow: dateError ? '0 0 0 1px #FF5A5F' : 'none',
                            borderRadius: 12,
                        }}
                    >
                        <style>{`
                            .cd-datepicker .relative > button {
                                background: rgba(255,255,255,0.06) !important;
                                border: none !important;
                                box-shadow: none !important;
                                padding: 6px 12px !important;
                                min-width: 0 !important;
                                max-height: 36px !important;
                                border-radius: 12px !important;
                                gap: 0 !important;
                            }
                            .cd-datepicker .relative > button > .material-symbols-outlined {
                                display: none !important;
                            }
                            .cd-datepicker .relative > button > span:last-child {
                                font-size: 14px !important;
                                line-height: 1.2 !important;
                                font-weight: 600 !important;
                                color: rgba(255,255,255,0.92) !important;
                            }
                        `}</style>
                        <DatePicker
                            selectedDate={form.date || todayStr}
                            onChange={(d) => update({ date: d })}
                        />
                    </div>
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

            {/* Centered squircle card. Squircle fallback (border-radius + clip) matches
                the list page — rows/cards have no measured width at render time. */}
            <div className="flex-1 min-h-0 flex items-center justify-center">
                <div
                    style={{
                        width: '100%',
                        maxWidth: 260,
                        height: 200,
                        borderRadius: 24,
                        overflow: 'hidden',
                        background: 'rgba(255,255,255,0.06)',
                        display: 'flex',
                        flexDirection: 'column',
                    }}
                >
                    {/* Colored top band with the title in white. Reduced per Bug 5
                        so the card stays within the standard expanded height. */}
                    <div
                        className="flex items-center px-4 shrink-0"
                        style={{ height: 32, background: currentEvent.color }}
                    >
                        <span
                            className="text-[14px] font-semibold truncate"
                            style={{ color: '#fff' }}
                        >
                            {currentEvent.name || '未命名'}
                        </span>
                    </div>

                    {/* Body: big day number (or 就是今天) + unit + date row. */}
                    <div className="flex-1 flex flex-col items-center justify-center gap-1 px-4">
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
                            <div className="flex flex-col items-center">
                                <span
                                    className="font-bold leading-none tracking-tight"
                                    style={{ fontSize: 56, color: currentEvent.color }}
                                >
                                    {bigNumber}
                                </span>
                                <span
                                    className="text-[13px] font-semibold mt-1"
                                    style={{ color: 'rgba(255,255,255,0.7)' }}
                                >
                                    天
                                </span>
                            </div>
                        )}

                        <span
                            className="text-[11px] font-medium mt-1"
                            style={{ color: 'rgba(255,255,255,0.5)' }}
                        >
                            {dateRowLabel}：{formatCnDate(currentEvent.date)}
                        </span>
                    </div>
                </div>
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
