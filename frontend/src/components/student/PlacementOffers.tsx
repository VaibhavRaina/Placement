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
            placedCompany: user.placedCompany || null
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
        
        <div className="space-y-6 opacity-50 pointer-events-none">
          {notices.map((notice) => (
            <PlacementNoticeCard key={notice._id} notice={notice} disabled />
          ))}
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
            <p className="text-gray-500">No placement offers available for your profile at the moment.</p>
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
        <div className="space-y-6">
          {notices.map((notice) => (
            <PlacementNoticeCard key={notice._id} notice={notice} />
          ))}
        </div>
      )}
    </div>
  );
}

function PlacementNoticeCard({ notice, disabled = false }: { notice: Notice; disabled?: boolean }) {
  return (
    <div className="border rounded-lg p-4">
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
          className={`inline-flex items-center justify-center rounded-md px-4 h-10 font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 ${
            disabled 
              ? 'bg-blue-600 text-white opacity-50 pointer-events-none' 
              : 'bg-blue-600 text-white hover:bg-blue-700'
          }`}
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
        <div className="flex items-center text-blue-600">
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