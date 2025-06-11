import React, { createContext, useContext, useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { User, UserRole } from '../types';
import { authAPI } from '../lib/api';

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isAdmin: boolean;
  isLoading: boolean;
  login: (user: User, token: string) => void;
  logout: () => void;
  updateUser: (userData: Partial<User>) => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  isAuthenticated: false,
  isAdmin: false,
  isLoading: true,
  login: () => {},
  logout: () => {},
  updateUser: () => {},
  refreshUser: async () => {},
});

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const navigate = useNavigate();

  // Initialize auth state from localStorage on app load
  useEffect(() => {
    const storedUser = localStorage.getItem('user');
    if (storedUser) {
      try {
        setUser(JSON.parse(storedUser));
      } catch (error) {
        console.error('Error parsing user data from localStorage', error);
        localStorage.removeItem('user');
        localStorage.removeItem('token');
      }
    }
    setIsLoading(false);
  }, []);

  const login = (userData: User, token: string) => {
    setUser(userData);
    localStorage.setItem('user', JSON.stringify(userData));
    localStorage.setItem('token', token);
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem('user');
    localStorage.removeItem('token');
    navigate('/');
  };

  const refreshUser = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        // No token, don't try to refresh
        return;
      }
      
      const response = await authAPI.getCurrentUser();
      const userData = response.data.user;
      if (userData) {
        setUser(userData);
        localStorage.setItem('user', JSON.stringify(userData));
      }
    } catch (error: any) {
      console.error('Error refreshing user data:', error);
      // Only logout if the error is 401 (unauthorized) or 403 (forbidden)
      // Don't logout on network errors or other temporary issues
      if (error.response?.status === 401 || error.response?.status === 403) {
        logout();
      }
    }
  };

  const contextValue = useMemo(() => ({
    user,
    isAuthenticated: !!user,
    isAdmin: user?.role === UserRole.ADMIN,
    isLoading,
    login,
    logout,
    refreshUser,
    updateUser: (userData: Partial<User>) => {
      if (user) {
        const updatedUser = { ...user, ...userData };
        setUser(updatedUser);
        localStorage.setItem('user', JSON.stringify(updatedUser));
      }
    },
  }), [user, isLoading]);

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);