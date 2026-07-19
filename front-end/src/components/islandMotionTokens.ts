// ============================================================
// Island motion tokens — TypeScript port of mac-island Motion layer
// Ported from:
//   mac-island/MemoryFlowIsland/UI/Motion/AppleSpringMotion.swift
//   mac-island/MemoryFlowIsland/UI/Motion/IslandMotionTokens.swift
//   mac-island/MemoryFlowIsland/UI/Motion/IslandTransitionKind.swift
//
// Provides exact spring parameters and per-transition timing profiles
// consumed by later shell/content tasks.
// ============================================================

/** A framer-motion compatible spring transition. */
export interface SpringToken {
    type: "spring";
    stiffness: number;
    damping: number;
    mass: number;
}

/**
 * Build a spring from Apple's (response, dampingFraction, mass) parameterisation.
 *
 * Mirrors IslandSpringMotionToken.init(response:dampingFraction:mass:):
 *   ω          = 2π / max(response, 0.001)
 *   stiffness  = mass * ω²
 *   damping    = 2 * dampingFraction * mass * ω
 *   (mass clamped to >= 0.001)
 */
export function springFromResponse(
    response: number,
    dampingFraction: number,
    mass: number = 1,
): SpringToken {
    const clampedMass = Math.max(mass, 0.001);
    const angularFrequency = (2 * Math.PI) / Math.max(response, 0.001);
    return {
        type: "spring",
        stiffness: clampedMass * angularFrequency * angularFrequency,
        damping: 2 * dampingFraction * clampedMass * angularFrequency,
        mass: clampedMass,
    };
}

// ── Reference springs ─────────────────────────────────────────
// AppleSpringMotion.response = 0.35, dampingFraction = 0.70
// Closing keeps the same response but settles with less overshoot (0.78).
export const APPLE_SPRING: SpringToken = springFromResponse(0.35, 0.70);
export const COLLAPSE_SPRING: SpringToken = springFromResponse(0.35, 0.78);

// ── IslandMotionTokens constants ──────────────────────────────
export const ACTIVITY_OPEN_TIMES: readonly number[] = [0, 0.2, 0.34, 1];
export const ACTIVITY_COLLAPSE_TIMES: readonly number[] = [0, 0.45, 0.55, 1];
export const ACTIVITY_OPEN_DURATION = 0.56;
export const ACTIVITY_COLLAPSE_DURATION = 0.85;
export const ACTIVITY_COLLAPSE_MID_WIDTH = 155;

export const CONTENT_ENTER_BLUR = 4;
export const CONTENT_ENTER_DELAY = 0.10;
export const CONTENT_ENTER_DURATION = 0.26;
export const CONTENT_EXIT_BLUR = 5;
export const CONTENT_EXIT_DURATION = 0.15;

// Compact content should not fade in until the shell has finished its collapse
// keyframe stop: 0.85 * 0.55 = 0.4675
export const COLLAPSE_COMPACT_CONTENT_DELAY =
    ACTIVITY_COLLAPSE_DURATION * ACTIVITY_COLLAPSE_TIMES[2];

// ── Transition kinds ──────────────────────────────────────────
export type IslandTransitionKind =
    | "compactToActivity"
    | "compactToExpanded"
    | "activityToCompact"
    | "activityToExpanded"
    | "expandedToCompact"
    | "expandedToActivity"
    | "hoverEnter"
    | "hoverLeave";

// ── Per-transition motion profile ─────────────────────────────
export interface MotionProfile {
    shellDuration: number;
    /** Keyframe stops, or null for a pure spring with no keyframe stops. */
    shellTimes: readonly number[] | null;
    shellSpring: SpringToken;
    contentEnterDelay: number;
    contentEnterDuration: number;
    contentExitDuration: number;
}

const HOVER_DURATION = 0.18;

/**
 * Derived from IslandMotionTokens.profile + IslandContentChoreographyPlan.enterStart.
 */
export function motionProfile(kind: IslandTransitionKind): MotionProfile {
    switch (kind) {
        case "compactToActivity":
            return {
                shellDuration: ACTIVITY_OPEN_DURATION,
                shellTimes: ACTIVITY_OPEN_TIMES,
                shellSpring: APPLE_SPRING,
                contentEnterDelay: CONTENT_ENTER_DELAY, // 0.10
                contentEnterDuration: CONTENT_ENTER_DURATION, // 0.26
                contentExitDuration: CONTENT_EXIT_DURATION, // 0.15
            };
        case "compactToExpanded":
            return {
                shellDuration: ACTIVITY_OPEN_DURATION,
                shellTimes: null, // pure spring, no keyframe stops
                shellSpring: APPLE_SPRING,
                contentEnterDelay: 0,
                contentEnterDuration: 0.30,
                contentExitDuration: CONTENT_EXIT_DURATION,
            };
        case "activityToExpanded":
            return {
                shellDuration: ACTIVITY_OPEN_DURATION,
                shellTimes: ACTIVITY_OPEN_TIMES,
                shellSpring: APPLE_SPRING,
                contentEnterDelay: 0,
                contentEnterDuration: 0.30,
                contentExitDuration: CONTENT_EXIT_DURATION,
            };
        case "expandedToActivity":
            return {
                shellDuration: ACTIVITY_OPEN_DURATION,
                shellTimes: ACTIVITY_OPEN_TIMES,
                shellSpring: APPLE_SPRING,
                // enterStart = max(shellDuration - enterDuration, exitDuration)
                //            = max(0.56 - 0.30, 0.15) = 0.26
                contentEnterDelay: Math.max(
                    ACTIVITY_OPEN_DURATION - 0.30,
                    CONTENT_EXIT_DURATION,
                ),
                contentEnterDuration: 0.30,
                contentExitDuration: CONTENT_EXIT_DURATION,
            };
        case "activityToCompact":
            return {
                shellDuration: ACTIVITY_COLLAPSE_DURATION,
                shellTimes: ACTIVITY_COLLAPSE_TIMES,
                shellSpring: COLLAPSE_SPRING,
                contentEnterDelay: COLLAPSE_COMPACT_CONTENT_DELAY, // 0.4675
                contentEnterDuration: CONTENT_ENTER_DURATION, // 0.26
                contentExitDuration: CONTENT_EXIT_DURATION,
            };
        case "expandedToCompact":
            return {
                shellDuration: ACTIVITY_COLLAPSE_DURATION,
                shellTimes: null, // pure COLLAPSE_SPRING, no keyframe stops
                shellSpring: COLLAPSE_SPRING,
                contentEnterDelay: COLLAPSE_COMPACT_CONTENT_DELAY, // 0.4675
                contentEnterDuration: 0.30,
                contentExitDuration: CONTENT_EXIT_DURATION,
            };
        case "hoverEnter":
        case "hoverLeave":
            return {
                shellDuration: HOVER_DURATION,
                shellTimes: null,
                shellSpring: APPLE_SPRING,
                contentEnterDelay: 0.12,
                contentEnterDuration: 0.12,
                contentExitDuration: 0.12,
            };
    }
}
