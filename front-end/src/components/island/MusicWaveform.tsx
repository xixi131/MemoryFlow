import React from 'react';
import { motion } from 'framer-motion';

interface MusicWaveformProps {
    color: string;
    isPlaying: boolean;
    count?: number;
}

const MusicWaveform: React.FC<MusicWaveformProps> = ({ color, isPlaying, count = 5 }) => {
    const bars = Array.from({ length: count }, (_, i) => i);
    const safeColor = /^#[0-9A-F]{6}$/i.test(color) ? color : '#22d3ee';

    return (
        <div className="flex items-center justify-center gap-[2px] h-6">
            {bars.map((i) => (
                <motion.div
                    key={i}
                    className="w-[3px] rounded-full"
                    style={{
                        background: `linear-gradient(180deg, ${safeColor} 0%, ${safeColor}33 100%)`,
                        transition: 'background 0.5s ease',
                    }}
                    initial={{ height: 4 }}
                    animate={isPlaying ? { height: [4, 16, 8, 20, 6, 12, 4] } : { height: 4 }}
                    transition={isPlaying ? {
                        duration: 2.2,
                        repeat: Infinity,
                        delay: i * 0.2,
                        ease: 'easeInOut',
                    } : {
                        duration: 0.3,
                        ease: 'easeOut',
                    }}
                />
            ))}
        </div>
    );
};

export default MusicWaveform;
