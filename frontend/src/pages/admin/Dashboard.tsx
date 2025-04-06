import { Routes, Route } from 'react-router-dom';
import { AdminNavbar } from '../../components/admin/Navbar';
import { AdminProfile } from '../../components/admin/Profile';
import { PlacementNews } from '../../components/admin/PlacementNews';
import { Analytics } from '../../components/admin/Analytics';
import { StudentSearch } from '../../components/admin/StudentSearch';

export default function AdminDashboard() {
  return (
    <div className="min-h-screen bg-gray-50">
      <AdminNavbar />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Routes>
          <Route index element={<AdminProfile />} />
          <Route path="news" element={<PlacementNews />} />
          <Route path="analytics" element={<Analytics />} />
          <Route path="search" element={<StudentSearch />} />
        </Routes>
      </main>
    </div>
  );
}