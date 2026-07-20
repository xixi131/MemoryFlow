import React from 'react';
import { motion } from 'framer-motion';
import {
    COLLAPSED_MUSIC_COVER_WIDTH,
    COLLAPSED_MUSIC_COVER_HEIGHT,
    COLLAPSED_MUSIC_COVER_RADIUS,
    COLLAPSED_MUSIC_COVER_SMOOTHNESS,
    ACTIVITY_OPEN_CONTENT_DURATION_SECONDS,
    ACTIVITY_OPEN_CONTENT_DELAY_SECONDS,
} from '../islandGeometry';
import SquircleCoverThumb from './SquircleCoverThumb';
import MusicWaveform from './MusicWaveform';
import type { MusicData } from '../useIslandState';

interface MusicActivityContentProps {
    musicData: MusicData;
    themeColor: string;
    activityOpenAnimToken: number;
    isActivityOpenTransition: boolean;
}

const MusicActivityContent: React.FC<MusicActivityContentProps> = ({
    musicData,
    themeColor,
    activityOpenAnimToken,
    isActivityOpenTransition,
}) => (
    <motion.div
        key={`music-activity-${activityOpenAnimToken}`}
        initial={isActivityOpenTransition ? { opacity: 0, filter: 'blur(4px)' } : false}
        animate={{ opacity: 1, filter: 'blur(0px)' }}
        transition={isActivityOpenTransition
            ? { duration: ACTIVITY_OPEN_CONTENT_DURATION_SECONDS, delay: ACTIVITY_OPEN_CONTENT_DELAY_SECONDS, ease: 'easeOut' }
            : { duration: 0.12 }}
        className="w-full h-full"
    >
        <div className="flex items-center justify-between w-full h-full px-2">
            <div className="flex items-center pl-[6px]">
                <SquircleCoverThumb
                    src={musicData.coverUrl}
                    width={COLLAPSED_MUSIC_COVER_WIDTH}
                    height={COLLAPSED_MUSIC_COVER_HEIGHT}
                    radius={COLLAPSED_MUSIC_COVER_RADIUS}
                    smoothness={COLLAPSED_MUSIC_COVER_SMOOTHNESS}
                    shapeVariant="puffy"
                    showGloss
                    backgroundFill="rgba(255,255,255,0.1)"
                    placeholderIconClassName="material-symbols-outlined text-[14px] text-white/50"
                />
            </div>
            <div className="pr-[6px]">
                <MusicWaveform color={themeColor} isPlaying={musicData.isPlaying} count={4} />
            </div>
        </div>
    </motion.div>
);

export default MusicActivityContent;
