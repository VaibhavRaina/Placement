import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import User, { IUser, UserRole } from '../models/User';

// Extend the Express Request type to include user
declare global {
  namespace Express {
    interface Request {
      user?: IUser;
    }
  }
}

// JWT payload interface
interface JwtPayload {
  id: string;
  role: UserRole;
}

// Auth middleware to protect routes
export const protect = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    let token;

    // Check for token in Authorization header
    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith('Bearer')
    ) {
      // Extract token from header
      token = req.headers.authorization.split(' ')[1];
    }

    // Check if token exists
    if (!token) {
      res.status(401).json({ 
        success: false, 
        message: 'Not authorized, no token provided'
      });
      return;
    }

    // Verify token
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET as string
    ) as JwtPayload;

    // Get user from database
    const user = await User.findById(decoded.id);

    // Check if user exists
    if (!user) {
      res.status(401).json({ 
        success: false, 
        message: 'Not authorized, user not found'
      });
      return;
    }

    // Attach user to request object
    req.user = user;
    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(401).json({ 
      success: false, 
      message: 'Not authorized, token failed'
    });
  }
};

// Admin middleware to restrict routes to admin only
export const adminOnly = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Check if user exists and is an admin
  if (req.user && req.user.role === UserRole.ADMIN) {
    next();
  } else {
    res.status(403).json({ 
      success: false, 
      message: 'Access denied. Admin only.'
    });
  }
};

// Student middleware to restrict routes to students only
export const studentOnly = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Check if user exists and is a student
  if (req.user && req.user.role === UserRole.STUDENT) {
    next();
  } else {
    res.status(403).json({ 
      success: false, 
      message: 'Access denied. Student only.'
    });
  }
};