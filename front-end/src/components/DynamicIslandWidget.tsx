import React, { useRef, useCallback, useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
    SQUIRCLE_SMOOTHNESS_COMPACT,
    SQUIRCLE_SMOOTHNESS_ACTIVITY,
    SQUIRCLE_SMOOTHNESS_EXPANDED,
    EAR_TENSION_IDLE,
    EAR_BLEND_HEIGHT_IDLE,
    EAR_TENSION_ACTIVITY,
    EAR_BLEND_HEIGHT_ACTIVITY,
    EAR_TENSION_EXPANDED_MUSIC,
    EAR_BLEND_HEIGHT_EXPANDED_MUSIC,
    EAR_TENSION_EXPANDED_APP,
    EAR_BLEND_HEIGHT_EXPANDED_APP,
    COLLAPSED_RADIUS_DEFAULT,
    COLLAPSED_RADIUS_ACTIVITY,
    EXPANDED_RADIUS,
    HOVER_WIDTH_SCALE,
    HOVER_HEIGHT,
    ACTIVITY_COLLAPSED_WIDTH,
    EXPANDED_WIDTH,
    EXPANDED_MUSIC_HEIGHT,
    EXPANDED_APP_HEIGHT,
    WINDOW_WIDTH,
    SHADOW_BUFFER,
    computeExpandedIslandScale,
    generateEarPath,
    generateSquirclePath,
    generateOpenSquirclePath,
    generateLeftCapPath,
    generateRightCapPath,
} from './islandGeometry';
import {
    motionProfile,
    ACTIVITY_OPEN_TIMES,
    ACTIVITY_OPEN_DURATION,
    ACTIVITY_COLLAPSE_TIMES,
} from './islandMotionTokens';
import { useIslandState } from './useIslandState';
import MusicActivityContent from './island/MusicActivityContent';
import AppActivityContent from './island/AppActivityContent';
import ExpandedMusicCard from './island/ExpandedMusicCard';
import ExpandedReviewCard from './island/ExpandedReviewCard';
import ExpandedTodoCard from './island/ExpandedTodoCard';

// ── Gesture constants ────────────────────────────────────────
const GESTURE_SWITCH_THRESHOLD = 26;
const TAP_THRESHOLD = 10;
const TRACKPAD_VERTICAL_THRESHOLD = 70;
const TRACKPAD_HORIZONTAL_THRESHOLD = 70;
const TRACKPAD_GESTURE_RESET_MS = 160;
const TRACKPAD_GESTURE_COOLDOWN_MS = 320;

