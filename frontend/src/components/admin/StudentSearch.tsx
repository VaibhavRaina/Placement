import { useState } from 'react';
import { Search, CheckCircle, XCircle, Loader } from 'lucide-react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import toast from 'react-hot-toast';
import { User } from '../../types';
import { studentAPI } from '../../lib/api';

export function StudentSearch() {
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [searchResult, setSearchResult] = useState<User | null>(null);
  const [isPlacingStudent, setIsPlacingStudent] = useState(false);
  const [companyName, setCompanyName] = useState('');
  const [isUpdating, setIsUpdating] = useState(false);

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchQuery.trim()) {
      toast.error('Please enter a USN to search');
      return;
    }

    setIsSearching(true);
    setSearchResult(null);
    
    try {
      const response = await studentAPI.getStudentByUSN(searchQuery.trim());
      // Handle both possible response formats (student or user property)
      const studentData = response.data.student || response.data.user;
      
      if (!studentData) {
        throw new Error('Student data not found in response');
      }
      
      setSearchResult(studentData);
      setIsPlacingStudent(false);
      setCompanyName('');
    } catch (error: any) {
      console.error('Search error:', error);
      const errorMessage = error.response?.data?.message || 'Student not found';
      toast.error(errorMessage);
      setSearchResult(null);
    } finally {
      setIsSearching(false);
    }
  };

  const handlePlaceStudent = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!companyName.trim()) {
      toast.error('Please enter company name');
      return;
    }

    setIsUpdating(true);
    try {
      const response = await studentAPI.updatePlacementStatus(
        searchResult!.usn!,
        {
          placementStatus: 'Placed',
          placedCompany: companyName.trim()
        }
      );
      
      // Handle both possible response formats
      const updatedStudent = response.data.student || response.data.user;
      
      toast.success(response.data.message || `Student marked as placed in ${companyName}`);
      if (updatedStudent) {
        setSearchResult(updatedStudent);
      }
      setIsPlacingStudent(false);
      setCompanyName('');
    } catch (error: any) {
      console.error('Update placement status error:', error);
      const errorMessage = error.response?.data?.message || 'Failed to update placement status';
      toast.error(errorMessage);
    } finally {
      setIsUpdating(false);
    }
  };

  return (
    <div className="bg-white shadow rounded-lg p-6">
      <h2 className="text-2xl font-bold text-gray-900 mb-6">Search Student</h2>

      <form onSubmit={handleSearch} className="flex gap-4 mb-6">
        <div className="flex-1">
          <Input
            placeholder="Enter USN (e.g., 1MS22CS154)"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="uppercase"
            disabled={isSearching}
          />
        </div>
        <Button type="submit" disabled={isSearching}>
          {isSearching ? (
            <Loader className="h-4 w-4 animate-spin mr-2" />
          ) : (
            <Search className="h-4 w-4 mr-2" />
          )}
          Search
        </Button>
      </form>

      {searchResult && (
        <div className="mt-6 border rounded-lg p-6">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">USN</label>
              <p className="mt-1 text-lg font-medium text-gray-900">{searchResult.usn}</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Email</label>
              <p className="mt-1 text-lg font-medium text-gray-900">{searchResult.email}</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Semester</label>
              <p className="mt-1 text-lg font-medium text-gray-900">{searchResult.semester}</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Branch</label>
              <p className="mt-1 text-lg font-medium text-gray-900">{searchResult.branch}</p>
            </div>
          </div>

          <div className="mt-6 p-4 bg-gray-50 rounded-lg">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                {searchResult.placementStatus === 'Placed' ? (
                  <>
                    <CheckCircle className="h-5 w-5 text-green-500 mr-2" />
                    <span className="text-green-700">
                      Placed in {searchResult.placedCompany}
                    </span>
                  </>
                ) : (
                  <>
                    <XCircle className="h-5 w-5 text-gray-400 mr-2" />
                    <span className="text-gray-700">Not Placed</span>
                  </>
                )}
              </div>
              {searchResult.placementStatus !== 'Placed' && (
                <Button
                  onClick={() => setIsPlacingStudent(true)}
                  variant="outline"
                  disabled={isUpdating}
                >
                  Mark as Placed
                </Button>
              )}
            </div>

            {isPlacingStudent && searchResult.placementStatus !== 'Placed' && (
              <form onSubmit={handlePlaceStudent} className="mt-4">
                <div className="flex gap-4">
                  <Input
                    placeholder="Enter company name"
                    value={companyName}
                    onChange={(e) => setCompanyName(e.target.value)}
                    required
                    disabled={isUpdating}
                  />
                  <Button type="submit" disabled={isUpdating}>
                    {isUpdating ? (
                      <Loader className="h-4 w-4 animate-spin mr-2" />
                    ) : (
                      'Confirm'
                    )}
                  </Button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  );
}