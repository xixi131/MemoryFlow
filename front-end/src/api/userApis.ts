import request from '@/utils/request';

// 用户相关的所有接口
const userApis = {
    // 用户登录
    login: (data: any) => {
        return request({
            url: '/auth/login',
            method: 'post',
            data
        })
    },

    // 用户注册
    register: (data: any) => {
        return request({
            url: '/auth/register',
            method: 'post',
            data
        })
    },

    // 发送验证码
    sendCode: (email: string, type: string = 'reset') => {
        return request({
            url: '/auth/send-code',
            method: 'post',
            data: { email, type }
        })
    },

    // 获取用户信息
    getUserInfo: () => {
        return request({
            url: '/auth/me',
            method: 'get'
        })
    },

    // 上传头像
    uploadAvatar: (file: File) => {
        const formData = new FormData();
        formData.append('file', file);
        return request({
            url: '/upload/avatar',
            method: 'post',
            data: formData,
            headers: {
                'Content-Type': 'multipart/form-data'
            }
        })
    },

    // 更新用户信息
    updateProfile: (data: any) => {
        return request({
            url: '/auth/profile',
            method: 'post',
            data
        })
    }
}

export default userApis;
