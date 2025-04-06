import { Link, useLocation } from 'react-router-dom';
import { GraduationCap, User, LogOut } from 'lucide-react';
import { cn } from '../lib/utils';
import { useAuth } from '../context/AuthContext';
import { UserRole } from '../types';

export function Navbar() {
  const location = useLocation();
  const path = location.pathname;
  const { isAuthenticated, user, logout, isAdmin } = useAuth();

  // Don't show main navbar on student and admin dashboards as they have their own
  if (path.startsWith('/student') || path.startsWith('/admin')) {
    return null;
  }

  return (
    <nav className="bg-white shadow">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex">
            <Link to="/" className="flex items-center">
              <GraduationCap className="h-8 w-8 text-blue-600" />
              <span className="ml-2 text-lg font-semibold text-gray-900">
                Campus Placement Portal
              </span>
            </Link>
          </div>
          
          <div className="flex items-center space-x-4">
            {isAuthenticated ? (
              <>
                <Link
                  to={isAdmin ? '/admin' : '/student'}
                  className="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 hover:text-gray-700 hover:bg-gray-50 rounded-md"
                >
                  <User className="h-5 w-5 mr-2" />
                  {isAdmin ? 'Admin Dashboard' : 'Student Dashboard'}
                </Link>
                <button
                  onClick={logout}
                  className="inline-flex items-center px-4 py-2 text-sm font-medium text-red-600 hover:text-red-700 hover:bg-red-50 rounded-md"
                >
                  <LogOut className="h-5 w-5 mr-2" />
                  Logout
                </button>
              </>
            ) : (
              <>
                <Link
                  to="/login"
                  className={cn(
                    'px-3 py-2 rounded-md text-sm font-medium',
                    path === '/login'
                      ? 'bg-blue-100 text-blue-700'
                      : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'
                  )}
                >
                  Sign In
                </Link>
                <Link
                  to="/register"
                  className={cn(
                    'px-3 py-2 rounded-md text-sm font-medium',
                    path === '/register'
                      ? 'bg-blue-600 text-white'
                      : 'bg-blue-600 text-white hover:bg-blue-700'
                  )}
                >
                  Register
                </Link>
              </>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
}