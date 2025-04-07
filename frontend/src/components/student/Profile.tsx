import { useState, useEffect } from 'react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { CheckCircle, XCircle, Loader } from 'lucide-react';
import toast from 'react-hot-toast';
import { authAPI } from '../../lib/api';
import { User } from '../../types';

export function Profile() {
  const [isLoading, setIsLoading] = useState(true);
  const [profileData, setProfileData] = useState<User | null>(null);
  const [isChangingPassword, setIsChangingPassword] = useState(false);
  const [passwordData, setPasswordData] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const response = await authAPI.getCurrentUser();
        setProfileData(response.data.user ?? null);
      } catch (error) {
        console.error('Error fetching profile:', error);
        toast.error('Failed to load profile');
      } finally {
        setIsLoading(false);
      }
    };

    fetchProfile();
  }, []);

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (passwordData.newPassword !== passwordData.confirmPassword) {
      toast.error('New passwords do not match');
      return;
    }

    try {
      await authAPI.changePassword({
        currentPassword: passwordData.currentPassword,
        newPassword: passwordData.newPassword,
        confirmPassword: passwordData.confirmPassword
      });
      
      toast.success('Password changed successfully');
      setIsChangingPassword(false);
      setPasswordData({
        currentPassword: '',
        newPassword: '',
        confirmPassword: '',
      });
    } catch (error: any) {
      const errorMessage = error.response?.data?.message || 'Failed to change password';
      toast.error(errorMessage);
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader className="h-8 w-8 animate-spin text-blue-600" />
      </div>
    );
  }

  if (!profileData) {
    return (
      <div className="bg-white shadow rounded-lg p-6">
        <p className="text-red-500">Failed to load profile. Please try again later.</p>
      </div>
    );
  }

  return (
    <div className="bg-white shadow rounded-lg">
      <div className="p-6">
        <h2 className="text-2xl font-bold text-gray-900">Profile Information</h2>
        
        {/* Placement Status */}
        <div className="mt-6 p-4 bg-gray-50 rounded-lg">
          {profileData.placementStatus === 'Placed' ? (
            <div className="flex items-center text-green-700">
              <CheckCircle className="h-5 w-5 mr-2" />
              <span>Placed in {profileData.placedCompany}</span>
            </div>
          ) : (
            <div className="flex items-center text-gray-700">
              <XCircle className="h-5 w-5 mr-2" />
              <span>Not Placed in Any Company</span>
            </div>
          )}
        </div>

        {/* Profile Details */}
        <div className="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2">
          <div>
            <label className="block text-sm font-medium text-gray-700">USN</label>
            <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
              {profileData.usn}
            </p>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700">Email</label>
            <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
              {profileData.email}
            </p>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700">Semester</label>
            <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
              {profileData.semester}
            </p>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700">Branch</label>
            <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
              {profileData.branch}
            </p>
          </div>
        </div>

        {/* Password Change Section */}
        <div className="mt-8">
          <Button
            variant="outline"
            onClick={() => setIsChangingPassword(!isChangingPassword)}
          >
            Change Password
          </Button>

          {isChangingPassword && (
            <form onSubmit={handlePasswordChange} className="mt-4 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Current Password
                </label>
                <Input
                  type="password"
                  value={passwordData.currentPassword}
                  onChange={(e) => setPasswordData(prev => ({
                    ...prev,
                    currentPassword: e.target.value
                  }))}
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  New Password
                </label>
                <Input
                  type="password"
                  value={passwordData.newPassword}
                  onChange={(e) => setPasswordData(prev => ({
                    ...prev,
                    newPassword: e.target.value
                  }))}
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">
                  Confirm New Password
                </label>
                <Input
                  type="password"
                  value={passwordData.confirmPassword}
                  onChange={(e) => setPasswordData(prev => ({
                    ...prev,
                    confirmPassword: e.target.value
                  }))}
                  required
                />
              </div>

              <Button type="submit">Update Password</Button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}