const DynamicIslandWidget: React.FC = () => {
    const {
        state,
        dispatch,
        transitionKind,
        isExpandedRef,
        forceCompactModeRef,
        isLoggedInRef,
        modeRef,
        enableClickThrough,
        disableClickThrough,
        collapseExpanded,
        setForceCompactModeWithTransition,
        clearModeSwitchLongPressTimer,
        triggerActivityModeSwitch,
        sendMediaControl,
        handleToggleTodoTask,
        modeSwitchLongPressTimerRef,
        MODE_SWITCH_LONG_PRESS_MS,
    } = useIslandState();

    const {
        isExpanded, isLoggedIn, forceCompactMode, isHovered, greetingText, isGreetingActive,
        mode, appDisplayMode, musicData, localPosition, data, todoPreview, todoPendingOps,
        isReminderCollapsing, isModeSwitchAnimating, isForceCompactTransitioning,
        activityOpenAnimToken, isExpandedRecoveryCollapsing,
    } = state;

    const islandHitRef = useRef<HTMLDivElement | null>(null);

    // ── Trackpad gesture state ────────────────────────────────
    const trackpadDeltaXRef = useRef(0);
    const trackpadDeltaYRef = useRef(0);
    const trackpadGestureLockedRef = useRef(false);
    const trackpadGestureResetTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const trackpadGestureCooldownTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

    // ── Pointer gesture state ─────────────────────────────────
    const startX = useRef<number | null>(null);
    const lastPointerXRef = useRef<number | null>(null);
    const activePointerIdRef = useRef<number | null>(null);
    const isGestureTrackingRef = useRef(false);

    // ── Derived display state ─────────────────────────────────
    const hasMusicActivitySource = mode === 'music' && !!musicData;
    const hasAppActivitySource = mode === 'app' && isLoggedIn;
    const hasAnyActivitySource = hasMusicActivitySource || hasAppActivitySource;
    const showMusicActivity = hasMusicActivitySource && !forceCompactMode;
    const showReminder = appDisplayMode === 'review' && hasAppActivitySource && !forceCompactMode;
    const showTodoActivity = appDisplayMode === 'todo' && hasAppActivitySource && !forceCompactMode;
    const showAppActivity = showReminder || showTodoActivity;
    const showAnyActivity = showMusicActivity || showAppActivity;

    const collapsedCornerRadius = showAnyActivity ? COLLAPSED_RADIUS_ACTIVITY : COLLAPSED_RADIUS_DEFAULT;
    const collapsedCornerSmoothness = showAnyActivity ? SQUIRCLE_SMOOTHNESS_ACTIVITY : SQUIRCLE_SMOOTHNESS_COMPACT;
    const themeColor = musicData?.themeColor || '#22d3ee';

    const getCollapsedWidth = () => {
        if (showAnyActivity) return ACTIVITY_COLLAPSED_WIDTH;
        if (mode === 'app' && isGreetingActive && isLoggedIn && greetingText) {
            const estimated = Math.ceil(greetingText.length * 14 + 40);
            return Math.max(220, Math.min(300, estimated));
        }
        if (mode === 'app' && isLoggedIn && appDisplayMode === 'todo' && !hasAppActivitySource) return 230;
        return isLoggedIn ? 160 : 180;
    };
    const collapsedWidth = getCollapsedWidth();
    const baseWidth = isLoggedIn ? 160 : 180;

    const isInitialHoverState = isHovered && !isExpanded && !showAnyActivity;
    const hoverCollapsedWidth = isInitialHoverState ? collapsedWidth * HOVER_WIDTH_SCALE : collapsedWidth;
    const hoverCollapsedHeight = isInitialHoverState ? HOVER_HEIGHT : 36;

    // ── Content-choreography flag (task 006) ─────────────────────────────
    //    Whether the collapsed activity content is entering via the OPEN
    //    (force-compact → activity) transition — passed to activity content
    //    so it can stagger its own inner reveal.
    const isActivityOpenTransition = isForceCompactTransitioning && !forceCompactMode && hasAnyActivitySource;

    // ── Per-transition shell motion profile (islandMotionTokens) ──────────
    // The resolved `transitionKind` from the hook selects exact spring +
    // keyframe timing. We keep boolean *shape* gates (below) so the keyframe
    // array shapes are stable across mid-animation re-renders, while every
    // timing value (times / duration / spring) is sourced from `profile`.
    const profile = motionProfile(transitionKind);

    // Direction gates, resolved from STABLE state (not transitionKind) so the
    // chosen keyframe shape does not flip while an animation is in flight.
    // Collapse-from-expanded is split by destination: → activity uses the OPEN
    // (hold) family, → compact keeps the segmented squish.
    const isExpandedToActivityTransition = isReminderCollapsing && !forceCompactMode && hasAnyActivitySource;
    const isExpandedToCompactTransition = isReminderCollapsing && (forceCompactMode || !hasAnyActivitySource);
    const isActivityToCompactTransition = isForceCompactTransitioning && forceCompactMode && hasAnyActivitySource;

    // Segmented squish (waist at 155) is ONLY for activity → compact. Expanded →
    // compact is a DIRECT spring straight to the compact target (scalar targets +
    // profile.shellSpring below), with NO 155 mid keyframe (task 007 FIX A).
    const isCollapseShellTransition = isActivityToCompactTransition;
    const isOpenShellTransition = isActivityOpenTransition || isExpandedToActivityTransition;

    // Keyframe stops from the profile (null → the sensible per-direction default).
    // Only activity→compact keeps the segmented 155px squish keyframes. Every other
    // direction (open, expand, expanded→compact) now springs continuously so the
    // width, the drawn paths and the ears all morph together on one spring — matching
    // the (correct) normal expand. framer-motion's `times` expects a mutable number[].
    const collapseShellTimes = [...(profile.shellTimes ?? ACTIVITY_COLLAPSE_TIMES)]; // [0, 0.45, 0.55, 1]
    const shellDuration = profile.shellDuration;
    const collapseShellTransition = { times: collapseShellTimes, duration: shellDuration, ease: 'easeInOut' as const };

    // Spring restored. The shell is drawn by the CSS-laid-out cap layer (two fixed
    // 60px rounded caps + a flex-grow middle), NOT by a path whose right edge is a
    // separate framer path-spring. The caps' outer edges and the ears (right:-40px)
    // both track the framer-animated container WIDTH via flexbox each frame, so they
    // stay welded even through the APPLE_SPRING overshoot. The path-animated body
    // squircle (which diverged from the width number-spring and caused the right ear
    // to separate) was removed; the caps are the sole black shell.
    // shellPathTransition drives width/height + the inner-stroke `d` (these carry the
    // 4-stop squish keyframe arrays for activity→compact, so they need the `times`).
    // Phase 1 of the Mac expanded→activity recovery: a quick eased collapse to the
    // compact pill (no spring), matching expandedActivityRecoveryCollapseDuration.
    // Phase 2 (the bloom to activity) then rides the normal open spring.
    const recoveryCollapseTransition = { duration: 0.32, ease: 'easeInOut' as const };
    const shellPathTransition = isExpandedRecoveryCollapsing
        ? recoveryCollapseTransition
        : isCollapseShellTransition ? collapseShellTransition : profile.shellSpring;
    // Caps and ears animate a single `d` target (their horizontal weld is CSS, not
    // path), so they can't take the squish's 4-stop `times`; give them a plain
    // matched-duration morph on collapse and the spring otherwise.
    const capEarTransition = isExpandedRecoveryCollapsing
        ? recoveryCollapseTransition
        : isCollapseShellTransition
            ? { duration: shellDuration, ease: 'easeInOut' as const }
            : profile.shellSpring;

    const collapseMidWidth = isCollapseShellTransition ? 155 : baseWidth;
    // Collapse (squish): current → 155 → 155 → collapsed target.
    const segmentedWidthKeyframes = [null, collapseMidWidth, collapseMidWidth, collapsedWidth];
    const segmentedHeightKeyframes = [null, 36, 36, 36];

    const squircleCollapsedPath = [
        null,
        generateSquirclePath(collapseMidWidth, 36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateSquirclePath(collapseMidWidth, 36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateSquirclePath(collapsedWidth, 36, collapsedCornerRadius, collapsedCornerSmoothness),
    ];
    const openSquircleCollapsedPath = [
        null,
        generateOpenSquirclePath(collapseMidWidth, 36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateOpenSquirclePath(collapseMidWidth, 36, COLLAPSED_RADIUS_DEFAULT, collapsedCornerSmoothness),
        generateOpenSquirclePath(collapsedWidth, 36, collapsedCornerRadius, collapsedCornerSmoothness),
    ];

    // ── Content enter/exit choreography (task 006) ───────────────────────
    // Matches the Mac IslandContentChoreographyPlan: the layer that is
    // ENTERING (revealing into view) uses easeOut + the per-transition
    // enter delay from `profile`; the layer that is EXITING fades out fast
    // with `profile.contentExitDuration` and no delay. Direction is read from
    // STABLE `isExpanded` — expanded content enters when isExpanded is true,
    // collapsed content enters when isExpanded is false.
    // Activity/collapsed content reveals over 0.26s; expanded content over 0.30s.
    const collapsedContentTransition = !isExpanded
        ? { duration: 0.26, delay: profile.contentEnterDelay, ease: 'easeOut' as const }
        : { duration: profile.contentExitDuration, delay: 0, ease: 'easeOut' as const };
    const expandedContentTransition = isExpanded
        ? { duration: 0.30, delay: profile.contentEnterDelay, ease: 'easeOut' as const }
        : { duration: profile.contentExitDuration, delay: 0, ease: 'easeOut' as const };

    const islandDropShadow = isExpanded
        ? 'drop-shadow(0px 10px 25px rgba(0,0,0,0.22)) drop-shadow(0px 6px 14px rgba(0,0,0,0.18)) drop-shadow(0px 2px 6px rgba(0,0,0,0.12))'
        : isInitialHoverState
            ? 'drop-shadow(0px 5px 12px rgba(0,0,0,0.14))'
            : 'none';

    // ── Ear parameters ────────────────────────────────────────
    // Each visual state uses its own smoothness so ear curvature stays
    // in the same superellipse family as the body corners (matches Mac).
    const isActivityEarState = showAnyActivity || (isGreetingActive && isLoggedIn);
    const earSmoothness = isExpanded
        ? SQUIRCLE_SMOOTHNESS_EXPANDED
        : isActivityEarState
            ? SQUIRCLE_SMOOTHNESS_ACTIVITY
            : SQUIRCLE_SMOOTHNESS_COMPACT;
    const earTension = isExpanded
        ? (mode === 'music' ? EAR_TENSION_EXPANDED_MUSIC : EAR_TENSION_EXPANDED_APP)
        : isActivityEarState ? EAR_TENSION_ACTIVITY
        : EAR_TENSION_IDLE;
    const earBlendHeight = isExpanded
        ? (mode === 'music' ? EAR_BLEND_HEIGHT_EXPANDED_MUSIC : EAR_BLEND_HEIGHT_EXPANDED_APP)
        : isActivityEarState ? EAR_BLEND_HEIGHT_ACTIVITY
        : EAR_BLEND_HEIGHT_IDLE;

    // ── Screen-adaptive expanded box (expanded only) ──────────
    // Mac sizes the island to the notch; Windows has none, so shrink the EXPANDED
    // box (layout width/height, not a transform — fonts stay fixed) on smaller
    // displays. The collapsed/normal pill is never touched.
    const [expandedScale, setExpandedScale] = useState(() => computeExpandedIslandScale());
    useEffect(() => {
        const recompute = () => setExpandedScale(computeExpandedIslandScale());
        recompute();
        window.addEventListener('resize', recompute);
        return () => window.removeEventListener('resize', recompute);
    }, []);

    // ── Electron window resize ────────────────────────────────
    // The window canvas width is fixed; only the expanded height follows the shrunk
    // box height so there's no dead space below it. Collapsed keeps its fixed size.
    useEffect(() => {
        try {
            const ipc = (window as any).require('electron').ipcRenderer;
            const baseVisual = mode === 'music' ? EXPANDED_MUSIC_HEIGHT : EXPANDED_APP_HEIGHT;
            const visualHeight = isExpanded ? baseVisual * expandedScale : 36;
            ipc.send('resize-widget', {
                width: WINDOW_WIDTH,
                height: isExpanded ? Math.ceil(visualHeight + SHADOW_BUFFER) : 300,
            });
        } catch { }
    }, [isExpanded, mode, expandedScale]);

    // ── Outside click collapse ────────────────────────────────
    useEffect(() => {
        const handlePointerDownCapture = (event: PointerEvent) => {
            if (!isExpandedRef.current) return;
            const targetNode = event.target as Node | null;
            if (!targetNode) return;
            if (islandHitRef.current?.contains(targetNode)) return;
            collapseExpanded();
        };
        document.addEventListener('pointerdown', handlePointerDownCapture, true);
        return () => document.removeEventListener('pointerdown', handlePointerDownCapture, true);
    }, [collapseExpanded, isExpandedRef]);

    // ── Trackpad helpers ──────────────────────────────────────
    const clearTrackpadGestureState = useCallback(() => {
        trackpadDeltaXRef.current = 0;
        trackpadDeltaYRef.current = 0;
        if (trackpadGestureResetTimerRef.current) {
            clearTimeout(trackpadGestureResetTimerRef.current);
            trackpadGestureResetTimerRef.current = null;
        }
    }, []);

    const lockTrackpadGesture = useCallback(() => {
        trackpadGestureLockedRef.current = true;
        if (trackpadGestureCooldownTimerRef.current) clearTimeout(trackpadGestureCooldownTimerRef.current);
        trackpadGestureCooldownTimerRef.current = setTimeout(() => {
            trackpadGestureLockedRef.current = false;
            trackpadGestureCooldownTimerRef.current = null;
        }, TRACKPAD_GESTURE_COOLDOWN_MS);
    }, []);

    useEffect(() => {
        return () => {
            if (trackpadGestureCooldownTimerRef.current) clearTimeout(trackpadGestureCooldownTimerRef.current);
            trackpadGestureLockedRef.current = false;
        };
    }, []);

    // ── Login redirect ────────────────────────────────────────
    const openLogin = () => {
        try {
            const { shell } = (window as any).require('electron');
            const envUrl = (window as any)?.process?.env?.ELECTRON_START_URL;
            const baseUrl = (envUrl && typeof envUrl === 'string') ? envUrl : 'https://memoryflow.tanxhub.com';
            shell.openExternal(`${baseUrl.split('#')[0].replace(/\/$/, '')}/#/login?callback=desktop`);
        } catch { }
    };

    // ── Tap → expand/login ────────────────────────────────────
    const toggleExpand = () => {
        if (!isLoggedIn && mode === 'app') { openLogin(); return; }
        if (isExpanded) {
            // Route collapse through collapseExpanded so the Mac expanded→activity
            // two-phase recovery runs (tap-to-collapse previously bypassed it).
            collapseExpanded();
        } else {
            dispatch({ type: 'SET_EXPANDED', payload: true });
        }
    };

    // ── Pointer gesture handlers ──────────────────────────────
    const finalizeGesture = (currentTarget: EventTarget | null) => {
        startX.current = null;
        lastPointerXRef.current = null;
        activePointerIdRef.current = null;
        isGestureTrackingRef.current = false;
        const targetEl = currentTarget as HTMLElement | null;
        const isHovering = !!targetEl && typeof targetEl.matches === 'function' && targetEl.matches(':hover');
        if (!isExpandedRef.current && !isHovering) enableClickThrough();
    };

    const handlePointerDown = (e: React.PointerEvent) => {
        if ((e.target as HTMLElement).closest('button')) return;
        activePointerIdRef.current = e.pointerId;
        startX.current = e.clientX;
        lastPointerXRef.current = e.clientX;
        isGestureTrackingRef.current = true;
        try { e.currentTarget.setPointerCapture(e.pointerId); } catch { }
    };

    const handlePointerMove = (e: React.PointerEvent) => {
        if (!isGestureTrackingRef.current) return;
        if (activePointerIdRef.current !== null && e.pointerId !== activePointerIdRef.current) return;
        lastPointerXRef.current = e.clientX;
    };

    const handlePointerUp = (e: React.PointerEvent) => {
        if (!isGestureTrackingRef.current) return;
        if (activePointerIdRef.current !== null && e.pointerId !== activePointerIdRef.current) return;
        if (startX.current === null) { finalizeGesture(e.currentTarget); return; }

        const diff = (lastPointerXRef.current ?? e.clientX) - startX.current;
        try { e.currentTarget.releasePointerCapture(e.pointerId); } catch { }
        finalizeGesture(e.currentTarget);

        if (hasAnyActivitySource) {
            if (diff > GESTURE_SWITCH_THRESHOLD && showAnyActivity) { setForceCompactModeWithTransition(true); return; }
            if (diff < -GESTURE_SWITCH_THRESHOLD && forceCompactMode) { setForceCompactModeWithTransition(false); return; }
        }
        if (Math.abs(diff) < TAP_THRESHOLD) toggleExpand();
    };

    const handlePointerCancel = (e: React.PointerEvent) => {
        if (!isGestureTrackingRef.current) return;
        try { e.currentTarget.releasePointerCapture(e.pointerId); } catch { }
        finalizeGesture(e.currentTarget);
    };

    // ── Trackpad wheel handler ────────────────────────────────
    const handleTrackpadWheel = useCallback((e: React.WheelEvent<HTMLDivElement>) => {
        if (!isHovered && !isExpandedRef.current) return;
        if (trackpadGestureLockedRef.current) return;

        trackpadDeltaXRef.current += e.deltaX;
        trackpadDeltaYRef.current += e.deltaY;

        if (trackpadGestureResetTimerRef.current) clearTimeout(trackpadGestureResetTimerRef.current);
        trackpadGestureResetTimerRef.current = setTimeout(clearTrackpadGestureState, TRACKPAD_GESTURE_RESET_MS);

        const absX = Math.abs(trackpadDeltaXRef.current);
        const absY = Math.abs(trackpadDeltaYRef.current);

        if (absX >= absY && absX >= TRACKPAD_HORIZONTAL_THRESHOLD) {
            if (modeRef.current === 'music' && musicData) {
                e.preventDefault();
                sendMediaControl(trackpadDeltaXRef.current > 0 ? 'next' : 'prev');
                clearTrackpadGestureState();
                lockTrackpadGesture();
            }
            return;
        }

        if (absY > absX && absY >= TRACKPAD_VERTICAL_THRESHOLD) {
            const swipingUp = trackpadDeltaYRef.current > 0;
            const swipingDown = trackpadDeltaYRef.current < 0;

            if (swipingUp) {
                if (hasAnyActivitySource && !forceCompactModeRef.current) {
                    e.preventDefault();
                    setForceCompactModeWithTransition(true);
                    clearTrackpadGestureState();
                    lockTrackpadGesture();
                    return;
                }
            }

            if (swipingDown) {
                if (!isExpandedRef.current && hasAnyActivitySource && forceCompactModeRef.current) {
                    e.preventDefault();
                    setForceCompactModeWithTransition(false);
                    clearTrackpadGestureState();
                    lockTrackpadGesture();
                }
            }
        }
    }, [
        isHovered, musicData, sendMediaControl, clearTrackpadGestureState, lockTrackpadGesture,
        collapseExpanded, hasAnyActivitySource, showAnyActivity, setForceCompactModeWithTransition,
        isExpandedRef, forceCompactModeRef, modeRef,
    ]);

    // ── Mode-switch long press handlers ───────────────────────
    const handleActivityLeftIconPointerDown = (e: React.PointerEvent<HTMLButtonElement>) => {
        e.stopPropagation();
        if (e.button !== 0) return;
        if (!showAppActivity || isExpanded || isModeSwitchAnimating) return;
        clearModeSwitchLongPressTimer();
        modeSwitchLongPressTimerRef.current = setTimeout(() => {
            modeSwitchLongPressTimerRef.current = null;
            triggerActivityModeSwitch(appDisplayMode, showAppActivity);
        }, MODE_SWITCH_LONG_PRESS_MS);
    };

    const handleActivityLeftIconPointerEnd = (e: React.PointerEvent<HTMLButtonElement>) => {
        e.stopPropagation();
        clearModeSwitchLongPressTimer();
    };

    // ── Media control handlers ────────────────────────────────
    const handlePlayPause = useCallback((e: React.MouseEvent) => { e.stopPropagation(); sendMediaControl('play-pause'); }, [sendMediaControl]);
    const handlePrev = useCallback((e: React.MouseEvent) => { e.stopPropagation(); sendMediaControl('prev'); }, [sendMediaControl]);
    const handleNext = useCallback((e: React.MouseEvent) => { e.stopPropagation(); sendMediaControl('next'); }, [sendMediaControl]);

    // Expanded box dimensions, shrunk to fit smaller displays (layout only —
    // fonts/paddings are unchanged, so the box + subject cards get narrower while
    // text keeps its size). Corner radius stays fixed. Collapsed dims are untouched.
    const expandedWidth     = EXPANDED_WIDTH * expandedScale;
    const expandedAppHeight = EXPANDED_APP_HEIGHT * expandedScale;
    const expandedMusicHeight = EXPANDED_MUSIC_HEIGHT * expandedScale;
    const expandedContentHeight = mode === 'music' ? expandedMusicHeight : expandedAppHeight;

    // ─────────────────────────────────────────────────────────
    // Render
    // ─────────────────────────────────────────────────────────
    return (
        <div className="flex items-start justify-center w-full h-auto bg-transparent pointer-events-none" style={{ background: 'transparent' }}>
            <style>{`
                @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+SC:wght@400;500;600;700&display=swap');
                body, html { overflow: hidden !important; }
                html, body, #root { height: 100% !important; }
                ::-webkit-scrollbar { display: none !important; }
            `}</style>

            <motion.div
                className="relative pointer-events-none"
                style={{
                    transform: 'translateZ(0)',
                    transformOrigin: 'center top',
                    filter: islandDropShadow,
                    transition: 'filter 260ms ease-out',
                    willChange: 'transform, filter',
                }}
                initial={false}
                animate={isExpanded ? 'expanded' : 'collapsed'}
                variants={{
                    collapsed: {
                        // Only activity→compact keeps the segmented 155 squish; every
                        // other direction tweens the scalar target so the width, the
                        // paths and the ears morph together (no snap, and no spring
                        // overshoot that could separate the right ear).
                        width: isCollapseShellTransition ? segmentedWidthKeyframes : hoverCollapsedWidth,
                        height: isCollapseShellTransition ? segmentedHeightKeyframes : hoverCollapsedHeight,
                        scale: 1,
                        originY: 0,
                    },
                    expanded: {
                        width: expandedWidth,
                        height: expandedContentHeight,
                        scale: 1,
                        y: 0,
                        originY: 0,
                    },
                }}
                transition={shellPathTransition}
            >
                {/* ── Shell: CSS-laid-out caps + flex middle ──────────────────
                    This is the SOLE black shell. Its outer edges track the container
                    width via flexbox each frame — exactly like the ears (right:-40px)
                    — so shell and ears stay welded through the spring overshoot. The
                    corner radius/height morph via the cap `d` (cosmetic); the middle
                    is a plain flex-grow rectangle. No path-animated full-width shape,
                    so there is nothing to diverge from the width and reveal a nub. */}
                <div className="absolute inset-0 w-full h-full z-0 pointer-events-none flex">
                    <div className="relative w-[60px] h-full flex-shrink-0">
                        <motion.svg width="60" height="100%" className="w-full h-full overflow-visible">
                            <motion.path
                                fill="#000000"
                                initial={false}
                                animate={isExpanded ? 'expanded' : 'collapsed'}
                                variants={{
                                    collapsed: { d: generateLeftCapPath(hoverCollapsedHeight, collapsedCornerRadius, collapsedCornerSmoothness) },
                                    expanded: { d: generateLeftCapPath(expandedContentHeight, EXPANDED_RADIUS, SQUIRCLE_SMOOTHNESS_EXPANDED) },
                                }}
                                transition={capEarTransition}
                            />
                        </motion.svg>
                    </div>
                    <div className="flex-1 bg-black h-full" />
                    <div className="relative w-[60px] h-full flex-shrink-0">
                        <motion.svg width="60" height="100%" className="w-full h-full overflow-visible">
                            <motion.path
                                fill="#000000"
                                initial={false}
                                animate={isExpanded ? 'expanded' : 'collapsed'}
                                variants={{
                                    collapsed: { d: generateRightCapPath(hoverCollapsedHeight, collapsedCornerRadius, collapsedCornerSmoothness) },
                                    expanded: { d: generateRightCapPath(expandedContentHeight, EXPANDED_RADIUS, SQUIRCLE_SMOOTHNESS_EXPANDED) },
                                }}
                                transition={capEarTransition}
                            />
                        </motion.svg>
                    </div>
                </div>

                {/* ── Liquid ears ── */}
                <div className="absolute top-0 w-[40px] h-[40px] z-50 pointer-events-none" style={{ left: '-40px' }}>
                    <motion.svg width="40" height="40" viewBox="0 0 40 40" fill="none" className="overflow-visible">
                        <motion.path
                            fill="#000000"
                            animate={{ d: generateEarPath(true, earTension, earBlendHeight, earSmoothness) }}
                            transition={capEarTransition}
                        />
                    </motion.svg>
                </div>
                <div className="absolute top-0 w-[40px] h-[40px] z-50 pointer-events-none" style={{ right: '-40px' }}>
                    <motion.svg width="40" height="40" viewBox="0 0 40 40" fill="none" className="overflow-visible">
                        <motion.path
                            fill="#000000"
                            animate={{ d: generateEarPath(false, earTension, earBlendHeight, earSmoothness) }}
                            transition={capEarTransition}
                        />
                    </motion.svg>
                </div>

                {/* ── Hit area + gesture handling ── */}
                <motion.div
                    ref={islandHitRef}
                    onPointerDown={handlePointerDown}
                    onPointerMove={handlePointerMove}
                    onPointerUp={handlePointerUp}
                    onPointerCancel={handlePointerCancel}
                    onWheel={handleTrackpadWheel}
                    className="w-full h-full flex flex-col items-center justify-start text-white select-none drag-region group pointer-events-auto"
                    style={{ backgroundColor: 'transparent', cursor: 'pointer', position: 'relative', zIndex: 9999 }}
                    onMouseEnter={() => {
                        if (!isExpanded) dispatch({ type: 'SET_HOVERED', payload: true });
                        try { (window as any).require('electron').ipcRenderer.send('set-ignore-mouse-events', false); } catch { }
                    }}
                    onMouseLeave={() => {
                        dispatch({ type: 'SET_HOVERED', payload: false });
                        clearTrackpadGestureState();
                        if (activePointerIdRef.current !== null || isGestureTrackingRef.current) return;
                        try {
                            if (!isExpandedRef.current) {
                                (window as any).require('electron').ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
                            }
                        } catch { }
                    }}
                >
                    {/* Body squircle removed: it was a full-width path whose right
                        edge is a framer path-spring, diverging from the width
                        number-spring and pulling the right ear off the body during
                        overshoot. The CSS cap layer above is now the sole shell. */}

                    {/* ── Inner edge stroke ── */}
                    <div className="absolute inset-0 w-full h-full pointer-events-none z-50">
                        <motion.svg className="w-full h-full overflow-visible" width="100%" height="100%" style={{ overflow: 'visible' }}>
                            <defs>
                                <clipPath id="inner-stroke-cut-top">
                                    <rect x="-100" y="21" width="2000" height="2000" />
                                </clipPath>
                            </defs>
                            <motion.path
                                fill="none"
                                stroke="rgba(255,255,255,0.12)"
                                strokeWidth="1"
                                vectorEffect="non-scaling-stroke"
                                clipPath="url(#inner-stroke-cut-top)"
                                initial={false}
                                animate={isExpanded ? 'expanded' : 'collapsed'}
                                variants={{
                                    collapsed: {
                                        d: isCollapseShellTransition ? openSquircleCollapsedPath
                                            : generateOpenSquirclePath(hoverCollapsedWidth, hoverCollapsedHeight, collapsedCornerRadius, collapsedCornerSmoothness),
                                    },
                                    expanded: { d: generateOpenSquirclePath(expandedWidth, expandedContentHeight, EXPANDED_RADIUS, SQUIRCLE_SMOOTHNESS_EXPANDED) },
                                }}
                                transition={shellPathTransition}
                            />
                        </motion.svg>
                    </div>

                    {/* ── Content ── */}
                    <motion.div layout="position" className="w-full h-full flex flex-col relative overflow-hidden">
                        {/* Collapsed content */}
                        <motion.div
                            initial={false}
                            animate={{ opacity: isExpanded ? 0 : 1, filter: isExpanded ? 'blur(5px)' : 'blur(0px)', scale: isExpanded ? 0.96 : 1, y: isExpanded ? -4 : 0, pointerEvents: isExpanded ? 'none' : 'auto' }}
                            transition={collapsedContentTransition}
                            className="absolute inset-0 w-full h-full z-20"
                        >
                            {showMusicActivity && musicData ? (
                                <MusicActivityContent
                                    musicData={musicData}
                                    themeColor={themeColor}
                                    activityOpenAnimToken={activityOpenAnimToken}
                                    isActivityOpenTransition={isActivityOpenTransition}
                                />
                            ) : !isLoggedIn ? (
                                <div className="flex items-center justify-center w-full h-full gap-2 px-3">
                                    <span className="material-symbols-outlined text-sm">login</span>
                                    <span className="text-sm font-bold">点击登录</span>
                                </div>
                            ) : isGreetingActive && greetingText ? (
                                <div className="flex items-center justify-center w-full h-full px-3">
                                    <motion.div
                                        key={greetingText}
                                        initial={{ opacity: 0, y: 6 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        exit={{ opacity: 0, y: -6 }}
                                        transition={{ duration: 0.35, ease: 'easeOut' }}
                                        className="w-full min-w-0"
                                    >
                                        <div className="text-[13px] font-semibold text-white/90 truncate text-center" style={{ fontFamily: '"SF Pro Text", "Inter", "PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif' }}>
                                            {greetingText}
                                        </div>
                                    </motion.div>
                                </div>
                            ) : showAppActivity ? (
                                <AppActivityContent
                                    appDisplayMode={appDisplayMode}
                                    data={data}
                                    todoPreview={todoPreview}
                                    activityOpenAnimToken={activityOpenAnimToken}
                                    isActivityOpenTransition={isActivityOpenTransition}
                                    onIconPointerDown={handleActivityLeftIconPointerDown}
                                    onIconPointerEnd={handleActivityLeftIconPointerEnd}
                                />
                            ) : mode === 'app' && appDisplayMode === 'todo' && !hasAppActivitySource ? (
                                <div className="flex items-center justify-between w-full h-full px-3">
                                    <div className="flex items-center gap-2 min-w-0">
                                        <span className="material-symbols-outlined text-sm text-cyan-300">checklist</span>
                                    </div>
                                    <span className="text-[12px] font-bold text-white/[0.84] leading-none">
                                        {`${Math.max(todoPreview.pending, 0)}`}
                                    </span>
                                </div>
                            ) : (
                                <div className="w-full h-full" />
                            )}
                        </motion.div>

                        {/* Expanded content */}
                        <motion.div
                            initial={false}
                            animate={{ opacity: isExpanded ? 1 : 0, filter: isExpanded ? 'blur(0px)' : 'blur(5px)', scale: isExpanded ? 1 : 0.96, y: isExpanded ? 0 : -4, pointerEvents: isExpanded ? 'auto' : 'none' }}
                            transition={expandedContentTransition}
                            className="flex flex-col w-full px-9 py-5 pb-5 z-10 overflow-hidden"
                            style={{ width: expandedWidth, minWidth: expandedWidth }}
                        >
                            {mode === 'music' && musicData ? (
                                <ExpandedMusicCard
                                    musicData={musicData}
                                    themeColor={themeColor}
                                    localPosition={localPosition}
                                    onPlayPause={handlePlayPause}
                                    onPrev={handlePrev}
                                    onNext={handleNext}
                                />
                            ) : appDisplayMode === 'todo' ? (
                                <ExpandedTodoCard
                                    todoPreview={todoPreview}
                                    todoPendingOps={todoPendingOps}
                                    onToggleTask={handleToggleTodoTask}
                                />
                            ) : (
                                <ExpandedReviewCard data={data} isExpanded={isExpanded} />
                            )}
                        </motion.div>
                    </motion.div>
                </motion.div>
            </motion.div>
        </div>
    );
};

export default DynamicIslandWidget;
