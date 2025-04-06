import express from 'express';
import { getAllStudents, getStudentByUSN, updatePlacementStatus, getPlacementStatistics } from '../controllers/studentController';
import { protect, adminOnly } from '../middleware/auth';

const router = express.Router();

// Protect all routes and restrict to admin only
router.use(protect, adminOnly);

// Admin-only routes
router.get('/', getAllStudents);
router.get('/statistics', getPlacementStatistics);
router.get('/:usn', getStudentByUSN);
router.put('/:usn/placement-status', updatePlacementStatus);

export default router;