import request from '@/utils/request';

// 仪表盘数据类型接口
export interface DashboardSummary {
    greeting: string;
    pendingReviewCount: number;
    completedReviewCount: number;
}

// 仪表盘相关的所有接口
const dashboardApis = {
    // 获取首页摘要数据
    getSummary: () => {
        return request({
            url: '/dashboard/summary',
            method: 'get'
        });
    }
}

export default dashboardApis;
