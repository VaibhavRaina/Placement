import React, { useState, useEffect } from 'react';
import { getVisitedCompanies } from '../lib/api'; // Adjust the import path as needed

const CompaniesShowcase: React.FC = () => {
  const [companies, setCompanies] = useState<string[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchCompanies = async () => {
      try {
        setLoading(true);
        const data = await getVisitedCompanies();
        if (data.success) {
          setCompanies(data.companies);
        } else {
          setError(data.message || 'Failed to fetch companies');
        }
      } catch (err: any) {
        console.error('Error fetching companies:', err);
        setError(err.response?.data?.message || err.message || 'An error occurred');
      } finally {
        setLoading(false);
      }
    };

    fetchCompanies();
  }, []);

  if (loading) {
    return <div className="text-center p-4">Loading companies...</div>;
  }

  if (error) {
    return <div className="text-center p-4 text-red-500">Error: {error}</div>;
  }

  return (
    <div className="bg-gray-100 p-6 rounded-lg shadow-md">
      <h2 className="text-2xl font-semibold mb-4 text-center text-gray-700">Companies Visited</h2>
      {companies.length > 0 ? (
        <div className="flex flex-wrap justify-center gap-4">
          {companies.map((company, index) => (
            <span 
              key={index} 
              className="bg-blue-100 text-blue-800 text-sm font-medium px-3 py-1 rounded-full shadow"
            >
              {company}
            </span>
          ))}
        </div>
      ) : (
        <p className="text-center text-gray-500">No companies have posted notices yet.</p>
      )}
    </div>
  );
};

export default CompaniesShowcase;
