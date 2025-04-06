import express from 'express';
import { createNotice, getStudentNotices, getAllNotices, deleteNotice } from '../controllers/noticeController';
import { protect, adminOnly, studentOnly } from '../middleware/auth';

const router = express.Router();

// Protect all routes
router.use(protect);

// Admin routes
router.post('/', adminOnly, createNotice);
router.get('/all', adminOnly, getAllNotices);
router.delete('/:id', adminOnly, deleteNotice);

// Student routes
router.get('/student', studentOnly, getStudentNotices);

export default router;