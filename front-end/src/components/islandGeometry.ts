// ============================================================
// Island shape math & animation tokens
// Parameters are aligned with mac-island/IslandVisualTokens.swift
// ============================================================

import { APPLE_SPRING } from './islandMotionTokens';

// Spring for the outer container — the Apple response/dampingFraction spring
// ported from mac-island (IslandMotionTokens.appleSpring).
export const containerSpring = APPLE_SPRING;

// ── Squircle smoothness ──────────────────────────────────────
// Matches mac-island IslandVisualTokens:
//   compact.smoothness   = 3.3
//   activity.smoothness  = 2.8
//   expanded*.smoothness = 3.5
export const SQUIRCLE_SMOOTHNESS_COMPACT   = 3.3;
export const SQUIRCLE_SMOOTHNESS_ACTIVITY  = 2.8;
export const SQUIRCLE_SMOOTHNESS_EXPANDED  = 3.5;

// ── Corner radii ─────────────────────────────────────────────
// Matches mac-island IslandVisualTokens:
//   compact.radius      = 50
//   activity.radius     = 40
//   expanded*.radius    = 80
export const COLLAPSED_RADIUS_DEFAULT  = 50;   // compact state
export const COLLAPSED_RADIUS_ACTIVITY = 40;   // activity state
export const EXPANDED_RADIUS           = 80;   // both expanded states

// ── Ear (liquid connection) — compact / idle state ───────────
// compact.earTension = 0.4, compact.earBlendHeight = 11
export const EAR_TENSION_IDLE      = 0.4;
export const EAR_BLEND_HEIGHT_IDLE = 11;

// ── Ear — activity state ─────────────────────────────────────
// activity.earTension = 0.4, activity.earBlendHeight = 14
export const EAR_TENSION_ACTIVITY      = 0.4;
export const EAR_BLEND_HEIGHT_ACTIVITY = 14;

// ── Ear — expanded music state ────────────────────────────────
// Mac uses 50px, but Windows floats without a physical notch — halved to stay proportional.
export const EAR_TENSION_EXPANDED_MUSIC      = 0.65;
export const EAR_BLEND_HEIGHT_EXPANDED_MUSIC = 42;

// ── Ear — expanded app state ──────────────────────────────────
// Mac uses 60px, Windows floating context uses a smaller value.
export const EAR_TENSION_EXPANDED_APP      = 0.55;
export const EAR_BLEND_HEIGHT_EXPANDED_APP = 44;

// ── Hover behaviour ───────────────────────────────────────────
// Matches mac-island IslandVisualTokens.hover:
//   collapsedWidthScale = 1.04, collapsedHeight = 38
export const HOVER_WIDTH_SCALE = 1.04;
export const HOVER_HEIGHT      = 38;

// ── Activity transition timing ────────────────────────────────
export const ACTIVITY_COLLAPSE_DURATION_SECONDS       = 0.85;
export const ACTIVITY_COLLAPSE_CONTENT_DELAY_SECONDS  = 0.47;
export const ACTIVITY_SEGMENTED_TIMES                 = [0, 0.45, 0.55, 1];
export const ACTIVITY_OPEN_DURATION_SECONDS           = 0.56;
export const ACTIVITY_OPEN_CONTENT_DELAY_SECONDS      = 0.1;
export const ACTIVITY_OPEN_CONTENT_DURATION_SECONDS   = 0.26;

// ── Collapsed activity width ──────────────────────────────────
export const ACTIVITY_COLLAPSED_WIDTH = 240;

// ── Music cover dimensions (collapsed / expanded) ─────────────
// Matches mac-island IslandVisualTokens.activityMusicArtwork / expandedMusicArtwork
export const COLLAPSED_MUSIC_COVER_WIDTH      = 20;
export const COLLAPSED_MUSIC_COVER_HEIGHT     = 20;
export const COLLAPSED_MUSIC_COVER_RADIUS     = 6.4;
export const COLLAPSED_MUSIC_COVER_SMOOTHNESS = 1.92;

export const EXPANDED_MUSIC_COVER_WIDTH      = 72;
export const EXPANDED_MUSIC_COVER_HEIGHT     = 80;
export const EXPANDED_MUSIC_COVER_RADIUS     = 16;
export const EXPANDED_MUSIC_COVER_SMOOTHNESS = 1.85;

// ── Expanded card dimensions ──────────────────────────────────
export const EXPANDED_WIDTH        = 460;
export const EXPANDED_MUSIC_HEIGHT = 210;
export const EXPANDED_APP_HEIGHT   = 320;

// ── Window canvas ─────────────────────────────────────────────
export const WINDOW_WIDTH   = 620;
export const SHADOW_BUFFER  = 120;

