import api from './api';
import { ApiResponse, AuthResponse, User } from '../types';

export const authService = {
  login: (data: any) => {
    return api.post<any, ApiResponse<AuthResponse>>('/auth/login', data);
  },

  register: (data: any) => {
    return api.post<any, ApiResponse<AuthResponse>>('/auth/register', data);
  },

  logout: () => {
    return api.post<any, ApiResponse<void>>('/auth/logout');
  },

  getCurrentUser: () => {
    return api.get<any, ApiResponse<User>>('/auth/me');
  },

  updateProfile: (data: any) => {
    return api.post<any, ApiResponse<User>>('/auth/profile', data);
  },

  sendCode: (email: string, type: string = 'reset') => {
    return api.post<any, ApiResponse<void>>('/auth/send-code', { email, type });
  },

  resetPassword: (data: any) => {
    return api.post<any, ApiResponse<void>>('/auth/reset-password', data);
  },

  changeEmail: (data: { code: string; newEmail: string }) => {
    return api.post<any, ApiResponse<void>>('/auth/change-email', data);
  }
};
