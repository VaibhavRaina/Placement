import axios from 'axios';
import {
  User,
  Notice,
  LoginCredentials,
  RegisterData,
  PasswordChangeData,
  PlacementStatusUpdate,
  NoticeData,
  PlacementStatistics
} from '../types';

// Using the proxy set up in vite.config.ts
const API_URL = '/api';

// Create axios instance with base URL
const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add interceptor to include auth token in requests
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response types
interface AuthResponse {
  success: boolean;
  user: User;
  token: string;
  message?: string;
}

// Extended to support both 'user' and 'student' properties
interface UserResponse {
  success: boolean;
  user?: User;
  student?: User; // For endpoints that return 'student' instead of 'user'
  message?: string;
}

interface NoticesResponse {
  success: boolean;
  count: number;
  notices: Notice[];
  message?: string;
}

interface MessageResponse {
  success: boolean;
  message: string;
}

interface StatisticsResponse {
  success: boolean;
  statistics: PlacementStatistics;
  message?: string;
}

interface StudentsResponse {
  success: boolean;
  count: number;
  students: User[];
  message?: string;
}

// Auth API calls
export const authAPI = {
  register: (userData: RegisterData) => 
    api.post<AuthResponse>('/auth/register', userData),
    
  login: (credentials: LoginCredentials) => 
    api.post<AuthResponse>('/auth/login', credentials),
    
  getCurrentUser: () => 
    api.get<UserResponse>('/auth/me'),
    
  changePassword: (passwordData: PasswordChangeData) => 
    api.put<MessageResponse>('/auth/change-password', passwordData),
};

// Student API calls
export const studentAPI = {
  getAllStudents: () => 
    api.get<StudentsResponse>('/students'),
    
  getStudentByUSN: (usn: string) => 
    api.get<UserResponse>(`/students/${usn}`),
    
  updatePlacementStatus: (usn: string, statusData: PlacementStatusUpdate) => 
    api.put<UserResponse>(`/students/${usn}/placement-status`, statusData),
    
  getPlacementStatistics: () => 
    api.get<StatisticsResponse>('/students/statistics'),
};

// Notice API calls
export const noticeAPI = {
  getAllNotices: () => 
    api.get<NoticesResponse>('/notices/all'),
    
  getStudentNotices: () => 
    api.get<NoticesResponse>('/notices/student'),
    
  createNotice: (noticeData: NoticeData) => 
    api.post<{ success: boolean; notice: Notice }>('/notices', noticeData),
    
  deleteNotice: (id: string) => 
    api.delete<MessageResponse>(`/notices/${id}`),
};

export default api;