// ── Screen-adaptive expanded box (expanded state only) ────────
// The mac island sizes itself to the physical notch. Windows has no notch, so we
// derive a factor from the display's logical width and shrink the EXPANDED box
// (width + height) on smaller displays. This is applied to the LAYOUT dimensions,
// NOT as a transform — fonts / paddings stay fixed, so text keeps its size and only
// the box (and therefore each subject card) gets narrower. The collapsed/normal
// pill is never touched. Clamped to <= 1.0 so the box never exceeds mac size (which
// would leave the fixed-height subject grid unable to fill it).
export const ISLAND_REFERENCE_SCREEN_WIDTH = 1920;
export const ISLAND_EXPANDED_SCALE_MIN = 0.85;  // most the box shrinks on small displays
export const ISLAND_EXPANDED_SCALE_MAX = 1.0;   // never larger than mac size

export function computeExpandedIslandScale(screenWidth?: number): number {
    const width = screenWidth ?? (typeof window !== 'undefined' ? window.screen?.width : undefined);
    if (!width || !Number.isFinite(width)) return 1;
    const raw = width / ISLAND_REFERENCE_SCREEN_WIDTH;
    return Math.min(Math.max(raw, ISLAND_EXPANDED_SCALE_MIN), ISLAND_EXPANDED_SCALE_MAX);
}

// Internal ear geometry constants (matches IslandPathFactory.swift)
const EAR_TIP_EXTENSION  = 4;   // earTipExtension
const EAR_BODY_OVERLAP   = 1;   // earBodyOverlap
const EAR_WIDTH          = 40;  // shellEarWidth
const EAR_CURVE_STEPS    = 28;  // earCurveSteps

// ============================================================
// Superellipse helpers
// ============================================================

/** |value|^(2/smoothness) — unsigned component */
function superellipseComponent(value: number, smoothness: number): number {
    return Math.pow(Math.abs(value), 2 / smoothness);
}

/** sign(value) * |value|^(2/smoothness) — signed component */
function signedSuperellipseComponent(value: number, smoothness: number): number {
    if (value === 0) return 0;
    return Math.sign(value) * superellipseComponent(value, smoothness);
}

// ============================================================
// Path generation — aligned with IslandPathFactory.swift
// ============================================================

/**
 * Liquid ear connector.
 *
 * Uses a single cubic Bezier instead of parametric line segments.
 * Mac's CoreGraphics renders the superellipse loop smoothly via GPU anti-aliasing,
 * but SVG line segments at small sizes (8×11 px in compact state) produce visible
 * faceting that looks like a crease/fold. A cubic Bezier is mathematically smooth
 * at any scale and preserves the same tangent properties:
 *   • Vertical tangent at (edgeX, blendHeight) — flush with the island body's side
 *   • Horizontal tangent at (tipX, 0) — flush with the island's top edge
 *
 * k ≈ 0.55 approximates the superellipse curvature character (slightly puffier than
 * a circle, k=0.5523) and matches Mac's visual closely.
 */
export const generateEarPath = (
    isLeft: boolean,
    tension: number,
    blendHeight: number,
    _smoothness: number   // kept for call-site compatibility; not needed for Bezier
): string => {
    const curveReach = blendHeight * tension + EAR_TIP_EXTENSION;
    const edgeX = isLeft ? EAR_WIDTH : 0;
    const inwardOverlapX = isLeft ? edgeX + EAR_BODY_OVERLAP : edgeX - EAR_BODY_OVERLAP;
    const direction = isLeft ? -1 : 1;
    const tipX = edgeX + direction * curveReach;

    // Control point factor: 0 = straight diagonal, 0.5523 = circle, 0.55 = slight superellipse
    const k = 0.55;
    const c1x = edgeX;
    const c1y = +(blendHeight * (1 - k)).toFixed(2);
    const c2x = +(tipX - direction * curveReach * (1 - k)).toFixed(2);
    const c2y = 0;

    return [
        `M ${edgeX} ${blendHeight}`,
        `C ${c1x} ${c1y}, ${c2x} ${c2y}, ${tipX.toFixed(2)} 0`,
        `L ${inwardOverlapX} 0 L ${inwardOverlapX} ${blendHeight} Z`,
    ].join(' ');
};

/**
 * Bottom-only squircle (flat top).
 * Matches IslandPathFactory.squircleBodyPath(width:height:radius:smoothness:).
 */
