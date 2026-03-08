import request from './api';

export interface Article {
    id: string;
    title: string;
    body: string;
}

export interface Point {
    id: string;
    title: string;
    status: string;
    isLearned: boolean;
    contents: Article[];
}

export interface Chapter {
    id: string;
    title: string;
    contents: Article[]; // Level 1 articles
    children: Point[];   // Level 2 points
}

export interface SubjectDetail {
    id: string;
    title: string;
    chapters: Chapter[];
}

const subjectApis = {
    // 获取科目详情
    getSubjectDetail: (id: string) => {
        return request({
            url: `/subjects/${id}`,
            method: 'get'
        });
    },

    // 获取章节详情（懒加载）
    getChapterDetail: (id: string) => {
        return request({
            url: `/subjects/chapters/${id}`,
            method: 'get'
        });
    },

    // 删除科目
    deleteSubject: (id: string) => {
        return request({
            url: `/subjects/${id}`,
            method: 'delete'
        });
    },

    // 追加内容
    appendContent: (id: string, content: string, chapterId?: string, pointId?: string) => {
        const payload: Record<string, string> = { content };
        if (chapterId) payload.chapterId = chapterId;
        if (pointId) payload.pointId = pointId;
        return request({
            url: `/subjects/${id}/append`,
            method: 'post',
            data: payload
        });
    },

    // 删除章节
    deleteChapter: (id: string) => {
        return request({
            url: `/subjects/chapters/${id}`,
            method: 'delete'
        });
    },

    // 删除要点
    deletePoint: (id: string) => {
        return request({
            url: `/subjects/points/${id}`,
            method: 'delete'
        });
    },

    // 删除文章
    deleteArticle: (id: string) => {
        return request({
            url: `/subjects/articles/${id}`,
            method: 'delete'
        });
    },

    // 更新文章
    updateArticle: (id: string, title: string, content: string) => {
        return request({
            url: `/subjects/articles/${id}`,
            method: 'put',
            data: { title, content }
        });
    },

    // 标记要点为已学习
    markPointLearned: (id: string) => {
        return request({
            url: `/points/${id}/learn`,
            method: 'post'
        });
    },

    // 取消要点已学习状态
    unmarkPointLearned: (id: string) => {
        return request({
            url: `/points/${id}/learn`,
            method: 'delete'
        });
    },

    // 标记章节为已学习
    markChapterLearned: (id: string) => {
        return request({
            url: `/subjects/chapters/${id}/learn`,
            method: 'post'
        });
    },

    // 取消章节已学习状态
    unmarkChapterLearned: (id: string) => {
        return request({
            url: `/subjects/chapters/${id}/learn`,
            method: 'delete'
        });
    },

    // 获取待复习列表
    getPendingReviews: () => {
        return request({
            url: '/reviews/pending',
            method: 'get'
        });
    },

    // 完成复习
    completeReview: (id: string) => {
        return request({
            url: `/points/${id}/review`,
            method: 'post'
        });
    },

    // 撤销复习
    revertReview: (id: string) => {
        return request({
            url: `/points/${id}/review/revert`,
            method: 'post'
        });
    }
};

export default subjectApis;
