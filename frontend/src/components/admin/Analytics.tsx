import React, { useState, useEffect } from 'react';
import { BarChart3, TrendingUp, Users, Briefcase, Loader } from 'lucide-react';
import { studentAPI } from '../../lib/api';
import toast from 'react-hot-toast';
import { JobType, PlacementStatistics } from '../../types';

export function Analytics() {
  const [isLoading, setIsLoading] = useState(true);
  const [statistics, setStatistics] = useState<PlacementStatistics>({
    totalStudents: 0,
    placedStudents: 0,
    notPlacedStudents: 0,
    placementPercentage: 0,
    companiesStats: [],
    averagePackage: 0,
    jobTypeStats: []
  });

  useEffect(() => {
    const fetchStatistics = async () => {
      try {
        const response = await studentAPI.getPlacementStatistics();
        // Handle potential undefined values from the API response
        setStatistics({
          ...response.data.statistics,
          // Provide default values for potentially undefined properties
          averagePackage: response.data.statistics.averagePackage || 0,
          jobTypeStats: response.data.statistics.jobTypeStats || []
        });
      } catch (error) {
        console.error('Error fetching statistics:', error);
        toast.error('Failed to load placement statistics');
      } finally {
        setIsLoading(false);
      }
    };

    fetchStatistics();
  }, []);

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader className="h-8 w-8 animate-spin text-blue-600" />
      </div>
    );
  }

  // Format average package for display
  const formattedAvgPackage = statistics.averagePackage 
    ? `₹${statistics.averagePackage.toFixed(2)} LPA` 
    : 'N/A';
  
  // Calculate number of companies
  const companiesCount = statistics.companiesStats.length;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">Analytics Dashboard</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard 
          title="Total Students"
          value={statistics.totalStudents.toString()}
          icon={<Users className="h-6 w-6 text-blue-600" />}
          trend="--"
        />
        <StatCard 
          title="Placed Students"
          value={statistics.placedStudents.toString()}
          icon={<Briefcase className="h-6 w-6 text-green-600" />}
          trend={`${statistics.placementPercentage.toFixed(1)}%`}
        />
        <StatCard 
          title="Average Package"
          value={formattedAvgPackage}
          icon={<TrendingUp className="h-6 w-6 text-purple-600" />}
          trend="--"
        />
        <StatCard 
          title="Companies Visited"
          value={companiesCount.toString()}
          icon={<BarChart3 className="h-6 w-6 text-orange-600" />}
          trend="--"
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Company Statistics</h2>
          {statistics.companiesStats.length > 0 ? (
            <div className="space-y-4">
              {statistics.companiesStats.map((stat, index) => (
                <div key={index} className="flex items-center">
                  <div className="w-48 text-sm text-gray-600">{stat._id}</div>
                  <div className="flex-1">
                    <div className="h-4 bg-gray-100 rounded-full overflow-hidden">
                      <div 
                        className="h-full bg-blue-600 rounded-full"
                        style={{ width: `${(stat.count / statistics.placedStudents) * 100}%` }}
                      />
                    </div>
                  </div>
                  <div className="w-16 text-right text-sm text-gray-900">{stat.count}</div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-4">No placement data available yet</p>
          )}
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Job Type Distribution</h2>
          {statistics.jobTypeStats && statistics.jobTypeStats.length > 0 ? (
            <div className="space-y-4">
              {statistics.jobTypeStats.map((stat, index) => {
                const jobTypeColor = getJobTypeColor(stat._id as JobType);
                const total = statistics.jobTypeStats?.reduce((sum, s) => sum + s.count, 0) ?? 0;
                return (
                  <div key={index} className="flex items-center">
                    <div className="w-48 text-sm text-gray-600">{stat._id}</div>
                    <div className="flex-1">
                      <div className="h-4 bg-gray-100 rounded-full overflow-hidden">
                        <div 
                          className={`h-full rounded-full ${jobTypeColor}`}
                          style={{ width: `${(stat.count / total) * 100}%` }}
                        />
                      </div>
                    </div>
                    <div className="w-16 text-right text-sm text-gray-900">{stat.count}</div>
                  </div>
                );
              })}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-4">No job type data available yet</p>
          )}
        </div>
      </div>
    </div>
  );
}

interface StatCardProps {
  title: string;
  value: string;
  icon: React.ReactNode;
  trend: string;
}

function StatCard({ title, value, icon, trend }: StatCardProps) {
  return (
    <div className="bg-white rounded-lg shadow p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-2xl font-semibold text-gray-900 mt-1">{value}</p>
        </div>
        {icon}
      </div>
      <div className="mt-4">
        <span className="text-sm text-green-600 font-medium">{trend}</span>
      </div>
    </div>
  );
}

function getJobTypeColor(jobType: JobType): string {
  switch (jobType) {
    case JobType.FULLTIME:
      return 'bg-green-600';
    case JobType.INTERNSHIP:
      return 'bg-blue-600';
    case JobType.INTERNSHIP_FTE:
      return 'bg-purple-600';
    case JobType.CONTRACT:
      return 'bg-orange-600';
    default:
      return 'bg-gray-600';
  }
}