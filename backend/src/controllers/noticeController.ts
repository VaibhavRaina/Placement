import { Request, Response } from 'express';
import Notice, { INotice } from '../models/Notice'; // Changed import
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
      jobType,        // Added jobType field
      minCGPA,        // Added minCGPA field
      maxCGPA         // Added maxCGPA field
    } = req.body;

    // Basic validation for CGPA range
    const minCgpaNum = parseFloat(String(minCGPA ?? 0));
    const maxCgpaNum = parseFloat(String(maxCGPA ?? 10));

    if (isNaN(minCgpaNum) || minCgpaNum < 0 || minCgpaNum > 10 ||
        isNaN(maxCgpaNum) || maxCgpaNum < 0 || maxCgpaNum > 10 ||
        minCgpaNum > maxCgpaNum) {
      res.status(400).json({
        success: false,
        message: 'Invalid CGPA range. Min and Max must be between 0 and 10, and Min cannot exceed Max.'
      });
      return;
    }

    // Create notice
    const notice = await Notice.create({
      companyName,
      description,
      link,
      targetSemesters,
      targetBranches,
      targetYear,
      minCGPA: minCgpaNum, // Use validated number
      maxCGPA: maxCgpaNum, // Use validated number
      packageOffered, 
      jobType        
    });

    res.status(201).json({
      success: true,
      notice
    });
  } catch (error: any) {
    console.error('Create notice error:', error);
    // Handle potential validation errors from Mongoose
    if (error.name === 'ValidationError') {
      res.status(400).json({ success: false, message: error.message });
      return; // Add return here to exit after sending response
    }
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
      year: student.year,
      cgpa: student.cgpa
    });
    
    // Find notices matching student's criteria
    const notices = await Notice.find({
      targetSemesters: { $in: [parseInt(String(student.semester))] }, 
      targetBranches: { $in: [String(student.branch)] }, 
      // Filter by CGPA criteria: student's CGPA must be >= minCGPA and <= maxCGPA
      minCGPA: { $lte: student.cgpa || 0 }, 
      maxCGPA: { $gte: student.cgpa || 0 } 
      // Not filtering by year for now as it might be causing issues
    }).sort({ createdAt: -1 });

    // For debugging
    console.log(`Found ${notices.length} notices for student`);
    if (notices.length === 0) {
      console.log('Available notices (for debugging):', await Notice.find().lean());
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

// @desc    Get all unique company names from notices
// @route   GET /api/notices/companies
// @access  Public (or Private depending on needs)
export const getVisitedCompanies = async (req: Request, res: Response): Promise<void> => {
  try {
    const companies = await Notice.distinct('companyName');

    res.status(200).json({
      success: true,
      count: companies.length,
      companies
    });
  } catch (error: any) {
    console.error('Get visited companies error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};