export const generateSquirclePath = (
    width: number,
    height: number,
    radius: number,
    smoothness: number
): string => {
    const r = Math.min(radius, width / 2, height / 2);
    const steps = 30;

    let path = `M 0 0 L ${width} 0 L ${width} ${height - r}`;

    const cx1 = width - r;
    const cy1 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = (Math.PI / 2) * (i / steps);
        path += ` L ${(cx1 + superellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy1 + superellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }

    path += ` L ${r} ${height}`;

    const cx2 = r;
    const cy2 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI / 2 + (Math.PI / 2) * (i / steps);
        path += ` L ${(cx2 + signedSuperellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy2 + superellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }

    path += ` L 0 0 Z`;
    return path;
};

/**
 * Bottom-only open squircle stroke — used as a bottom edge highlight in expanded state.
 * Matches mac-island IslandPathFactory.openSquircleStrokePath comment:
 *   "展开态描边只作为底部边缘高光使用，不能画到左右侧边。
 *    如果从 y=0 开始画左右竖线，线会压在液态连接与主体的交界处，形成灰色缝。"
 * Starts from the bottom of the right edge, curves around the bottom, ends after the
 * bottom-left corner. Does NOT go back up either side.
 */
export const generateOpenSquirclePath = (
    width: number,
    height: number,
    radius: number,
    smoothness: number
): string => {
    const r = Math.min(radius, width / 2, height / 2);
    const steps = 30;

    let path = `M ${width} ${height - r}`;

    const cx1 = width - r;
    const cy1 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = (Math.PI / 2) * (i / steps);
        path += ` L ${(cx1 + superellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy1 + superellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }

    path += ` L ${r} ${height}`;

    const cx2 = r;
    const cy2 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI / 2 + (Math.PI / 2) * (i / steps);
        path += ` L ${(cx2 + signedSuperellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy2 + superellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }

    // End here — do NOT add L 0 0 (would create a gray stripe up the left side).
    return path;
};

/**
 * Left cap background: square top-right/bottom-right, rounded bottom-left.
 * Matches IslandPathFactory.leftCapPath(height:radius:smoothness:).
 */
export const generateLeftCapPath = (
    height: number,
    radius: number,
    smoothness: number = SQUIRCLE_SMOOTHNESS_COMPACT
): string => {
    const w = 60;
    const r = Math.min(radius, height / 2);
    const steps = 30;

    let path = `M 0 0 L ${w} 0 L ${w} ${height} L ${r} ${height}`;

    const cx = r;
    const cy = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI / 2 + (Math.PI / 2) * (i / steps);
        path += ` L ${(cx + signedSuperellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy + superellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }

    path += ` L 0 0 Z`;
    return path;
};

/**
 * Right cap background: square top-left, rounded bottom-right.
 * Matches IslandPathFactory.rightCapPath(height:radius:smoothness:).
 */
export const generateRightCapPath = (
    height: number,
    radius: number,
    smoothness: number = SQUIRCLE_SMOOTHNESS_COMPACT
): string => {
    const w = 60;
    const r = Math.min(radius, height / 2);
    const steps = 30;

    let path = `M 0 0 L ${w} 0 L ${w} ${height - r}`;

    const cx = w - r;
    const cy = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = (Math.PI / 2) * (i / steps);
        path += ` L ${(cx + superellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy + superellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }

    path += ` L 0 ${height} Z`;
    return path;
};

/** Full 4-corner squircle — used only for music cover thumbnail. */
export const generateFullSquirclePath = (
    width: number,
    height: number,
    radius: number,
    smoothness: number = 2.8
): string => {
    const r = Math.min(radius, width / 2, height / 2);
    const steps = 24;

    let path = `M ${r} 0 L ${width - r} 0`;

    // top-right
    const cx1 = width - r; const cy1 = r;
    for (let i = 1; i <= steps; i++) {
        const t = -Math.PI / 2 + (Math.PI / 2) * (i / steps);
        path += ` L ${(cx1 + superellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy1 + signedSuperellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }
    path += ` L ${width} ${height - r}`;

    // bottom-right
    const cx2 = width - r; const cy2 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = (Math.PI / 2) * (i / steps);
        path += ` L ${(cx2 + superellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy2 + superellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }
    path += ` L ${r} ${height}`;

    // bottom-left
    const cx3 = r; const cy3 = height - r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI / 2 + (Math.PI / 2) * (i / steps);
        path += ` L ${(cx3 + signedSuperellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy3 + superellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }
    path += ` L 0 ${r}`;

    // top-left
    const cx4 = r; const cy4 = r;
    for (let i = 1; i <= steps; i++) {
        const t = Math.PI + (Math.PI / 2) * (i / steps);
        path += ` L ${(cx4 + signedSuperellipseComponent(Math.cos(t), smoothness) * r).toFixed(2)} ${(cy4 + signedSuperellipseComponent(Math.sin(t), smoothness) * r).toFixed(2)}`;
    }

    path += ` Z`;
    return path;
};

/** Puffy cover — all four edges curve slightly inward. Used for music album art. */
export const generatePuffyCoverPath = (
    width: number,
    height: number,
    radius: number,
    smoothness: number = 2
): string => {
    const steps = 72;
    const cx = width / 2;
    const cy = height / 2;
    const minSide = Math.min(width, height);
    const normalizedRadius = Math.max(0.1, Math.min(0.34, radius / minSide));
    const superellipseN = Math.max(
        3.8,
        Math.min(7.2, 3.9 + normalizedRadius * 8.5 + (2.4 - smoothness) * 2.2)
    );
    const exponent = 2 / superellipseN;

    let path = '';
    for (let i = 0; i <= steps; i++) {
        const t = -Math.PI / 2 + (Math.PI * 2 * i) / steps;
        const cosT = Math.cos(t);
        const sinT = Math.sin(t);
        const x = cx + (width / 2) * Math.sign(cosT) * Math.pow(Math.abs(cosT), exponent);
        const y = cy + (height / 2) * Math.sign(sinT) * Math.pow(Math.abs(sinT), exponent);
        path += `${i === 0 ? 'M' : 'L'} ${x.toFixed(2)} ${y.toFixed(2)} `;
    }
    path += 'Z';
    return path;
};
