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
    /**
     * Frosted-glass blur intensity (px) applied to the LIST card overlay when a
     * background image is set. Range 0–20. Defaults to 6. Optional so events
     * saved before this field existed still load.
     */
    listBlurIntensity?: number;
    /**
     * Frosted-glass blur intensity (px) applied to the DETAIL card overlay when a
     * background image is set. Range 0–20. Defaults to 8. Optional so events
     * saved before this field existed still load.
     */
    detailBlurIntensity?: number;
    /**
     * Background-image zoom/scale for the card. Applied as the background-size
     * multiplier: 1.0 (or absent) renders as 'cover'; other values render as
     * `${bgImageScale * 100}% auto`, so <1 shrinks the image (reveals more) and
     * >1 zooms in. Range 0.3–3.0. Defaults to 1.0. Optional so events saved
     * before this field existed still load. Adjusted via the edit-page preview
     * card's scroll wheel (task 022).
     */
    bgImageScale?: number;
}
