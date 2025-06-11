import { Link, useLocation } from 'react-router-dom';
import { User, BellPlus, BarChart, Search, LogOut } from 'lucide-react';
import { cn } from '../../lib/utils';
import { useAuth } from '../../context/AuthContext';

export function AdminNavbar() {
  const location = useLocation();
  const { logout } = useAuth();

  const links = [
    { href: '/admin', icon: User, label: 'Profile' },
    { href: '/admin/news', icon: BellPlus, label: 'Send Placement News' },
    { href: '/admin/analytics', icon: BarChart, label: 'Analytics' },
    { href: '/admin/search', icon: Search, label: 'Search Student' },
  ];

  return (
    <nav className="bg-white shadow">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex">
            {links.map((link) => (
              <Link
                key={link.href}
                to={link.href}
                className={cn(
                  'inline-flex items-center px-4 text-sm font-medium border-b-2 hover:border-gray-300 hover:text-gray-700',
                  location.pathname === link.href
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500'
                )}
              >
                <link.icon className="h-5 w-5 mr-2" />
                {link.label}
              </Link>
            ))}
          </div>
          <div className="flex items-center space-x-4">
            <button
              onClick={logout}
              className="inline-flex items-center px-4 py-2 text-sm font-medium text-red-600 hover:text-red-700 hover:bg-red-50 rounded-md"
            >
              <LogOut className="h-5 w-5 mr-2" />
              Logout
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
}