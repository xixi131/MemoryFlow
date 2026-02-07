import React, { useState, useEffect, useRef } from 'react';

interface DatePickerProps {
    selectedDate: string;
    onChange: (date: string) => void;
}

const DatePicker: React.FC<DatePickerProps> = ({ selectedDate, onChange }) => {
    const [isOpen, setIsOpen] = useState(false);
    const [currentMonth, setCurrentMonth] = useState(new Date(selectedDate));
    const containerRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
                setIsOpen(false);
            }
        };

        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    const daysInMonth = (date: Date) => {
        return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
    };

    const firstDayOfMonth = (date: Date) => {
        return new Date(date.getFullYear(), date.getMonth(), 1).getDay();
    };

    const handlePrevMonth = () => {
        setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1));
    };

    const handleNextMonth = () => {
        setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1));
    };

    const handleDateClick = (day: number) => {
        const date = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), day);
        // Format as YYYY-MM-DD manually to avoid timezone issues
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(day).padStart(2, '0');
        onChange(`${year}-${month}-${d}`);
        setIsOpen(false);
    };

    const renderCalendar = () => {
        const days = [];
        const totalDays = daysInMonth(currentMonth);
        const startDay = firstDayOfMonth(currentMonth);

        // Empty cells for days before start of month
        for (let i = 0; i < startDay; i++) {
            days.push(<div key={`empty-${i}`} className="size-8 md:size-10"></div>);
        }

        // Days of month
        for (let day = 1; day <= totalDays; day++) {
            const date = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), day);
            const dateStr = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            const isSelected = dateStr === selectedDate;
            const isToday = dateStr === new Date().toISOString().split('T')[0];

            days.push(
                <button
                    key={day}
                    onClick={() => handleDateClick(day)}
                    className={`size-8 md:size-10 rounded-xl flex items-center justify-center text-sm font-bold transition-all
                        ${isSelected 
                            ? 'bg-primary text-white shadow-lg shadow-primary/30 scale-110' 
                            : isToday
                                ? 'border-2 border-primary text-primary'
                                : 'text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-white/10'
                        }`}
                >
                    {day}
                </button>
            );
        }

        return days;
    };

    return (
        <div className="relative" ref={containerRef}>
            <button
                onClick={() => setIsOpen(!isOpen)}
                className="flex items-center gap-3 px-5 py-3 rounded-2xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-white/5 shadow-sm hover:shadow-md transition-all group min-w-[180px]"
            >
                <span className="material-symbols-outlined text-slate-400 group-hover:text-primary transition-colors">calendar_month</span>
                <span className="text-slate-700 dark:text-white font-bold text-lg">{selectedDate}</span>
            </button>

            {isOpen && (
                <div className="absolute top-full left-0 mt-4 p-6 bg-white/90 dark:bg-[#0F172A]/90 backdrop-blur-xl border border-slate-200 dark:border-white/10 rounded-[2rem] shadow-2xl z-50 w-[320px] md:w-[360px] animate-fade-in-up">
                    {/* Header */}
                    <div className="flex items-center justify-between mb-6">
                        <button onClick={handlePrevMonth} className="size-8 rounded-full hover:bg-slate-100 dark:hover:bg-white/10 flex items-center justify-center transition-colors">
                            <span className="material-symbols-outlined text-slate-500">chevron_left</span>
                        </button>
                        <span className="text-lg font-bold text-slate-900 dark:text-white">
                            {currentMonth.toLocaleString('default', { month: 'long', year: 'numeric' })}
                        </span>
                        <button onClick={handleNextMonth} className="size-8 rounded-full hover:bg-slate-100 dark:hover:bg-white/10 flex items-center justify-center transition-colors">
                            <span className="material-symbols-outlined text-slate-500">chevron_right</span>
                        </button>
                    </div>

                    {/* Week Days */}
                    <div className="grid grid-cols-7 mb-2 text-center">
                        {['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map(d => (
                            <span key={d} className="text-xs font-bold text-slate-400 uppercase tracking-wider py-2">{d}</span>
                        ))}
                    </div>

                    {/* Days Grid */}
                    <div className="grid grid-cols-7 gap-1 place-items-center">
                        {renderCalendar()}
                    </div>
                </div>
            )}
        </div>
    );
};

export default DatePicker;
