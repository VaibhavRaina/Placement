import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { GraduationCap } from 'lucide-react';
import Button from '../components/ui/Button';
import Input from '../components/ui/Input';
import toast from 'react-hot-toast';
import { authAPI } from '../lib/api';
import { UserRole } from '../types';
import { useAuth } from '../context/AuthContext';

export default function Login() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [isAdmin, setIsAdmin] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [formData, setFormData] = useState({
    username: '',
    password: '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    
    try {
      // Call backend API to login
      const response = await authAPI.login({
        username: formData.username,
        password: formData.password
      });
      
      // Use the login function from AuthContext
      login(response.data.user, response.data.token);
      
      // Redirect based on user role
      if (response.data.user.role === UserRole.ADMIN) {
        toast.success('Welcome Admin!');
        navigate('/admin');
      } else {
        toast.success(`Welcome ${response.data.user.name ?? response.data.user.usn}!`);
        navigate('/student');
      }
    } catch (error: any) {
      console.error('Login error:', error);
      const errorMessage = error.response?.data?.message ?? 'Invalid credentials';
      toast.error(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="flex justify-center">
          <GraduationCap className="h-12 w-12 text-blue-600" />
        </div>
        <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
          Sign in to your account
        </h2>
        <p className="mt-2 text-center text-sm text-gray-600">
          {isAdmin ? (
            'Admin Portal'
          ) : (
            <>
              Or{' '}
              <Link to="/register" className="font-medium text-blue-600 hover:text-blue-500">
                register here
              </Link>
            </>
          )}
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
          <form className="space-y-6" onSubmit={handleSubmit}>
            <div>
              <label htmlFor="username" className="block text-sm font-medium text-gray-700">
                {isAdmin ? 'Username' : 'USN'}
              </label>
              <div className="mt-1">
                <Input
                  id="username"
                  name="username"
                  type="text"
                  required
                  value={formData.username}
                  onChange={(e) => setFormData({ ...formData, username: e.target.value })}
                  className={isAdmin ? "" : "uppercase"}
                />
              </div>
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                Password
              </label>
              <div className="mt-1">
                <Input
                  id="password"
                  name="password"
                  type="password"
                  required
                  value={formData.password}
                  onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                />
              </div>
            </div>

            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <input
                  id="isAdmin"
                  name="isAdmin"
                  type="checkbox"
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  checked={isAdmin}
                  onChange={(e) => {
                    setIsAdmin(e.target.checked);
                    if (e.target.checked) {
                      setFormData(prev => ({ ...prev, username: 'admin' }));
                    } else {
                      setFormData(prev => ({ ...prev, username: '' }));
                    }
                  }}
                />
                <label htmlFor="isAdmin" className="ml-2 block text-sm text-gray-900">
                  Login as Admin
                </label>
              </div>
            </div>

            <div>
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? 'Signing in...' : 'Sign in'}
              </Button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}