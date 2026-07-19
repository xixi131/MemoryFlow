import type { CountdownEvent } from '@/types/countdown';

export type CountdownStatus = 'upcoming' | 'today' | 'past';

export interface CountdownResult {
    days: number;
    status: CountdownStatus;
    /** ISO date string (YYYY-MM-DD) of the occurrence the result refers to. */
    effectiveDate: string;
}

const MS_PER_DAY = 86400000;

/** Parse a 'YYYY-MM-DD' string into a UTC-midnight Date (timezone-safe). */
function parseUtcDate(dateStr: string): Date {
    const [y, m, d] = dateStr.split('-').map((n) => parseInt(n, 10));
    return new Date(Date.UTC(y, m - 1, d));
}

/** Format a Date back to 'YYYY-MM-DD' using UTC components. */
function formatUtcDate(date: Date): string {
    const y = date.getUTCFullYear();
    const m = String(date.getUTCMonth() + 1).padStart(2, '0');
    const d = String(date.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

/** Whole-day diff between two UTC-midnight dates: a - b. */
function diffDays(a: Date, b: Date): number {
    return Math.round((a.getTime() - b.getTime()) / MS_PER_DAY);
}

/**
 * Build the occurrence of (month, day) in the given year, handling Feb 29
 * gracefully by clamping to Feb 28 in non-leap years.
 */
function occurrenceInYear(year: number, month0: number, day: number): Date {
    const candidate = new Date(Date.UTC(year, month0, day));
    // If day overflowed (e.g. Feb 29 in a non-leap year), JS rolls over into
    // the next month. Detect and clamp to the last valid day of the target month.
    if (candidate.getUTCMonth() !== month0) {
        return new Date(Date.UTC(year, month0 + 1, 0)); // last day of month0
    }
    return candidate;
}

/**
 * Calculate day count and status for a countdown event relative to todayStr.
 *
 * Countdown: days = effectiveDate - today (negative = past for one-time events;
 *   yearly-repeat events advance to the next occurrence >= today).
 * Countup: days = today - date + 1 (always positive; date must not be future).
 */
export function calcEventDays(event: CountdownEvent, todayStr: string): CountdownResult {
    const today = parseUtcDate(todayStr);
    const base = parseUtcDate(event.date);

    if (event.countMode === 'countup') {
        const days = diffDays(today, base) + 1;
        const status: CountdownStatus = diffDays(today, base) === 0 ? 'today' : 'upcoming';
        return { days, status, effectiveDate: event.date };
    }

    // countdown
    let effective = base;
    if (event.repeat) {
        const month0 = base.getUTCMonth();
        const day = base.getUTCDate();
        effective = occurrenceInYear(today.getUTCFullYear(), month0, day);
        // If this year's occurrence already passed, advance to next year.
        if (diffDays(effective, today) < 0) {
            effective = occurrenceInYear(today.getUTCFullYear() + 1, month0, day);
        }
    }

    const days = diffDays(effective, today);
    let status: CountdownStatus;
    if (days === 0) status = 'today';
    else if (days > 0) status = 'upcoming';
    else status = 'past';

    return { days, status, effectiveDate: formatUtcDate(effective) };
}

/*
 * Inline validation (see step 5):
 *
 * 1. birthday repeat=true date='2025-01-01' today='2026-07-19'
 *    -> effectiveDate='2027-01-01', status='upcoming'
 *    (2026-01-01 already passed on 2026-07-19, so advance to 2027-01-01)
 *
 * 2. repeat=true date='2026-07-19' today='2026-07-19'
 *    -> status='today', days=0
 *
 * 3. one-time countdown repeat=false date='2026-01-01' today='2026-07-19'
 *    -> status='past', days negative (-199)
 */
