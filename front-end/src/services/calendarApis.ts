import request from '@/utils/request'

export interface CalendarRecordDTO {
    date: string; // 'YYYY-MM-DD'
    status: 'completed' | 'partial' | 'missed' | 'none';
    studyMinutes: number;
    pointsCompleted: number;
    wordsLearned: number;
    isToday: boolean;
}

const calendarApis = {
    // 获取指定月份的打卡记录
    getMonthlyRecords: (year: number, month: number) => {
        return request({
            url: '/calendar/records',
            method: 'get',
            params: { year, month }
        })
    }
}

export default calendarApis
