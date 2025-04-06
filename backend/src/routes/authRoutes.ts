import express from 'express';
import { registerStudent, loginUser, changePassword, getCurrentUser } from '../controllers/authController';
import { protect } from '../middleware/auth';

const router = express.Router();

// Public routes
router.post('/register', registerStudent);
router.post('/login', loginUser);

// Protected routes
router.put('/change-password', protect, changePassword);
router.get('/me', protect, getCurrentUser);

export default router;