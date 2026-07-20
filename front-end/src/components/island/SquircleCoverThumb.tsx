import React, { useMemo, useId } from 'react';
import { generateFullSquirclePath, generatePuffyCoverPath } from '../islandGeometry';

interface SquircleCoverThumbProps {
    src?: string;
    width?: number;
    height?: number;
    radius?: number;
    smoothness?: number;
    shapeVariant?: 'rounded' | 'puffy';
    showGloss?: boolean;
    showRim?: boolean;
    className?: string;
    style?: React.CSSProperties;
    backgroundFill?: string;
    stroke?: string;
    strokeWidth?: number;
    placeholderIconClassName?: string;
}

const SquircleCoverThumb: React.FC<SquircleCoverThumbProps> = ({
    src,
    width = 22,
    height = 26,
    radius = 8.6,
    smoothness = 2.35,
    shapeVariant = 'rounded',
    showGloss = false,
    showRim = false,
    className,
    style,
    backgroundFill = 'rgba(255,255,255,0.1)',
    stroke = 'transparent',
    strokeWidth = 0.9,
    placeholderIconClassName = 'material-symbols-outlined text-[13px] text-white/50',
}) => {
    const rawId = useId();
    const clipId = useMemo(() => `cover-squircle-${rawId.replace(/:/g, '')}`, [rawId]);
    const glossId = useMemo(() => `cover-gloss-${rawId.replace(/:/g, '')}`, [rawId]);
    const shadeId = useMemo(() => `cover-shade-${rawId.replace(/:/g, '')}`, [rawId]);
    const rimId = useMemo(() => `cover-rim-${rawId.replace(/:/g, '')}`, [rawId]);
    const squirclePath = useMemo(
        () => shapeVariant === 'puffy'
            ? generatePuffyCoverPath(width, height, radius, smoothness)
            : generateFullSquirclePath(width, height, radius, smoothness),
        [width, height, radius, smoothness, shapeVariant]
    );

    return (
        <div
            className={`relative shrink-0 ${className || ''}`.trim()}
            style={{ width, height, ...style }}
        >
            <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="block">
                <defs>
                    <clipPath id={clipId}>
                        <path d={squirclePath} />
                    </clipPath>
                    <linearGradient id={glossId} x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="rgba(255,255,255,0.34)" />
                        <stop offset="22%" stopColor="rgba(255,255,255,0.14)" />
                        <stop offset="48%" stopColor="rgba(255,255,255,0.03)" />
                        <stop offset="70%" stopColor="rgba(255,255,255,0)" />
                    </linearGradient>
                    <linearGradient id={shadeId} x1="100%" y1="100%" x2="0%" y2="0%">
                        <stop offset="0%" stopColor="rgba(0,0,0,0.22)" />
                        <stop offset="28%" stopColor="rgba(0,0,0,0.1)" />
                        <stop offset="58%" stopColor="rgba(0,0,0,0)" />
                    </linearGradient>
                    <linearGradient id={rimId} x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="rgba(255,255,255,0.36)" />
                        <stop offset="35%" stopColor="rgba(255,255,255,0.12)" />
                        <stop offset="70%" stopColor="rgba(255,255,255,0.06)" />
                        <stop offset="100%" stopColor="rgba(255,255,255,0.14)" />
                    </linearGradient>
                </defs>

                <path d={squirclePath} fill={backgroundFill} />

                {src ? (
                    <image
                        href={src}
                        width={width}
                        height={height}
                        preserveAspectRatio="xMidYMid slice"
                        clipPath={`url(#${clipId})`}
                    />
                ) : null}

                {showGloss ? (
                    <>
                        <rect width={width} height={height} fill={`url(#${glossId})`} clipPath={`url(#${clipId})`} />
                        <rect width={width} height={height} fill={`url(#${shadeId})`} clipPath={`url(#${clipId})`} />
                    </>
                ) : null}

                <path
                    d={squirclePath}
                    fill="none"
                    stroke={showGloss && showRim ? `url(#${rimId})` : stroke}
                    strokeWidth={strokeWidth}
                    vectorEffect="non-scaling-stroke"
                />
            </svg>

            {!src ? (
                <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                    <span className={placeholderIconClassName}>music_note</span>
                </div>
            ) : null}
        </div>
    );
};

export default SquircleCoverThumb;
