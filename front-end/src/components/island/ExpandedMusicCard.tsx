import React from 'react';
import { motion } from 'framer-motion';
import {
    EXPANDED_MUSIC_COVER_WIDTH,
    EXPANDED_MUSIC_COVER_HEIGHT,
    EXPANDED_MUSIC_COVER_RADIUS,
    EXPANDED_MUSIC_COVER_SMOOTHNESS,
} from '../islandGeometry';
import SquircleCoverThumb from './SquircleCoverThumb';
import MusicWaveform from './MusicWaveform';
import type { MusicData } from '../useIslandState';

const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
};

interface ExpandedMusicCardProps {
    musicData: MusicData;
    themeColor: string;
    localPosition: number;
    onPlayPause: (e: React.MouseEvent) => void;
    onPrev: (e: React.MouseEvent) => void;
    onNext: (e: React.MouseEvent) => void;
}

const ExpandedMusicCard: React.FC<ExpandedMusicCardProps> = ({
    musicData,
    themeColor,
    localPosition,
    onPlayPause,
    onPrev,
    onNext,
}) => (
    <div className="flex flex-col gap-2">
        {/* Metadata */}
        <div className="flex gap-4">
            <SquircleCoverThumb
                src={musicData.coverUrl}
                width={EXPANDED_MUSIC_COVER_WIDTH}
                height={EXPANDED_MUSIC_COVER_HEIGHT}
                radius={EXPANDED_MUSIC_COVER_RADIUS}
                smoothness={EXPANDED_MUSIC_COVER_SMOOTHNESS}
                shapeVariant="puffy"
                showGloss
                className="flex-shrink-0"
                style={{ filter: 'drop-shadow(0 10px 22px rgba(0,0,0,0.46)) drop-shadow(0 3px 10px rgba(0,0,0,0.2))' }}
                backgroundFill="rgba(255,255,255,0.12)"
                placeholderIconClassName="material-symbols-outlined text-[30px] text-white/50"
            />
            <div className="flex-1 flex flex-col justify-center min-w-0">
                <div className="flex items-center justify-between gap-2">
                    <div className="flex flex-col min-w-0 flex-1">
                        <span className="text-base text-white truncate" style={{ fontFamily: '"SF Pro Text", "Inter", "PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif' }}>
                            {musicData.title}
                        </span>
                        <span className="text-sm text-white/50 truncate" style={{ fontFamily: '"SF Pro Text", "Inter", "PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif' }}>
                            {musicData.artist}
                        </span>
                    </div>
                    <div className="flex-shrink-0">
                        <MusicWaveform color={themeColor} isPlaying={musicData.isPlaying} />
                    </div>
                </div>
            </div>
        </div>

        {/* Progress */}
        <div className="flex items-center gap-2 mt-1">
            <span className="text-[14px] font-medium tabular-nums leading-none" style={{ color: '#666666', fontFamily: '"SF Pro Text", "Inter", "PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif' }}>
                {formatTime(localPosition)}
            </span>
            <div className="flex-1 relative h-[8px] rounded-full overflow-hidden" style={{ backgroundColor: '#222222' }}>
                <div
                    className="absolute left-0 top-0 h-full transition-[width] duration-300 ease-linear"
                    style={{
                        backgroundColor: '#747376',
                        width: `${(localPosition / (musicData.duration || 1)) * 100}%`,
                    }}
                />
            </div>
            <span className="text-[14px] font-medium tabular-nums leading-none" style={{ color: '#666666', fontFamily: '"SF Pro Text", "Inter", "PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif' }}>
                -{formatTime(Math.max(0, (musicData.duration || 0) - localPosition))}
            </span>
        </div>

        {/* Controls */}
        <div className="flex items-center justify-center gap-6 mt-1" style={{ marginBottom: '5px' }}>
            <motion.button whileTap={{ scale: 0.9 }} className="p-2 text-white/40 hover:text-white transition-colors">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 2 L15 9 L22 9 L16.5 13 L18.5 21 L12 17 L5.5 21 L7.5 13 L2 9 L9 9 Z" />
                </svg>
            </motion.button>

            <motion.button onClick={onPrev} whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-1 text-white outline-none focus:outline-none">
                <svg width="36" height="36" viewBox="0 0 28 28" fill="currentColor">
                    <path d="M 23 6.5 C 23.7 6.5 24 7 24 7.8 L 24 20.2 C 24 21 23.7 21.5 23 21.5 C 22.5 21.5 22.1 21.3 21.5 20.8 L 14.5 15.6 C 14 15.2 13.5 14.7 13.5 14 C 13.5 13.3 14 12.8 14.5 12.4 L 21.5 7.2 C 22.1 6.7 22.5 6.5 23 6.5 Z" />
                    <path d="M 12.5 6.5 C 13.2 6.5 13.5 7 13.5 7.8 L 13.5 20.2 C 13.5 21 13.2 21.5 12.5 21.5 C 12 21.5 11.6 21.3 11 20.8 L 4 15.6 C 3.5 15.2 3 14.7 3 14 C 3 13.3 3.5 12.8 4 12.4 L 11 7.2 C 11.6 6.7 12 6.5 12.5 6.5 Z" />
                </svg>
            </motion.button>

            <motion.button onClick={onPlayPause} whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-1 text-white outline-none focus:outline-none">
                {musicData.isPlaying ? (
                    <svg width="52" height="52" viewBox="0 0 24 24" fill="currentColor">
                        <rect x="6" y="5" width="4" height="14" rx="1" />
                        <rect x="14" y="5" width="4" height="14" rx="1" />
                    </svg>
                ) : (
                    <svg width="52" height="52" viewBox="0 0 28 28" fill="currentColor">
                        <path d="M 8.5 6 C 7.5 6 6.5 6.8 6.5 8 L 6.5 20 C 6.5 21.2 7.5 22 8.5 22 C 8.9 22 9.4 21.8 9.8 21.5 L 20.8 15.5 C 21.8 14.8 21.8 13.2 20.8 12.5 L 9.8 6.5 C 9.4 6.2 8.9 6 8.5 6 Z" />
                    </svg>
                )}
            </motion.button>

            <motion.button onClick={onNext} whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="p-1 text-white outline-none focus:outline-none">
                <svg width="36" height="36" viewBox="0 0 28 28" fill="currentColor">
                    <path d="M 5.5 6.5 C 4.8 6.5 4.5 7 4.5 7.8 L 4.5 20.2 C 4.5 21 4.8 21.5 5.5 21.5 C 6 21.5 6.4 21.3 7 20.8 L 14 15.6 C 14.5 15.2 15 14.7 15 14 C 15 13.3 14.5 12.8 14 12.4 L 7 7.2 C 6.4 6.7 6 6.5 5.5 6.5 Z" />
                    <path d="M 15.5 6.5 C 14.8 6.5 14.5 7 14.5 7.8 L 14.5 20.2 C 14.5 21 14.8 21.5 15.5 21.5 C 16 21.5 16.4 21.3 17 20.8 L 24 15.6 C 24.5 15.2 25 14.7 25 14 C 25 13.3 24.5 12.8 24 12.4 L 17 7.2 C 16.4 6.7 16 6.5 15.5 6.5 Z" />
                </svg>
            </motion.button>

            <motion.button whileTap={{ scale: 0.9 }} className="p-2 text-white/40 hover:text-white transition-colors">
                <svg width="28" height="28" viewBox="0 0 26 24" fill="none" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M4 16V5c0-1.1.9-2 2-2h14c1.1 0 2 .9 2 2v11" fill="#1B1B1B" stroke="#6D6D6F" />
                    <rect x="0" y="15" width="26" height="3" rx="1" fill="#6D6D6F" stroke="none" />
                </svg>
            </motion.button>
        </div>
    </div>
);

export default ExpandedMusicCard;
