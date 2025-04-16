import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import User, { IUser, UserRole, Branch } from '../models/User';
import { Types } from 'mongoose';

// Generate JWT token
const generateToken = (id: string, role: UserRole): string => {
  return jwt.sign({ id, role }, process.env.JWT_SECRET as string, {
    expiresIn: '30d',
  });
};

// @desc    Register student
// @route   POST /api/auth/register
// @access  Public
export const registerStudent = async (req: Request, res: Response): Promise<void> => {
  try {
    const { usn, email, password, semester, branch, name, cgpa, dob } = req.body;

    // Validate USN format
    if (!/^[0-9][a-zA-Z]{2}[0-9]{2}[a-zA-Z]{2}[0-9]{3}$/.test(usn)) {
      res.status(400).json({
        success: false,
        message: 'Invalid USN format. Must be like 1ms22cs154',
      });
      return;
    }

    // Validate email contains USN
    if (!email.toLowerCase().includes(usn.toLowerCase())) {
      res.status(400).json({
        success: false,
        message: 'Email must include your USN',
      });
      return;
    }

    // Validate semester
    if (semester < 1 || semester > 8) {
      res.status(400).json({
        success: false,
        message: 'Semester must be between 1 and 8',
      });
      return;
    }

    // Check if student already exists
    const studentExists = await User.findOne({ usn });
    if (studentExists) {
      res.status(400).json({
        success: false,
        message: 'Student with this USN already exists',
      });
      return;
    }

    const emailExists = await User.findOne({ email });
    if (emailExists) {
      res.status(400).json({
        success: false,
        message: 'Email is already in use',
      });
      return;
    }    // Extract year from USN
    const yearCode = usn.substring(3, 5);
    const year = 2000 + parseInt(yearCode);
    
    // Create student
    const student = await User.create({
      name,
      dob: dob ? new Date(dob) : undefined,
      usn,
      email,
      password,
      semester,
      branch,
      cgpa: cgpa || 0,
      role: UserRole.STUDENT,
      year,
      placementStatus: 'Not Placed',
      placedCompany: null,
    });

    if (student) {
      const token = generateToken(student._id.toString(), student.role);

      res.status(201).json({
        success: true,
        user: {          id: student._id,
          name: student.name,
          dob: student.dob,
          usn: student.usn,
          email: student.email,
          role: student.role,
          semester: student.semester,
          branch: student.branch,
          year: student.year,
          cgpa: student.cgpa,
          placementStatus: student.placementStatus,
          placedCompany: student.placedCompany,
        },
        token,
      });
    } else {
      res.status(400).json({
        success: false,
        message: 'Invalid student data',
      });
    }
  } catch (error: any) {
    console.error('Register student error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message,
    });
  }
};

// @desc    Login user (student or admin)
// @route   POST /api/auth/login
// @access  Public
export const loginUser = async (req: Request, res: Response): Promise<void> => {
  try {
    const { username, password } = req.body;

    // Check if username is admin
    if (username === 'admin') {
      // Find admin
      const admin = await User.findOne({ username: 'admin' });

      // If admin doesn't exist in the database, create default admin
      if (!admin) {
        const newAdmin = await User.create({
          username: 'admin',
          email: 'admin@placementportal.com',
          password: 'admin123',
          role: UserRole.ADMIN,
        });

        // Check if passwords match
        if (await newAdmin.comparePassword(password)) {
          const token = generateToken(newAdmin._id.toString(), newAdmin.role);

          res.status(200).json({
            success: true,
            user: {
              id: newAdmin._id,
              username: newAdmin.username,
              role: newAdmin.role,
            },
            token,
          });
          return;
        }
      } else if (await admin.comparePassword(password)) {
        // If admin exists and passwords match
        const token = generateToken(admin._id.toString(), admin.role);

        res.status(200).json({
          success: true,
          user: {
            id: admin._id,
            username: admin.username,
            role: admin.role,
          },
          token,
        });
        return;
      }
    } else {
      // Handle student login with USN
      const student = await User.findOne({ usn: username });

      if (student && (await student.comparePassword(password))) {
        const token = generateToken(student._id.toString(), student.role);

        res.status(200).json({
          success: true,
          user: {
            id: student._id,
            usn: student.usn,
            email: student.email,
            role: student.role,
            semester: student.semester,
            branch: student.branch,
            year: student.year,
            placementStatus: student.placementStatus,
            placedCompany: student.placedCompany,
          },
          token,
        });
        return;
      }
    }

    // If we get here, authentication failed
    res.status(401).json({
      success: false,
      message: 'Invalid credentials',
    });
  } catch (error: any) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message,
    });
  }
};

// @desc    Change user password
// @route   PUT /api/auth/change-password
// @access  Private
export const changePassword = async (req: Request, res: Response): Promise<void> => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = req.user as IUser;

    // Check if current password matches
    if (!(await user.comparePassword(currentPassword))) {
      res.status(401).json({
        success: false,
        message: 'Current password is incorrect',
      });
      return;
    }

    // Update password
    user.password = newPassword;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Password updated successfully',
    });
  } catch (error: any) {
    console.error('Change password error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message,
    });
  }
};

// @desc    Get current user profile
// @route   GET /api/auth/me
// @access  Private
export const getCurrentUser = async (req: Request, res: Response): Promise<void> => {
  try {
    const user = req.user as IUser;

    if (user.role === UserRole.STUDENT) {
      res.status(200).json({
        success: true,
        user: {
          id: user._id,
          usn: user.usn,
          email: user.email,
          role: user.role,
          semester: user.semester,
          branch: user.branch,
          year: user.year,
          placementStatus: user.placementStatus,
          placedCompany: user.placedCompany,
        },
      });
    } else {
      res.status(200).json({
        success: true,
        user: {
          id: user._id,
          username: user.username,
          role: user.role,
        },
      });
    }
  } catch (error: any) {
    console.error('Get current user error:', error);
    res.status(500).json({
      success: false,
      message: 'Server Error',
      error: error.message,
    });
  }
};