import { useEffect, useState } from 'react';
import { ExternalLink, Loader, Briefcase, DollarSign } from 'lucide-react';
import { noticeAPI } from '../../lib/api';
import { Notice } from '../../types';
import toast from 'react-hot-toast';
import { useAuth } from '../../context/AuthContext';

export function PlacementOffers() {
  const { user } = useAuth(); // Get user directly from auth context
  const [isLoading, setIsLoading] = useState(true);
  const [notices, setNotices] = useState<Notice[]>([]);
  const [userPlacementStatus, setUserPlacementStatus] = useState<{
    isPlaced: boolean;
    placedCompany: string | null;
  }>({
    isPlaced: false,
    placedCompany: null
  });
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [debugInfo, setDebugInfo] = useState<{
    user: any;
    responseMessage: string;
  }>({ user: null, responseMessage: '' });

  useEffect(() => {
    const fetchNotices = async () => {
      try {
        // Set placement status from auth context
        if (user) {
          setUserPlacementStatus({
            isPlaced: user.placementStatus === 'Placed',
            placedCompany: user.placedCompany ?? null
          });
          
          // Capture user data for debugging
          setDebugInfo(prev => ({
            ...prev,
            user: {
              semester: user.semester,
              branch: user.branch,
              year: user.year
            }
          }));
        } else {
          setErrorMessage('User information not found');
          return;
        }
        
        // Fetch notices from backend
        const response = await noticeAPI.getStudentNotices();
        setNotices(response.data.notices || []);
        
        // Save response message for debugging
        if (response.data.message) {
          setErrorMessage(response.data.message);
          setDebugInfo(prev => ({
            ...prev,
            responseMessage: response.data.message ?? ''
          }));
        }
      } catch (error: any) {
        console.error('Error fetching notices:', error);
        toast.error('Failed to load placement offers');
        setErrorMessage('Failed to load placement offers');
      } finally {
        setIsLoading(false);
      }
    };

    fetchNotices();
  }, [user]);

  if (isLoading) {
    return (
      <div className="bg-white shadow rounded-lg p-6">
        <div className="flex justify-center items-center h-64">
          <Loader className="h-8 w-8 animate-spin text-blue-600" />
        </div>
      </div>
    );
  }

  if (userPlacementStatus.isPlaced) {
    return (
      <div className="bg-white shadow rounded-lg p-6">
        <div className="bg-blue-50 border border-blue-200 rounded-md p-4 mb-6">
          <p className="text-blue-700">
            You are already placed in {userPlacementStatus.placedCompany}. No further applications allowed.
          </p>
        </div>

        {/* Summary Section - For placed students */}
        <div className="bg-gradient-to-r from-gray-50 to-gray-100 rounded-lg p-4 border border-gray-200 mb-6 opacity-75">
          <h2 className="text-2xl font-bold text-gray-700 mb-4">Available Opportunities (View Only)</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="bg-white rounded-lg p-4 shadow-sm border border-blue-200">
              <div className="flex items-center">
                <Briefcase className="h-8 w-8 text-blue-600 mr-3" />
                <div>
                  <p className="text-2xl font-bold text-blue-600">
                    {notices.filter(n => n.jobType === 'Full Time' || n.jobType === 'Internship + Full Time').length}
                  </p>
                  <p className="text-sm text-gray-600">Full-Time Jobs</p>
                </div>
              </div>
            </div>
            <div className="bg-white rounded-lg p-4 shadow-sm border border-purple-200">
              <div className="flex items-center">
                <svg className="h-8 w-8 text-purple-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
                <div>
                  <p className="text-2xl font-bold text-purple-600">
                    {notices.filter(n => n.jobType === 'Internship').length}
                  </p>
                  <p className="text-sm text-gray-600">Internships</p>
                </div>
              </div>
            </div>
            <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
              <div className="flex items-center">
                <svg className="h-8 w-8 text-gray-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
                <div>
                  <p className="text-2xl font-bold text-gray-600">
                    {notices.length}
                  </p>
                  <p className="text-sm text-gray-600">Total Opportunities</p>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div className="space-y-8 opacity-50 pointer-events-none">
          {/* Full-Time Opportunities Section - Disabled */}
          <div>
            <div className="mb-4">
              <h3 className="text-xl font-semibold text-gray-900 flex items-center">
                <Briefcase className="h-5 w-5 mr-2 text-blue-600" />
                Full-Time Opportunities
              </h3>
              <div className="mt-2 h-0.5 bg-gradient-to-r from-blue-600 to-blue-300 rounded-full w-48"></div>
            </div>
            {(() => {
              const fullTimeNotices = notices.filter(notice => 
                notice.jobType === 'Full Time' || notice.jobType === 'Internship + Full Time'
              );
              return fullTimeNotices.length > 0 ? (
                <div className="space-y-4">
                  {fullTimeNotices.map((notice) => (
                    <PlacementNoticeCard key={notice._id} notice={notice} disabled />
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
                  <Briefcase className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                  <p className="text-gray-500">No full-time opportunities available at the moment.</p>
                </div>
              );
            })()}
          </div>

          {/* Internship Opportunities Section - Disabled */}
          <div>
            <div className="mb-4">
              <h3 className="text-xl font-semibold text-gray-900 flex items-center">
                <svg className="h-5 w-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
                Internship Opportunities
              </h3>
              <div className="mt-2 h-0.5 bg-gradient-to-r from-purple-600 to-purple-300 rounded-full w-48"></div>
            </div>
            {(() => {
              const internshipNotices = notices.filter(notice => 
                notice.jobType === 'Internship'
              );
              return internshipNotices.length > 0 ? (
                <div className="space-y-4">
                  {internshipNotices.map((notice) => (
                    <PlacementNoticeCard key={notice._id} notice={notice} disabled />
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
                  <svg className="h-12 w-12 text-gray-400 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                  <p className="text-gray-500">No internship opportunities available at the moment.</p>
                </div>
              );
            })()}
          </div>

          {/* Contract Opportunities Section - Disabled (if any exist) */}
          {(() => {
            const contractNotices = notices.filter(notice => 
              notice.jobType === 'Contract'
            );
            return contractNotices.length > 0 ? (
              <div>
                <div className="mb-4">
                  <h3 className="text-xl font-semibold text-gray-900 flex items-center">
                    <svg className="h-5 w-5 mr-2 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    Contract Opportunities
                  </h3>
                  <div className="mt-2 h-0.5 bg-gradient-to-r from-orange-600 to-orange-300 rounded-full w-48"></div>
                </div>
                <div className="space-y-4">
                  {contractNotices.map((notice) => (
                    <PlacementNoticeCard key={notice._id} notice={notice} disabled />
                  ))}
                </div>
              </div>
            ) : null;
          })()}
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white shadow rounded-lg p-6">
      {errorMessage && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-md p-4 mb-6">
          <p className="text-yellow-700">{errorMessage}</p>
        </div>
      )}
      
      {notices.length === 0 && !errorMessage ? (
        <div>
          <div className="text-center py-12">
            <div className="mb-6">
              <svg className="h-16 w-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0H8m8 0v2a2 2 0 002 2H6a2 2 0 002-2V6m0 0V4a2 2 0 012-2h4a2 2 0 012 2v2m-6 12a2 2 0 100-4 2 2 0 000 4zm0 0v2a2 2 0 002 2h4a2 2 0 002-2v-2m-6 0a2 2 0 002-2h4a2 2 0 002 2v2m-6 0H6m6 0v-2a2 2 0 00-2-2H6a2 2 0 00-2 2v2z" />
              </svg>
              <h3 className="text-lg font-medium text-gray-900 mb-2">No Opportunities Available</h3>
              <p className="text-gray-500">No placement offers are available for your profile at the moment.</p>
              <p className="text-sm text-gray-400 mt-2">Check back later or contact the placement office for updates.</p>
            </div>
          </div>
          
          {/* Debugging information, only visible in development */}
          {process.env.NODE_ENV === 'development' && (
            <div className="mt-8 border-t pt-4">
              <details>
                <summary className="text-sm text-gray-500 cursor-pointer">Debug Information</summary>
                <div className="mt-2 p-4 bg-gray-100 rounded text-xs">
                  <h4 className="font-medium mb-2">User Profile:</h4>
                  <pre>{JSON.stringify(debugInfo.user, null, 2)}</pre>
                  
                  <h4 className="font-medium mt-4 mb-2">Response Message:</h4>
                  <pre>{debugInfo.responseMessage || 'No message'}</pre>
                </div>
              </details>
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-8">
          {/* Summary Section */}
          <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg p-4 border border-blue-200">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Available Opportunities</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="bg-white rounded-lg p-4 shadow-sm border border-blue-200">
                <div className="flex items-center">
                  <Briefcase className="h-8 w-8 text-blue-600 mr-3" />
                  <div>
                    <p className="text-2xl font-bold text-blue-600">
                      {notices.filter(n => n.jobType === 'Full Time' || n.jobType === 'Internship + Full Time').length}
                    </p>
                    <p className="text-sm text-gray-600">Full-Time Jobs</p>
                  </div>
                </div>
              </div>
              <div className="bg-white rounded-lg p-4 shadow-sm border border-purple-200">
                <div className="flex items-center">
                  <svg className="h-8 w-8 text-purple-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                  <div>
                    <p className="text-2xl font-bold text-purple-600">
                      {notices.filter(n => n.jobType === 'Internship').length}
                    </p>
                    <p className="text-sm text-gray-600">Internships</p>
                  </div>
                </div>
              </div>
              <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
                <div className="flex items-center">
                  <svg className="h-8 w-8 text-gray-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                  <div>
                    <p className="text-2xl font-bold text-gray-600">
                      {notices.length}
                    </p>
                    <p className="text-sm text-gray-600">Total Opportunities</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Full-Time Opportunities Section */}
          <div>
            <div className="mb-4">
              <h3 className="text-xl font-semibold text-gray-900 flex items-center">
                <Briefcase className="h-5 w-5 mr-2 text-blue-600" />
                Full-Time Opportunities
              </h3>
              <div className="mt-2 h-0.5 bg-gradient-to-r from-blue-600 to-blue-300 rounded-full w-48"></div>
            </div>
            {(() => {
              const fullTimeNotices = notices.filter(notice => 
                notice.jobType === 'Full Time' || notice.jobType === 'Internship + Full Time'
              );
              return fullTimeNotices.length > 0 ? (
                <div className="space-y-4">
                  {fullTimeNotices.map((notice) => (
                    <PlacementNoticeCard key={notice._id} notice={notice} />
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
                  <Briefcase className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                  <p className="text-gray-500">No full-time opportunities available at the moment.</p>
                </div>
              );
            })()}
          </div>

          {/* Internship Opportunities Section */}
          <div>
            <div className="mb-4">
              <h3 className="text-xl font-semibold text-gray-900 flex items-center">
                <svg className="h-5 w-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
                Internship Opportunities
              </h3>
              <div className="mt-2 h-0.5 bg-gradient-to-r from-purple-600 to-purple-300 rounded-full w-48"></div>
            </div>
            {(() => {
              const internshipNotices = notices.filter(notice => 
                notice.jobType === 'Internship'
              );
              return internshipNotices.length > 0 ? (
                <div className="space-y-4">
                  {internshipNotices.map((notice) => (
                    <PlacementNoticeCard key={notice._id} notice={notice} />
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
                  <svg className="h-12 w-12 text-gray-400 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                  <p className="text-gray-500">No internship opportunities available at the moment.</p>
                </div>
              );
            })()}
          </div>

          {/* Contract Opportunities Section (if any exist) */}
          {(() => {
            const contractNotices = notices.filter(notice => 
              notice.jobType === 'Contract'
            );
            return contractNotices.length > 0 ? (
              <div>
                <div className="mb-4">
                  <h3 className="text-xl font-semibold text-gray-900 flex items-center">
                    <svg className="h-5 w-5 mr-2 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    Contract Opportunities
                  </h3>
                  <div className="mt-2 h-0.5 bg-gradient-to-r from-orange-600 to-orange-300 rounded-full w-48"></div>
                </div>
                <div className="space-y-4">
                  {contractNotices.map((notice) => (
                    <PlacementNoticeCard key={notice._id} notice={notice} />
                  ))}
                </div>
              </div>
            ) : null;
          })()}
        </div>
      )}
    </div>
  );
}

function PlacementNoticeCard({ notice, disabled = false }: { readonly notice: Notice; readonly disabled?: boolean }) {
  // Determine card styling based on job type
  const getJobTypeStyle = (jobType: string) => {
    switch (jobType) {
      case 'Full Time':
        return {
          borderColor: 'border-blue-200',
          bgColor: 'bg-blue-50',
          iconColor: 'text-blue-600',
          buttonColor: disabled ? 'bg-blue-600 text-white opacity-50 pointer-events-none' : 'bg-blue-600 text-white hover:bg-blue-700'
        };
      case 'Internship':
        return {
          borderColor: 'border-purple-200',
          bgColor: 'bg-purple-50',
          iconColor: 'text-purple-600',
          buttonColor: disabled ? 'bg-purple-600 text-white opacity-50 pointer-events-none' : 'bg-purple-600 text-white hover:bg-purple-700'
        };
      case 'Internship + Full Time':
        return {
          borderColor: 'border-indigo-200',
          bgColor: 'bg-indigo-50',
          iconColor: 'text-indigo-600',
          buttonColor: disabled ? 'bg-indigo-600 text-white opacity-50 pointer-events-none' : 'bg-indigo-600 text-white hover:bg-indigo-700'
        };
      case 'Contract':
        return {
          borderColor: 'border-orange-200',
          bgColor: 'bg-orange-50',
          iconColor: 'text-orange-600',
          buttonColor: disabled ? 'bg-orange-600 text-white opacity-50 pointer-events-none' : 'bg-orange-600 text-white hover:bg-orange-700'
        };
      default:
        return {
          borderColor: 'border-gray-200',
          bgColor: 'bg-gray-50',
          iconColor: 'text-gray-600',
          buttonColor: disabled ? 'bg-gray-600 text-white opacity-50 pointer-events-none' : 'bg-gray-600 text-white hover:bg-gray-700'
        };
    }
  };

  const jobTypeStyle = getJobTypeStyle(notice.jobType);

  return (
    <div className={`border rounded-lg p-4 transition-all duration-200 hover:shadow-md ${jobTypeStyle.borderColor} ${jobTypeStyle.bgColor}`}>
      <div className="flex justify-between items-start">
        <div>
          <h3 className="text-lg font-medium text-gray-900">{notice.companyName}</h3>
          <p className="mt-1 text-sm text-gray-500">
            Posted {new Date(notice.createdAt).toLocaleDateString()}
          </p>
        </div>
        <a 
          href={notice.link}
          target="_blank"
          rel="noopener noreferrer"
          className={`inline-flex items-center justify-center rounded-md px-4 h-10 font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 ${jobTypeStyle.buttonColor}`}
        >
          Apply Now
          <ExternalLink className="ml-2 h-4 w-4" />
        </a>
      </div>

      <div className="mt-3 flex space-x-4">
        <div className="flex items-center text-green-600">
          <DollarSign className="h-4 w-4 mr-1" />
          <span className="text-sm font-medium">{notice.packageOffered}</span>
        </div>
        <div className={`flex items-center ${jobTypeStyle.iconColor}`}>
          <Briefcase className="h-4 w-4 mr-1" />
          <span className="text-sm font-medium">{notice.jobType}</span>
        </div>
      </div>
      
      <p className="mt-3 text-gray-700">{notice.description}</p>
      
      <div className="mt-3 flex flex-wrap gap-2">
        {Array.isArray(notice.targetBranches) && notice.targetBranches.map((branch) => (
          <span
            key={branch}
            className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
          >
            {branch}
          </span>
        ))}
        {Array.isArray(notice.targetSemesters) && (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
            Sem {notice.targetSemesters.join(', ')}
          </span>
        )}
      </div>
    </div>
  );
}