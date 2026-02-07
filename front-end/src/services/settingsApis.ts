import request from '@/utils/request'

export interface UserSettingsDTO {
    id?: number;
    theme: 'dark' | 'light' | 'auto';
    dailyNewWordsGoal: number;
    reminderEnabled: boolean;
    reminderTime: string;
    emailReminderEnabled: boolean;
    autoPlayAudio: boolean;
    soundEffectsEnabled: boolean;
    widgetAutoStart: boolean;
    floatingWindowEnabled: boolean;
}

const settingsApis = {
    // 获取用户设置
    getSettings: () => {
        return request({
            url: '/settings',
            method: 'get'
        })
    },

    // 更新用户设置
    updateSettings: (data: Partial<UserSettingsDTO>) => {
        return request({
            url: '/settings',
            method: 'post',
            data
        })
    }
}

export default settingsApis
