import request from './api'

// 目标相关的所有接口
const goalApis = {
    // 获取用户所有目标
    getGoals: () => {
        return request({
            url: '/goals',
            method: 'get'
        })
    },

    // 创建目标
    createGoal: (data: { title: string; labelType: string; dueDate?: string }) => {
        return request({
            url: '/goals',
            method: 'post',
            data
        })
    },

    // 删除目标
    deleteGoal: (id: string) => {
        return request({
            url: `/goals/${id}`,
            method: 'delete'
        })
    },

    // 获取目标详情
    getGoalDetail: (id: string) => {
        return request({
            url: `/goals/${id}`,
            method: 'get'
        })
    },

    // 获取目标下的所有科目
    getGoalSubjects: (goalId: string) => {
        return request({
            url: `/subjects/goal/${goalId}`,
            method: 'get'
        })
    },

    // 创建科目
    createSubject: (data: { goalId: string; title: string; content?: string }) => {
        return request({
            url: '/subjects',
            method: 'post',
            data
        })
    }
}

export default goalApis
