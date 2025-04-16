import { useState } from 'react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { BRANCHES, Branch, JOB_TYPES, JobType } from '../../types';
import toast from 'react-hot-toast';
import { noticeAPI } from '../../lib/api';
import { Check, X } from 'lucide-react';

// Package unit and frequency options
const PACKAGE_UNITS = ['LPA', 'K'];
const PACKAGE_FREQUENCIES = ['Monthly', 'Yearly'];

// All available semesters
const ALL_SEMESTERS = [1, 2, 3, 4, 5, 6, 7, 8];

export function PlacementNews() {
  const [isLoading, setIsLoading] = useState(false);
  const [formData, setFormData] = useState({
    companyName: '',
    description: '',
    link: '',
    targetSemesters: [] as number[],
    targetBranches: [] as Branch[],
    targetYear: new Date().getFullYear(),
    packageAmount: '',
    packageUnit: 'LPA',
    packageFrequency: 'Yearly',
    jobType: JobType.FULLTIME,
    minCGPA: '',
    maxCGPA: ''
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.companyName || !formData.description || !formData.link || !formData.packageAmount) {
      toast.error('Please fill in all required fields');
      return;
    }

    if (formData.targetSemesters.length === 0 || formData.targetBranches.length === 0) {
      toast.error('Please select target semesters and branches');
      return;
    }

    // Validate CGPA range
    const minCgpaNum = parseFloat(formData.minCGPA);
    const maxCgpaNum = parseFloat(formData.maxCGPA);

    if ((formData.minCGPA && (isNaN(minCgpaNum) || minCgpaNum < 0 || minCgpaNum > 10)) ||
        (formData.maxCGPA && (isNaN(maxCgpaNum) || maxCgpaNum < 0 || maxCgpaNum > 10)) ||
        (formData.minCGPA && formData.maxCGPA && minCgpaNum > maxCgpaNum)) {
      toast.error('Invalid CGPA range. Values must be between 0 and 10, and Min cannot exceed Max.');
      return;
    }

    // Format the package string based on user inputs
    const packageOffered = `${formData.packageAmount} ${formData.packageUnit} ${
      formData.packageUnit === 'K' ? formData.packageFrequency : ''
    }`.trim();

    setIsLoading(true);
    
    try {
      // Call backend API to create notice
      await noticeAPI.createNotice({
        companyName: formData.companyName,
        description: formData.description,
        link: formData.link,
        targetSemesters: formData.targetSemesters,
        targetBranches: formData.targetBranches,
        targetYear: formData.targetYear,
        packageOffered: packageOffered,
        jobType: formData.jobType,
        minCGPA: formData.minCGPA ? minCgpaNum : undefined,
        maxCGPA: formData.maxCGPA ? maxCgpaNum : undefined
      });
      
      toast.success('Placement notice sent successfully');
      
      // Reset form
      setFormData({
        companyName: '',
        description: '',
        link: '',
        targetSemesters: [],
        targetBranches: [],
        targetYear: new Date().getFullYear(),
        packageAmount: '',
        packageUnit: 'LPA',
        packageFrequency: 'Yearly',
        jobType: JobType.FULLTIME,
        minCGPA: '',
        maxCGPA: ''
      });
    } catch (error: any) {
      console.error('Error creating notice:', error);
      const errorMessage = error.response?.data?.message || 'Failed to send placement notice';
      toast.error(errorMessage);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSemesterToggle = (semester: number) => {
    setFormData(prev => ({
      ...prev,
      targetSemesters: prev.targetSemesters.includes(semester)
        ? prev.targetSemesters.filter(s => s !== semester)
        : [...prev.targetSemesters, semester],
    }));
  };

  const handleBranchToggle = (branch: Branch) => {
    setFormData(prev => ({
      ...prev,
      targetBranches: prev.targetBranches.includes(branch)
        ? prev.targetBranches.filter(b => b !== branch)
        : [...prev.targetBranches, branch],
    }));
  };

  const selectAllSemesters = () => {
    setFormData(prev => ({
      ...prev,
      targetSemesters: [...ALL_SEMESTERS]
    }));
  };

  const clearAllSemesters = () => {
    setFormData(prev => ({
      ...prev,
      targetSemesters: []
    }));
  };

  const selectAllBranches = () => {
    setFormData(prev => ({
      ...prev,
      targetBranches: [...BRANCHES as Branch[]]
    }));
  };

  const clearAllBranches = () => {
    setFormData(prev => ({
      ...prev,
      targetBranches: []
    }));
  };

  return (
    <div className="bg-white shadow rounded-lg p-6">
      <h2 className="text-2xl font-bold text-gray-900 mb-6">Send Placement Notice</h2>
      
      <form onSubmit={handleSubmit} className="space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700">Company Name</label>
          <Input
            value={formData.companyName}
            onChange={(e) => setFormData(prev => ({ ...prev, companyName: e.target.value }))}
            required
            disabled={isLoading}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Package Offered</label>
          <div className="grid grid-cols-5 gap-4">
            <div className="col-span-2">
              <Input
                type="text"
                placeholder="Amount"
                value={formData.packageAmount}
                onChange={(e) => setFormData(prev => ({
                  ...prev,
                  packageAmount: e.target.value.replace(/[^\d.-]/g, '') // Only allow numbers, dots and dashes
                }))}
                required
                disabled={isLoading}
              />
            </div>
            
            <div className="col-span-1">
              <select
                value={formData.packageUnit}
                onChange={(e) => setFormData(prev => ({ ...prev, packageUnit: e.target.value }))}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                disabled={isLoading}
              >
                {PACKAGE_UNITS.map(unit => (
                  <option key={unit} value={unit}>{unit}</option>
                ))}
              </select>
            </div>
            
            <div className="col-span-2">
              <select
                value={formData.packageFrequency}
                onChange={(e) => setFormData(prev => ({ ...prev, packageFrequency: e.target.value }))}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                disabled={isLoading || formData.packageUnit === 'LPA'}
              >
                {PACKAGE_FREQUENCIES.map(frequency => (
                  <option key={frequency} value={frequency}>{frequency}</option>
                ))}
              </select>
            </div>
          </div>
          <p className="mt-1 text-xs text-gray-500">
            Example: 8.5 LPA or 40K Monthly
          </p>
        </div>
          
        <div>
          <label className="block text-sm font-medium text-gray-700">Job Type</label>
          <select
            value={formData.jobType}
            onChange={(e) => setFormData(prev => ({ ...prev, jobType: e.target.value as JobType }))}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            disabled={isLoading}
          >
            {JOB_TYPES.map((type) => (
              <option key={type} value={type}>
                {type}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">CGPA Criteria (Optional)</label>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Input
                type="text"
                placeholder="Min CGPA (e.g., 6.5)"
                value={formData.minCGPA}
                onChange={(e) => setFormData(prev => ({
                  ...prev,
                  minCGPA: e.target.value.replace(/[^\d.]/g, '') // Allow only numbers and dot
                }))}
                disabled={isLoading}
              />
            </div>
            <div>
              <Input
                type="text"
                placeholder="Max CGPA (e.g., 8.0)"
                value={formData.maxCGPA}
                onChange={(e) => setFormData(prev => ({
                  ...prev,
                  maxCGPA: e.target.value.replace(/[^\d.]/g, '') // Allow only numbers and dot
                }))}
                disabled={isLoading}
              />
            </div>
          </div>
          <p className="mt-1 text-xs text-gray-500">
            Leave blank if no specific CGPA range is required.
          </p>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">Description</label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
            rows={4}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            required
            disabled={isLoading}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">Apply/Test Link</label>
          <Input
            type="url"
            value={formData.link}
            onChange={(e) => setFormData(prev => ({ ...prev, link: e.target.value }))}
            required
            disabled={isLoading}
          />
        </div>

        <div className="border rounded-lg p-4">
          <div className="flex justify-between items-center mb-3">
            <label className="block text-sm font-medium text-gray-700">
              Target Semesters <span className="text-blue-600">({formData.targetSemesters.length} selected)</span>
            </label>
            <div className="flex gap-2">
              <Button 
                type="button" 
                size="sm" 
                onClick={selectAllSemesters} 
                disabled={isLoading || formData.targetSemesters.length === ALL_SEMESTERS.length}
              >
                Select All
              </Button>
              <Button 
                type="button" 
                size="sm" 
                variant="outline" 
                onClick={clearAllSemesters} 
                disabled={isLoading || formData.targetSemesters.length === 0}
              >
                Clear All
              </Button>
            </div>
          </div>
          
          {formData.targetSemesters.length > 0 && (
            <div className="mb-3 p-2 bg-gray-50 rounded-md">
              <p className="text-sm text-gray-700 mb-1">Selected semesters:</p>
              <div className="flex flex-wrap gap-1">
                {formData.targetSemesters
                  .sort((a, b) => a - b)
                  .map(semester => (
                    <span 
                      key={semester} 
                      className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
                    >
                      Sem {semester}
                      <X 
                        className="h-3 w-3 ml-1 cursor-pointer" 
                        onClick={() => handleSemesterToggle(semester)} 
                      />
                    </span>
                  ))
                }
              </div>
            </div>
          )}
          
          <div className="flex flex-wrap gap-2">
            {ALL_SEMESTERS.map((semester) => (
              <Button
                key={semester}
                type="button"
                variant={formData.targetSemesters.includes(semester) ? 'primary' : 'outline'}
                size="sm"
                onClick={() => handleSemesterToggle(semester)}
                disabled={isLoading}
                className={formData.targetSemesters.includes(semester) ? 'relative' : ''}
              >
                Sem {semester}
                {formData.targetSemesters.includes(semester) && (
                  <Check className="h-3 w-3 absolute top-1 right-1" />
                )}
              </Button>
            ))}
          </div>
        </div>

        <div className="border rounded-lg p-4">
          <div className="flex justify-between items-center mb-3">
            <label className="block text-sm font-medium text-gray-700">
              Target Branches <span className="text-blue-600">({formData.targetBranches.length} selected)</span>
            </label>
            <div className="flex gap-2">
              <Button 
                type="button" 
                size="sm" 
                onClick={selectAllBranches} 
                disabled={isLoading || formData.targetBranches.length === BRANCHES.length}
              >
                Select All
              </Button>
              <Button 
                type="button" 
                size="sm" 
                variant="outline" 
                onClick={clearAllBranches} 
                disabled={isLoading || formData.targetBranches.length === 0}
              >
                Clear All
              </Button>
            </div>
          </div>
          
          {formData.targetBranches.length > 0 && (
            <div className="mb-3 p-2 bg-gray-50 rounded-md">
              <p className="text-sm text-gray-700 mb-1">Selected branches:</p>
              <div className="flex flex-wrap gap-1">
                {formData.targetBranches.map(branch => (
                  <span 
                    key={branch} 
                    className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
                  >
                    {branch}
                    <X 
                      className="h-3 w-3 ml-1 cursor-pointer" 
                      onClick={() => handleBranchToggle(branch)} 
                    />
                  </span>
                ))}
              </div>
            </div>
          )}
          
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4">
            {BRANCHES.map((branch) => (
              <Button
                key={branch}
                type="button"
                variant={formData.targetBranches.includes(branch as Branch) ? 'primary' : 'outline'}
                size="sm"
                onClick={() => handleBranchToggle(branch as Branch)}
                disabled={isLoading}
                className={formData.targetBranches.includes(branch as Branch) ? 'relative' : ''}
              >
                {branch}
                {formData.targetBranches.includes(branch as Branch) && (
                  <Check className="h-3 w-3 absolute top-1 right-1" />
                )}
              </Button>
            ))}
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">Target Year</label>
          <select
            value={formData.targetYear}
            onChange={(e) => setFormData(prev => ({ ...prev, targetYear: parseInt(e.target.value) }))}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            disabled={isLoading}
          >
            {[2022, 2023, 2024, 2025, 2026].map((year) => (
              <option key={year} value={year}>
                {year}
              </option>
            ))}
          </select>
        </div>

        <Button type="submit" className="w-full" disabled={isLoading}>
          {isLoading ? 'Sending Notice...' : 'Send Notice'}
        </Button>
      </form>
    </div>
  );
}