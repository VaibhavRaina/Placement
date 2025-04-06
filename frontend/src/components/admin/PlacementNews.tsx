import { useState } from 'react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { BRANCHES, Branch, JOB_TYPES, JobType } from '../../types';
import toast from 'react-hot-toast';
import { noticeAPI } from '../../lib/api';

// Package unit and frequency options
const PACKAGE_UNITS = ['LPA', 'K'];
const PACKAGE_FREQUENCIES = ['Monthly', 'Yearly'];

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
    jobType: JobType.FULLTIME
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
        jobType: formData.jobType
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
        jobType: JobType.FULLTIME
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

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Target Semesters</label>
          <div className="flex flex-wrap gap-2">
            {[1, 2, 3, 4, 5, 6, 7, 8].map((semester) => (
              <Button
                key={semester}
                type="button"
                variant={formData.targetSemesters.includes(semester) ? 'primary' : 'outline'}
                onClick={() => handleSemesterToggle(semester)}
                disabled={isLoading}
              >
                Sem {semester}
              </Button>
            ))}
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Target Branches</label>
          <div className="flex flex-wrap gap-2">
            {BRANCHES.map((branch) => (
              <Button
                key={branch}
                type="button"
                variant={formData.targetBranches.includes(branch as Branch) ? 'primary' : 'outline'}
                onClick={() => handleBranchToggle(branch as Branch)}
                disabled={isLoading}
              >
                {branch}
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