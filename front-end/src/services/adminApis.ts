import request from '@/utils/request';

// Admin API endpoints
const adminApis = {
    // Get admin dashboard stats
    getStats: () => {
        return request({
            url: '/admin/stats',
            method: 'get',
            headers: {
                'X-Admin-Token': 'admin123'
            }
        });
    },

    // Get user list with pagination and filtering
    getUserList: (page: number, size: number, email?: string, onlyBanned?: boolean) => {
        return request({
            url: '/admin/users',
            method: 'get',
            params: {
                page,
                size,
                email,
                onlyBanned
            },
            headers: {
                'X-Admin-Token': 'admin123' // Hardcoded for now as per requirements
            }
        });
    },

    // Ban a user
    banUser: (userId: number) => {
        return request({
            url: `/admin/user/ban/${userId}`,
            method: 'post',
            headers: {
                'X-Admin-Token': 'admin123'
            }
        });
    },

    // Unban a user
    unbanUser: (userId: number) => {
        return request({
            url: `/admin/user/unban/${userId}`,
            method: 'post',
            headers: {
                'X-Admin-Token': 'admin123'
            }
        });
    },

    // Get whitelist
    getWhitelist: (page: number, size: number) => {
        return request({
            url: '/admin/whitelist',
            method: 'get',
            params: {
                page,
                size
            },
            headers: {
                'X-Admin-Token': 'admin123'
            }
        });
    },

    // Add emails to whitelist
    addWhitelist: (emails: string[]) => {
        return request({
            url: '/admin/whitelist',
            method: 'post',
            data: emails,
            headers: {
                'X-Admin-Token': 'admin123'
            }
        });
    },

    // Remove email from whitelist
    removeWhitelist: (id: number) => {
        return request({
            url: `/admin/whitelist/${id}`,
            method: 'delete',
            headers: {
                'X-Admin-Token': 'admin123'
            }
        });
    }
};

export default adminApis;
