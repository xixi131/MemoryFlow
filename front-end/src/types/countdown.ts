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
    /**
     * Optional background image URL for the card. Null (or absent, for events
     * saved before this field existed) → use the color-band design. Defaults to
     * null.
     */
    bgImageUrl?: string | null;
    /**
     * Background-image focal point as CSS background-position percentages.
     * Defaults to { x: 50, y: 50 } (centered).
     */
    bgImageOffset?: { x: number; y: number };
    /** Card text color used when a background image is set. Defaults to '#FFFFFF'. */
    textColor?: string;
}
