import api from './api';

export interface Word {
    id: number;
    word: string;
    phonetic: string;
    definition: string;
    translation: string;
    pos: string;
    audioUrl?: string;
    isLearned: boolean;
    detail?: string;
}

export interface StudySessionData {
    words: Word[];
    newCount: number;
    reviewCount: number;
    totalCount: number;
}

export interface Course {
    id: number;
    name: string;
    code: string;
    description: string;
    wordCount: number;
    difficulty: number;
    category?: string;
    coverImage?: string;
    icon: string;
    colorTheme: string;
    learnedCount?: number;
    dailyGoal?: number;
    isUserCourse?: boolean;
    progress?: number;
}

export const vocabularyApis = {
    // 获取所有可用课程
    getAllCourses: () => {
        return api.get<any, { code: number; data: Course[] }>('/vocabulary/courses');
    },
    
    // 获取用户已选课程
    getUserCourses: () => {
        return api.get('/vocabulary/courses/my');
    },

    // 选择/更新课程设置
    selectCourse: (data: { courseId: number; dailyGoal: number }) => {
        return api.post('/vocabulary/courses/select', data);
    },

    // 获取学习会话 (新增)
    getStudySession: (courseId?: number) => {
        return api.get<any, { code: number; data: StudySessionData }>('/vocabulary/session', { params: { courseId } });
    },

    // 学习单词 (新增)
    learnWord: (data: { wordId: number; courseId?: number }) => {
        return api.post('/vocabulary/words/learn', data);
    },

    // 复习单词 (新增)
    reviewWord: (data: { wordId: number; correct: boolean }) => {
        return api.post('/vocabulary/words/review', data);
    },
    
    // 获取学习统计
    getStats: () => {
        return api.get('/vocabulary/stats');
    },

    // 获取学习历史
    getLearnedHistory: (date: string) => {
        return api.get<any, { code: number; data: Word[] }>('/vocabulary/words/history', { params: { date } });
    }
};

export default vocabularyApis;
