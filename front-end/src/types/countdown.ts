// Countdown event data schema.

export type CountdownEventType = 'birthday' | 'anniversary' | 'custom';
export type CountdownMode = 'countdown' | 'countup';

export interface CountdownEvent {
    id: string;
    name: string;
    type: CountdownEventType;
    countMode: CountdownMode;
    /** ISO date string in YYYY-MM-DD format. */
    date: string;
    repeat: boolean;
    /** Hex color string, e.g. '#FF8800'. */
    color: string;
}
