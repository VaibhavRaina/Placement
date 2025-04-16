import express from 'express';
import { 
  getAllStudents, 
  getStudentByUSN, 
  updatePlacementStatus, 
  getPlacementStatistics, 
  updateStudentProfile, 
  updateStudentDetailsByAdmin 
} from '../controllers/studentController';
import { protect, adminOnly } from '../middleware/auth';

const router = express.Router();

// Student profile update route (student only)
router.put('/profile', protect, updateStudentProfile);

// Admin-only routes - apply middleware to protect these routes
router.use(protect, adminOnly);

// Admin-only routes
router.get('/', getAllStudents);
router.get('/statistics', getPlacementStatistics);
router.get('/:usn', getStudentByUSN);
router.put('/:usn/placement-status', updatePlacementStatus);
router.put('/:usn/update', updateStudentDetailsByAdmin);

export default router;