import { Request, Response } from 'express';
import Notice from '../models/Notice';
import User, { IUser, UserRole } from '../models/User';

// @desc    Create a new placement notice
// @route   POST /api/notices
// @access  Private/Admin
export const createNotice = async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      companyName, 
      description, 
      link, 
      targetSemesters, 
      targetBranches, 
      targetYear,
      packageOffered, // Added packageOffered field
      jobType        // Added jobType field
    } = req.body;
    
    // Create notice
    const notice = await Notice.create({
      companyName,
      description,
      link,
      targetSemesters,
      targetBranches,
      targetYear,
      packageOffered, // Added packageOffered field
      jobType        // Added jobType field
    });

    res.status(201).json({
      success: true,
      notice
    });
  } catch (error: any) {
    console.error('Create notice error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};

// @desc    Get notices for a specific student
// @route   GET /api/notices/student
// @access  Private/Student
export const getStudentNotices = async (req: Request, res: Response): Promise<void> => {
  try {
    const student = req.user as IUser;
    
    // If student is already placed, they can't see new notices
    if (student.placementStatus === 'Placed') {
      res.status(200).json({
        success: true,
        message: `You are already placed in ${student.placedCompany}. No further applications allowed.`,
        notices: []
      });
      return;
    }

    // For debugging
    console.log('Student data:', {
      semester: student.semester,
      branch: student.branch,
      year: student.year
    });
    
    // Find notices with more flexible matching
    const notices = await Notice.find({
      targetSemesters: { $in: [parseInt(String(student.semester))] }, // Convert to string then back to number to ensure type consistency
      targetBranches: { $in: [String(student.branch)] }, // Convert to string to ensure format consistency
      // Not filtering by year for now as it might be causing issues
    }).sort({ createdAt: -1 });

    // For debugging
    console.log(`Found ${notices.length} notices for student`);
    if (notices.length === 0) {
      console.log('Available notices:', await Notice.find().lean());
    }

    res.status(200).json({
      success: true,
      count: notices.length,
      notices
    });
  } catch (error: any) {
    console.error('Get student notices error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};

// @desc    Get all notices
// @route   GET /api/notices
// @access  Private/Admin
export const getAllNotices = async (req: Request, res: Response): Promise<void> => {
  try {
    const notices = await Notice.find().sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: notices.length,
      notices
    });
  } catch (error: any) {
    console.error('Get all notices error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};

// @desc    Delete a notice
// @route   DELETE /api/notices/:id
// @access  Private/Admin
export const deleteNotice = async (req: Request, res: Response): Promise<void> => {
  try {
    const notice = await Notice.findByIdAndDelete(req.params.id);

    if (!notice) {
      res.status(404).json({
        success: false,
        message: 'Notice not found'
      });
      return;
    }

    res.status(200).json({
      success: true,
      message: 'Notice deleted successfully'
    });
  } catch (error: any) {
    console.error('Delete notice error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};