import express from 'express';
import { 
  createNotice, 
  getStudentNotices, 
  getAllNotices, 
  deleteNotice,
  getVisitedCompanies // Import the new controller function
} from '../controllers/noticeController';
import { protect, adminOnly, studentOnly } from '../middleware/auth';

const router = express.Router();

// Public route to get visited companies (adjust middleware if needed)
router.get('/companies', getVisitedCompanies);

// Protect all routes
router.use(protect);

// Admin routes
router.post('/', adminOnly, createNotice);
router.get('/all', adminOnly, getAllNotices);
router.delete('/:id', adminOnly, deleteNotice);

// Student routes
router.get('/student', studentOnly, getStudentNotices);

export default router;