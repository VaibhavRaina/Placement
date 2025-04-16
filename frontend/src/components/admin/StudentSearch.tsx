import { useState, useEffect } from 'react';
import { Search, CheckCircle, XCircle, Loader, Save, Edit3 } from 'lucide-react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import toast from 'react-hot-toast';
import { User } from '../../types';
import { studentAPI } from '../../lib/api';

export function StudentSearch() {
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [searchResult, setSearchResult] = useState<User | null>(null);
  const [isEditingDetails, setIsEditingDetails] = useState(false);
  const [editableDetails, setEditableDetails] = useState({ 
    semester: '',
    cgpa: '',
  });
  const [isUpdatingDetails, setIsUpdatingDetails] = useState(false);
  const [isPlacingStudent, setIsPlacingStudent] = useState(false);
  const [companyName, setCompanyName] = useState('');
  const [isUpdatingPlacement, setIsUpdatingPlacement] = useState(false);

  useEffect(() => {
    if (searchResult) {
      setEditableDetails({
        semester: String(searchResult.semester || ''),
        cgpa: String(searchResult.cgpa || ''),
      });
      setIsEditingDetails(false);
    } else {
      setEditableDetails({ semester: '', cgpa: '' });
      setIsEditingDetails(false);
    }
  }, [searchResult]);

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchQuery.trim()) {
      toast.error('Please enter a USN to search');
      return;
    }

    setIsSearching(true);
    setSearchResult(null);
    
    try {
      const response = await studentAPI.getStudentByUSN(searchQuery.trim().toUpperCase());
      const studentData = response.data.student || response.data.user;
      
      if (!studentData) {
        throw new Error('Student data not found in response');
      }
      
      setSearchResult(studentData);
      setIsPlacingStudent(false);
      setCompanyName('');
    } catch (error: any) {
      console.error('Search error:', error);
      const errorMessage = error.response?.data?.message || 'Student not found or error fetching data';
      toast.error(errorMessage);
      setSearchResult(null);
    } finally {
      setIsSearching(false);
    }
  };

  const handleDetailChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    if ((name === 'semester' || name === 'cgpa') && value && !/^[\d.]*$/.test(value)) {
      return;
    }
    setEditableDetails(prev => ({ ...prev, [name]: value }));
  };

  const handleSaveDetails = async () => {
    if (!searchResult || !searchResult.usn) return;

    const semesterStr = editableDetails.semester.trim();
    const cgpaStr = editableDetails.cgpa.trim();

    if (!semesterStr || !cgpaStr) {
        toast.error('Semester and CGPA cannot be empty.');
        return;
    }

    const semesterNum = parseInt(semesterStr);
    const cgpaNum = parseFloat(cgpaStr);

    if (isNaN(semesterNum) || semesterNum < 1 || semesterNum > 8) {
      toast.error('Semester must be a number between 1 and 8');
      return;
    }
    if (isNaN(cgpaNum) || cgpaNum < 0 || cgpaNum > 10) {
      toast.error('CGPA must be a number between 0.0 and 10.0');
      return;
    }

    setIsUpdatingDetails(true);
    try {
      const response = await studentAPI.updateStudentDetailsByAdmin(searchResult.usn, {
        semester: semesterNum,
        cgpa: cgpaNum,
      });
      const updatedStudent = response.data.student || response.data.user;
      toast.success('Student details updated successfully');
      if (updatedStudent) {
        setSearchResult(updatedStudent);
      }
      setIsEditingDetails(false);
    } catch (error: any) {
      console.error('Update details error:', error);
      const errorMessage = error.response?.data?.message || 'Failed to update details';
      toast.error(errorMessage);
    } finally {
      setIsUpdatingDetails(false);
    }
  };

  const handlePlaceStudent = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmedCompanyName = companyName.trim();
    if (!trimmedCompanyName) {
      toast.error('Please enter company name');
      return;
    }
    if (!searchResult || !searchResult.usn) return;

    setIsUpdatingPlacement(true);
    try {
      const response = await studentAPI.updateStudentDetailsByAdmin(
        searchResult.usn,
        {
          placementStatus: 'Placed',
          placedCompany: trimmedCompanyName
        }
      );
      
      const updatedStudent = response.data.student || response.data.user;
      toast.success(response.data.message || `Student marked as placed in ${trimmedCompanyName}`);
      if (updatedStudent) {
        setSearchResult(updatedStudent);
      }
      setIsPlacingStudent(false);
      setCompanyName('');
    } catch (error: any) {
      console.error('Update placement status error:', error);
      const errorMessage = error.response?.data?.message || 'Failed to mark as placed';
      toast.error(errorMessage);
    } finally {
      setIsUpdatingPlacement(false);
    }
  };

  const handleMarkNotPlaced = async () => {
    if (!searchResult || !searchResult.usn) return;

    setIsUpdatingPlacement(true);
    try {
      const response = await studentAPI.updateStudentDetailsByAdmin(
        searchResult.usn,
        {
          placementStatus: 'Not Placed',
          placedCompany: ''
        }
      );
      
      const updatedStudent = response.data.student || response.data.user;
      toast.success(response.data.message || 'Student marked as Not Placed');
      if (updatedStudent) {
        setSearchResult(updatedStudent);
      }
    } catch (error: any) {
      console.error('Update placement status error:', error);
      const errorMessage = error.response?.data?.message || 'Failed to mark as not placed';
      toast.error(errorMessage);
    } finally {
      setIsUpdatingPlacement(false);
    }
  };

  const cancelEditDetails = () => {
    setIsEditingDetails(false);
    if (searchResult) {
      setEditableDetails({ 
        semester: String(searchResult.semester || ''), 
        cgpa: String(searchResult.cgpa || '') 
      });
    }
  };

  return (
    <div className="bg-white shadow rounded-lg p-6">
      <h2 className="text-2xl font-bold text-gray-900 mb-6">Search & Edit Student</h2>

      <form onSubmit={handleSearch} className="flex gap-4 mb-6">
        <div className="flex-1">
          <Input
            placeholder="Enter USN (e.g., 1MS22CS154)"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value.toUpperCase())}
            className="uppercase"
            disabled={isSearching || isUpdatingDetails || isUpdatingPlacement}
          />
        </div>
        <Button type="submit" disabled={isSearching || isUpdatingDetails || isUpdatingPlacement}>
          {isSearching ? (
            <Loader className="h-4 w-4 animate-spin mr-2" />
          ) : (
            <Search className="h-4 w-4 mr-2" />
          )}
          Search
        </Button>
      </form>

      {searchResult && (
        <div className="mt-6 border rounded-lg p-6 space-y-6">
          <div>
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-xl font-semibold text-gray-800">Student Details</h3>
              {!isEditingDetails && (
                <Button 
                  variant="outline"
                  size="sm"
                  onClick={() => setIsEditingDetails(true)}
                  disabled={isUpdatingDetails || isUpdatingPlacement}
                >
                  <Edit3 className="h-4 w-4 mr-2" />
                  Edit Details
                </Button>
              )}
            </div>
            <div className="grid grid-cols-2 gap-x-6 gap-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">USN</label>
                <p className="mt-1 text-base text-gray-900">{searchResult.usn}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Email</label>
                <p className="mt-1 text-base text-gray-900">{searchResult.email}</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Semester</label>
                {isEditingDetails ? (
                  <Input
                    type="text"
                    name="semester"
                    value={editableDetails.semester}
                    onChange={handleDetailChange}
                    maxLength={1}
                    disabled={isUpdatingDetails}
                    className="mt-1"
                  />
                ) : (
                  <p className="mt-1 text-base text-gray-900">{searchResult.semester}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">CGPA</label>
                {isEditingDetails ? (
                  <Input
                    type="text"
                    name="cgpa"
                    value={editableDetails.cgpa}
                    onChange={handleDetailChange}
                    maxLength={4}
                    disabled={isUpdatingDetails}
                    className="mt-1"
                  />
                ) : (
                  <p className="mt-1 text-base text-gray-900">{searchResult.cgpa}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Branch</label>
                <p className="mt-1 text-base text-gray-900">{searchResult.branch}</p>
              </div>
            </div>
            {isEditingDetails && (
              <div className="mt-4 flex justify-end gap-2">
                <Button 
                  variant="outline" 
                  onClick={cancelEditDetails}
                  disabled={isUpdatingDetails}
                >
                  Cancel
                </Button>
                <Button onClick={handleSaveDetails} disabled={isUpdatingDetails}>
                  {isUpdatingDetails ? (
                    <Loader className="h-4 w-4 animate-spin mr-2" />
                  ) : (
                    <Save className="h-4 w-4 mr-2" />
                  )}
                  Save Details
                </Button>
              </div>
            )}
          </div>

          <div className="mt-6 p-4 bg-gray-50 rounded-lg">
            <h3 className="text-lg font-semibold text-gray-800 mb-3">Placement Status</h3>
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
              <div className="flex gap-2">
                {searchResult.placementStatus === 'Placed' ? (
                  <Button
                    onClick={handleMarkNotPlaced}
                    variant="outline" // Changed from "destructive"
                    size="sm"
                    className="text-red-600 hover:text-red-700 border-red-300 hover:bg-red-50" // Add red styling
                    disabled={isUpdatingPlacement || isEditingDetails || isUpdatingDetails}
                  >
                    {isUpdatingPlacement ? <Loader className="h-4 w-4 animate-spin mr-2" /> : <XCircle className="h-4 w-4 mr-2" />}
                    Mark as Not Placed
                  </Button>
                ) : (
                  <Button
                    onClick={() => setIsPlacingStudent(true)}
                    variant="outline"
                    size="sm"
                    disabled={isUpdatingPlacement || isEditingDetails || isUpdatingDetails}
                  >
                    {isUpdatingPlacement ? <Loader className="h-4 w-4 animate-spin mr-2" /> : <CheckCircle className="h-4 w-4 mr-2" />}
                    Mark as Placed
                  </Button>
                )}
              </div>
            </div>

            {isPlacingStudent && searchResult.placementStatus !== 'Placed' && (
              <form onSubmit={handlePlaceStudent} className="mt-4 border-t pt-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">Company Name</label>
                <div className="flex gap-2">
                  <Input
                    placeholder="Enter company name"
                    value={companyName}
                    onChange={(e) => setCompanyName(e.target.value)}
                    required
                    disabled={isUpdatingPlacement}
                    className="flex-grow"
                  />
                  <Button type="submit" disabled={isUpdatingPlacement} size="sm">
                    {isUpdatingPlacement ? (
                      <Loader className="h-4 w-4 animate-spin mr-2" />
                    ) : (
                      'Confirm Placement'
                    )}
                  </Button>
                  <Button 
                    type="button"
                    variant="outline" 
                    size="sm"
                    onClick={() => setIsPlacingStudent(false)} 
                    disabled={isUpdatingPlacement}
                  >
                    Cancel
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