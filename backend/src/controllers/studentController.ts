import { Request, Response } from 'express';
import User, { IUser, UserRole } from '../models/User';
import Notice from '../models/Notice';

// @desc    Get all students for admin dashboard
// @route   GET /api/students
// @access  Private/Admin
export const getAllStudents = async (req: Request, res: Response): Promise<void> => {
  try {
    // Find all students
    const students = await User.find({ role: UserRole.STUDENT })
      .select('-password')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: students.length,
      students
    });
  } catch (error: any) {
    console.error('Get all students error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};

// @desc    Get student by USN
// @route   GET /api/students/:usn
// @access  Private/Admin
export const getStudentByUSN = async (req: Request, res: Response): Promise<void> => {
  try {
    const { usn } = req.params;
    
    // Find student by USN
    const student = await User.findOne({ usn: usn.toUpperCase(), role: UserRole.STUDENT }).select('-password');

    if (!student) {
      res.status(404).json({
        success: false,
        message: 'Student not found'
      });
      return;
    }

    res.status(200).json({
      success: true,
      student
    });
  } catch (error: any) {
    console.error('Get student by USN error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};

// @desc    Update student placement status
// @route   PUT /api/students/:usn/placement-status
// @access  Private/Admin
export const updatePlacementStatus = async (req: Request, res: Response): Promise<void> => {
  try {
    const { usn } = req.params;
    const { placementStatus, placedCompany } = req.body;

    // Validate placement status
    if (placementStatus !== 'Placed' && placementStatus !== 'Not Placed') {
      res.status(400).json({
        success: false,
        message: 'Invalid placement status. Must be "Placed" or "Not Placed".'
      });
      return;
    }

    // If status is "Placed", company name is required
    if (placementStatus === 'Placed' && !placedCompany) {
      res.status(400).json({
        success: false,
        message: 'Company name is required when marking a student as placed'
      });
      return;
    }

    // Find and update student
    const student = await User.findOne({ usn: usn.toUpperCase(), role: UserRole.STUDENT });

    if (!student) {
      res.status(404).json({
        success: false,
        message: 'Student not found'
      });
      return;
    }

    // Update placement status
    student.placementStatus = placementStatus;
    student.placedCompany = placementStatus === 'Placed' ? placedCompany : null;

    await student.save();

    res.status(200).json({
      success: true,
      message: `Student ${usn} has been marked as ${placementStatus}${placementStatus === 'Placed' ? ` in ${placedCompany}` : ''}`,
      student: {
        id: student._id,
        usn: student.usn,
        email: student.email,
        semester: student.semester,
        branch: student.branch,
        year: student.year,
        placementStatus: student.placementStatus,
        placedCompany: student.placedCompany,
      }
    });
  } catch (error: any) {
    console.error('Update placement status error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};

// @desc    Get placement statistics
// @route   GET /api/students/statistics
// @access  Private/Admin
export const getPlacementStatistics = async (req: Request, res: Response): Promise<void> => {
  try {
    // Count total students
    const totalStudents = await User.countDocuments({ role: UserRole.STUDENT });
    
    // Count placed students
    const placedStudents = await User.countDocuments({ 
      role: UserRole.STUDENT, 
      placementStatus: 'Placed' 
    });
    
    // Count not placed students
    const notPlacedStudents = totalStudents - placedStudents;

    // Get placement statistics grouped by company
    const companiesStats = await User.aggregate([
      { $match: { role: UserRole.STUDENT, placementStatus: 'Placed' } },
      { $group: { _id: '$placedCompany', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]);

    // Calculate average package from notices
    let averagePackage = 0;
    const placementNotices = await Notice.find({});
    if (placementNotices.length > 0) {
      const packages = placementNotices.map(notice => {
        const packageStr = notice.packageOffered;
        // Extract numeric values from package strings like "8.5 LPA" or "6-8 LPA"
        // For ranges, take the average of min and max
        if (packageStr.includes('-')) {
          const [min, max] = packageStr.split('-').map(p => parseFloat(p.trim()));
          return (min + max) / 2;
        } else {
          return parseFloat(packageStr.replace(/[^0-9.]/g, ''));
        }
      }).filter(pkg => !isNaN(pkg));
      
      if (packages.length > 0) {
        averagePackage = packages.reduce((sum, pkg) => sum + pkg, 0) / packages.length;
      }
    }
    
    // Get job type statistics
    const jobTypeStats = await Notice.aggregate([
      { $group: { _id: '$jobType', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]);

    res.status(200).json({
      success: true,
      statistics: {
        totalStudents,
        placedStudents,
        notPlacedStudents,
        placementPercentage: totalStudents > 0 ? (placedStudents / totalStudents) * 100 : 0,
        companiesStats,
        averagePackage,
        jobTypeStats
      }
    });
  } catch (error: any) {
    console.error('Get placement statistics error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};