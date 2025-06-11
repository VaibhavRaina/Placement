import { useState, useEffect } from 'react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { CheckCircle, XCircle, Loader, Edit, Save } from 'lucide-react';
import toast from 'react-hot-toast';
import { authAPI, studentAPI } from '../../lib/api';
import { useAuth } from '../../context/AuthContext';

// Use default export instead of named export
export default function Profile() {
  const { user: authUser, updateUser } = useAuth();
  const [isLoading, setIsLoading] = useState(true);
  const [isChangingPassword, setIsChangingPassword] = useState(false);
  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [passwordData, setPasswordData] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });
  const [profileFormData, setProfileFormData] = useState({
    name: '',
    dob: '',
    semester: '',
    cgpa: '',
  });

  useEffect(() => {
    const initializeProfile = () => {
      if (authUser) {
        setProfileFormData({
          name: authUser.name ?? '',
          dob: authUser.dob ?? '',
          semester: authUser.semester?.toString() ?? '',
          cgpa: authUser.cgpa !== undefined && authUser.cgpa !== null ? authUser.cgpa.toString() : '',
        });
        setIsLoading(false);
      } else {
        // If no user in context, try to fetch from API
        const fetchProfile = async () => {
          try {
            const response = await authAPI.getCurrentUser();
            const userData = response.data.user ?? null;
            
            if (userData) {
              setProfileFormData({
                name: userData.name ?? '',
                dob: userData.dob ?? '',
                semester: userData.semester?.toString() ?? '',
                cgpa: userData.cgpa !== undefined && userData.cgpa !== null ? userData.cgpa.toString() : '',
              });
            }
          } catch (error) {
            console.error('Error fetching profile:', error);
            toast.error('Failed to load profile');
          } finally {
            setIsLoading(false);
          }
        };

        fetchProfile();
      }
    };

    initializeProfile();
  }, [authUser]);

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

  const handleProfileUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const updateData: {
        name?: string;
        semester?: number;
        cgpa?: number;
      } = {};
      
      if (profileFormData.name.trim()) updateData.name = profileFormData.name.trim();
      if (profileFormData.semester) updateData.semester = parseInt(profileFormData.semester);
      if (profileFormData.cgpa.trim()) updateData.cgpa = parseFloat(profileFormData.cgpa);
      
      const response = await studentAPI.updateStudentProfile(updateData);
      const updatedUser = response.data.user ?? response.data.student;
      
      if (updatedUser) {
        updateUser(updatedUser);
        toast.success('Profile updated successfully');
        setIsEditingProfile(false);
      }
    } catch (error: any) {
      const errorMessage = error.response?.data?.message ?? 'Failed to update profile';
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

  if (!authUser) {
    return (
      <div className="bg-white shadow rounded-lg p-6">
        <p className="text-red-500">Failed to load profile. Please try again later.</p>
      </div>
    );
  }

  return (
    <div className="bg-white shadow rounded-lg">
      <div className="p-6">
        {/* Welcome Section */}
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900">
            Welcome, {authUser.name ?? authUser.usn}!
          </h1>
          <p className="text-gray-600 mt-2">Manage your profile and placement information</p>
        </div>
        
        <div className="flex justify-between items-center">
          <h2 className="text-2xl font-bold text-gray-900">Profile Information</h2>
          <Button 
            variant={isEditingProfile ? "primary" : "outline"}
            onClick={() => setIsEditingProfile(!isEditingProfile)}
            className="flex items-center"
          >
            {isEditingProfile ? (
              <>
                <Save className="h-4 w-4 mr-2" />
                <span>Save Profile</span>
              </>
            ) : (
              <>
                <Edit className="h-4 w-4 mr-2" />
                <span>Edit Profile</span>
              </>
            )}
          </Button>
        </div>
        
        {/* Placement Status */}
        <div className="mt-6 p-4 bg-gray-50 rounded-lg">
          {authUser.placementStatus === 'Placed' ? (
            <div className="flex items-center text-green-700">
              <CheckCircle className="h-5 w-5 mr-2" />
              <span>Placed in {authUser.placedCompany}</span>
            </div>
          ) : (
            <div className="flex items-center text-gray-700">
              <XCircle className="h-5 w-5 mr-2" />
              <span>Not Placed in Any Company</span>
            </div>
          )}
        </div>

        {/* Profile Details */}
        {isEditingProfile ? (
          <form onSubmit={handleProfileUpdate} className="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-gray-700">Full Name</label>
              <Input
                type="text"
                value={profileFormData.name}
                onChange={(e) => setProfileFormData(prev => ({
                  ...prev,
                  name: e.target.value
                }))}
                placeholder="Enter your full name"
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">USN</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.usn}
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Email</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.email}
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Branch</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.branch}
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Semester</label>
              <Input
                type="number"
                min={1}
                max={8}
                value={profileFormData.semester}
                onChange={(e) => setProfileFormData(prev => ({
                  ...prev,
                  semester: e.target.value
                }))}
                placeholder="Enter your current semester (1-8)"
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">CGPA</label>
              <Input
                type="text"
                value={profileFormData.cgpa}
                onChange={(e) => {
                  const value = e.target.value;
                  // Allow empty string or valid decimal numbers
                  if (value === '' || /^\d*\.?\d*$/.test(value)) {
                    const numValue = parseFloat(value);
                    if (value === '' || (numValue >= 0 && numValue <= 10)) {
                      setProfileFormData(prev => ({
                        ...prev,
                        cgpa: value
                      }));
                    }
                  }
                }}
                placeholder="Enter your current CGPA (0-10)"
              />
            </div>
            
            <div className="sm:col-span-2 flex justify-end">
              <Button type="submit" className="ml-2">Save Changes</Button>
              <Button 
                type="button" 
                variant="outline" 
                className="ml-2"
                onClick={() => setIsEditingProfile(false)}
              >
                Cancel
              </Button>
            </div>
          </form>
        ) : (
          <div className="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2">
            <div>
              <label className="block text-sm font-medium text-gray-700">Full Name</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.name || 'Not set'}
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">USN</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.usn}
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Email</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.email}
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Semester</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.semester}
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Branch</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.branch}
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">CGPA</label>
              <p className="mt-1 p-2 block w-full rounded-md border border-gray-300 bg-gray-50">
                {authUser.cgpa !== undefined ? authUser.cgpa : 'Not set'}
              </p>
            </div>
          </div>
        )}

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