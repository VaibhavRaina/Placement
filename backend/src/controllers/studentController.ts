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
        name: student.name,
        usn: student.usn,
        email: student.email,
        semester: student.semester,
        branch: student.branch,
        year: student.year,
        cgpa: student.cgpa,
        dob: student.dob,
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

// @desc    Update student profile by the student
// @route   PUT /api/students/profile
// @access  Private/Student
export const updateStudentProfile = async (req: Request, res: Response): Promise<void> => {
  try {
    const student = req.user as IUser;
    const { name, semester, cgpa, dob } = req.body;

    // Validate semester if provided
    if (semester !== undefined) {
      const semesterNum = parseInt(String(semester));
      if (isNaN(semesterNum) || semesterNum < 1 || semesterNum > 8) {
        res.status(400).json({
          success: false,
          message: 'Semester must be between 1 and 8'
        });
        return;
      }
    }

    // Validate CGPA if provided
    if (cgpa !== undefined) {
      const cgpaNum = parseFloat(String(cgpa));
      if (isNaN(cgpaNum) || cgpaNum < 0 || cgpaNum > 10) {
        res.status(400).json({
          success: false,
          message: 'CGPA must be between 0 and 10'
        });
        return;
      }
    }

    // Update student profile
    const updatedStudent = await User.findByIdAndUpdate(
      student._id,
      {
        $set: {
          ...(name && { name }),
          ...(semester && { semester: parseInt(String(semester)) }),
          ...(cgpa && { cgpa: parseFloat(String(cgpa)) }),
          ...(dob && { dob: new Date(dob) })
        }
      },
      { new: true, runValidators: true }
    ).select('-password');

    if (!updatedStudent) {
      res.status(404).json({
        success: false,
        message: 'Student not found'
      });
      return;
    }

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      user: updatedStudent
    });
  } catch (error: any) {
    console.error('Update student profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};

// @desc    Update student details by admin
// @route   PUT /api/students/:usn/update
// @access  Private/Admin
export const updateStudentDetailsByAdmin = async (req: Request, res: Response): Promise<void> => {
  try {
    const { usn } = req.params;
    const { 
      name, 
      semester, 
      cgpa, 
      dob,
      placementStatus, 
      placedCompany 
    } = req.body;

    // Validate semester if provided
    if (semester !== undefined) {
      const semesterNum = parseInt(String(semester));
      if (isNaN(semesterNum) || semesterNum < 1 || semesterNum > 8) {
        res.status(400).json({
          success: false,
          message: 'Semester must be between 1 and 8'
        });
        return;
      }
    }

    // Validate CGPA if provided
    if (cgpa !== undefined) {
      const cgpaNum = parseFloat(String(cgpa));
      if (isNaN(cgpaNum) || cgpaNum < 0 || cgpaNum > 10) {
        res.status(400).json({
          success: false,
          message: 'CGPA must be between 0 and 10'
        });
        return;
      }
    }

    // Validate placement status if provided
    if (placementStatus !== undefined && 
        placementStatus !== 'Placed' && 
        placementStatus !== 'Not Placed') {
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

    // Create update object
    const updateData: any = {};
    if (name) updateData.name = name;
    if (semester) updateData.semester = parseInt(String(semester));
    if (cgpa) updateData.cgpa = parseFloat(String(cgpa));
    if (dob) updateData.dob = new Date(dob);
    if (placementStatus) {
      updateData.placementStatus = placementStatus;
      updateData.placedCompany = placementStatus === 'Placed' ? placedCompany : null;
    }

    // Update student
    const student = await User.findOneAndUpdate(
      { usn: usn.toUpperCase(), role: UserRole.STUDENT },
      { $set: updateData },
      { new: true, runValidators: true }
    ).select('-password');

    if (!student) {
      res.status(404).json({
        success: false,
        message: 'Student not found'
      });
      return;
    }

    res.status(200).json({
      success: true,
      message: 'Student details updated successfully',
      student
    });
  } catch (error: any) {
    console.error('Update student details error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message
    });
  }
};