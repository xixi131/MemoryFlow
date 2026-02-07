import React, { useState, useEffect } from 'react';
import vocabularyApis, { Word } from '../services/vocabulary';
import DatePicker from './DatePicker';

interface LearnedHistoryProps {
    onBack: () => void;
}

const LearnedHistory: React.FC<LearnedHistoryProps> = ({ onBack }) => {
    const [date, setDate] = useState<string>(new Date().toISOString().split('T')[0]);
    const [words, setWords] = useState<Word[]>([]);
    const [loading, setLoading] = useState(false);
    const [audioPlaying, setAudioPlaying] = useState<number | null>(null);

    useEffect(() => {
        fetchHistory();
    }, [date]);

    const fetchHistory = async () => {
        setLoading(true);
        try {
            const res = await vocabularyApis.getLearnedHistory(date);
            if (res.code === 200) {
                setWords(res.data);
            }
        } catch (error) {
            console.error("Failed to fetch history", error);
        } finally {
            setLoading(false);
        }
    };

    const playAudio = (word: Word) => {
        if (word.audioUrl) {
            const audio = new Audio(word.audioUrl);
            setAudioPlaying(word.id);
            audio.onended = () => setAudioPlaying(null);
            audio.play().catch(e => console.error(e));
        } else {
            // TTS fallback
            if ('speechSynthesis' in window) {
                window.speechSynthesis.cancel();
                const utterance = new SpeechSynthesisUtterance(word.word);
                utterance.lang = 'en-US';
                utterance.onend = () => setAudioPlaying(null);
                setAudioPlaying(word.id);
                window.speechSynthesis.speak(utterance);
            }
        }
    };

    return (
        <div className="flex flex-col gap-10 w-full animate-fade-in pb-10">
            {/* Header */}
            <div className="flex flex-col gap-2 px-2">
                <div className="flex items-center gap-4">
                    <button 
                        onClick={onBack}
                        className="size-10 rounded-full bg-slate-200 dark:bg-white/10 flex items-center justify-center hover:bg-slate-300 dark:hover:bg-white/20 transition-colors"
                    >
                        <span className="material-symbols-outlined text-slate-700 dark:text-white">arrow_back</span>
                    </button>
                    <h2 className="text-4xl font-extrabold tracking-tight text-slate-900 dark:text-white">已学单词</h2>
                </div>
                <p className="text-slate-500 dark:text-slate-400 text-lg ml-14">回顾您的学习足迹</p>
            </div>

            {/* Date Filter */}
            <div className="flex items-center gap-4 px-2">
                <div className="flex items-center gap-4">
                    <span className="text-slate-500 font-bold hidden md:block">选择日期:</span>
                    <DatePicker selectedDate={date} onChange={setDate} />
                </div>
                <div className="text-slate-500 dark:text-slate-400 font-medium ml-auto">
                    共找到 <span className="text-primary font-bold text-xl">{words.length}</span> 个单词
                </div>
            </div>

            {/* Word List */}
            {loading ? (
                <div className="flex justify-center py-20">
                    <div className="size-12 rounded-full border-4 border-slate-200 dark:border-slate-700 border-t-primary animate-spin"></div>
                </div>
            ) : words.length > 0 ? (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {words.map(word => (
                        <div key={word.id} className="group bg-white dark:bg-slate-800 p-6 rounded-[2rem] border border-slate-200 dark:border-white/5 hover:border-primary/50 dark:hover:border-primary/50 transition-all hover:shadow-lg dark:hover:shadow-primary/10">
                            <div className="flex justify-between items-start mb-4">
                                <div>
                                    <h3 className="text-2xl font-bold text-slate-900 dark:text-white mb-1">{word.word}</h3>
                                    <div className="flex items-center gap-2 text-slate-500 dark:text-slate-400 cursor-pointer" onClick={() => playAudio(word)}>
                                        <span className="font-mono">/{word.phonetic}/</span>
                                        <span className={`material-symbols-outlined text-lg ${audioPlaying === word.id ? 'text-primary animate-pulse' : 'hover:text-primary'}`}>volume_up</span>
                                    </div>
                                </div>
                                <span className="px-3 py-1 rounded-full bg-slate-100 dark:bg-white/5 text-xs font-bold text-slate-500 uppercase tracking-wider">
                                    {word.pos}
                                </span>
                            </div>
                            <p className="text-slate-600 dark:text-slate-300 font-medium leading-relaxed bg-slate-50 dark:bg-black/20 p-4 rounded-xl">
                                {word.translation}
                            </p>
                        </div>
                    ))}
                </div>
            ) : (
                <div className="flex flex-col items-center justify-center py-20 text-slate-400 dark:text-slate-500">
                    <span className="material-symbols-outlined text-6xl mb-4">history_toggle_off</span>
                    <p className="text-xl font-medium">该日期没有学习记录</p>
                </div>
            )}
        </div>
    );
};

export default LearnedHistory;
