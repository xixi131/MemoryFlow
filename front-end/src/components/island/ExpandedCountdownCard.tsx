import React, { useState, useEffect, useRef } from 'react';
import type { CountdownEvent, CountdownEventType, CountdownMode } from '../../types/countdown';
import { calcEventDays } from '../../utils/countdownCalc';
import DatePicker from '../DatePicker';
import { saveCountdownEvents } from '../../api/countdownApi';
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
}

const ADD_DEFAULTS: CountdownFormState = {
    name: '',
    type: 'custom',
    countMode: 'countdown',
    date: '',
    repeat: false,
    color: DEFAULT_COLOR,
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
              }
            : { ...ADD_DEFAULTS };
        return draft ? ({ ...base, ...draft } as CountdownFormState) : base;
    }
    return draft ? ({ ...ADD_DEFAULTS, ...draft } as CountdownFormState) : { ...ADD_DEFAULTS };
}

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
                form.color !== savedEvent.color
            );
        }
        return (
            form.name.trim() !== '' ||
            form.date !== '' ||
            form.type !== ADD_DEFAULTS.type ||
            form.countMode !== ADD_DEFAULTS.countMode ||
            form.repeat !== ADD_DEFAULTS.repeat ||
            form.color !== ADD_DEFAULTS.color
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

            {/* Scrollable form column — no outer padding, hidden scrollbar. */}
            <div
                className="flex-1 min-h-0 overflow-y-auto pr-1 flex flex-col gap-3"
                style={{ scrollbarWidth: 'none' }}
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
                    className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                    style={{
                        background: 'rgba(255,255,255,0.06)',
                        color: 'rgba(255,255,255,0.92)',
                        border: nameError ? '1px solid #FF5A5F' : '1px solid transparent',
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
                    <div
                        onClick={(e) => e.stopPropagation()}
                        onMouseDown={(e) => e.stopPropagation()}
                        className="rounded-2xl"
                        style={{
                            width: 'fit-content',
                            boxShadow: dateError ? '0 0 0 1px #FF5A5F' : 'none',
                            borderRadius: 16,
                        }}
                    >
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

const ExpandedCountdownCard: React.FC<ExpandedCountdownCardProps> = (props) => {
    // Exhaustive page switch. 'detail' | 'add' | 'edit' are owned by tasks 013/012;
    // render minimal placeholders for now so the switch stays type-safe.
    switch (props.countdownPage) {
        case 'list':
            return <CountdownListPage {...props} />;
        case 'add':
        case 'edit':
            return (
                <CountdownFormPage
                    mode={props.countdownPage}
                    countdownEvents={props.countdownEvents}
                    countdownSelectedId={props.countdownSelectedId}
                    countdownFormDraft={props.countdownFormDraft}
                    dispatch={props.dispatch}
                />
            );
        case 'detail':
            // TODO(013): detail page.
            return null;
        default: {
            // Exhaustiveness guard — compile error if a CountdownPage is unhandled.
            const _exhaustive: never = props.countdownPage;
            return _exhaustive;
        }
    }
};

export default ExpandedCountdownCard;
