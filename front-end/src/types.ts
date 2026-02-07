export interface Goal {
    id: string;
    title: string;
    subtitle: string;
    priority?: boolean;
    daily?: boolean;
    labelType?: 'priority' | 'daily' | 'longterm';
    progress: number;
    icon: string;
    colorClass: string;
    iconBgClass: string;
    status: 'active' | 'completed';
    dueDate: string;
    progressGradient?: string;
}

export interface Subject {
    id: string;
    title: string;
    progress: number;
    totalTasks: number;
    completedTasks: number;
    icon: string;
    colorClass: string; // e.g., 'text-primary'
    bgClass: string; // e.g., 'bg-primary'
    status: 'In Progress' | 'Due Today' | 'Completed' | 'Pending';
}

export interface Topic {
    id: string;
    title: string;
    status: 'pending' | 'in-progress' | 'completed';
    notes?: string[];
    isExpanded?: boolean;
}

export interface Task {
    id: string;
    title: string;
    time?: string;
    completed: boolean;
    tag?: string;
    tagColor?: string;
}

export interface ApiResponse<T> {
    code: number;
    message: string;
    data: T;
}

export interface User {
    id: number;
    email: string;
    nickname: string;
    avatarUrl?: string;
    profession?: string;
    age?: string;
    role?: string;
}

export interface AuthResponse {
    accessToken: string;
    user: User;
}
