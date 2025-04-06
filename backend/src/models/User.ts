import mongoose, { Document, Schema, Types } from 'mongoose';
import bcrypt from 'bcryptjs';

// Define the user roles
export enum UserRole {
  STUDENT = 'student',
  ADMIN = 'admin',
}

// Define the branches
export enum Branch {
  CS = 'Computer Science',
  IT = 'Information Technology',
  ECE = 'Electronics and Communication Engineering',
  ME = 'Mechanical Engineering',
  EE = 'Electrical Engineering',
  CE = 'Civil Engineering',
  OTHER = 'Other',
}

// Interface for User document
export interface IUser extends Document {
  _id: Types.ObjectId;
  usn?: string; // Only for students
  email: string;
  password: string;
  role: UserRole;
  semester?: number; // Only for students
  branch?: Branch; // Only for students
  year?: number; // Derived from USN for students
  placementStatus?: 'Not Placed' | 'Placed'; // Only for students
  placedCompany?: string | null; // Only for students
  username?: string; // Only for admin
  comparePassword: (candidatePassword: string) => Promise<boolean>;
}

// Create the User Schema
const UserSchema = new Schema<IUser>(
  {
    usn: {
      type: String,
      unique: true,
      sparse: true,
      trim: true,
      uppercase: true,
      validate: {
        validator: function(v: string) {
          // Format like 1ms22cs154
          return /^[0-9][a-zA-Z]{2}[0-9]{2}[a-zA-Z]{2}[0-9]{3}$/.test(v);
        },
        message: 'USN must be in format like 1ms22cs154'
      }
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      validate: {
        validator: function(v: string) {
          return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
        },
        message: 'Please enter a valid email'
      }
    },
    password: {
      type: String,
      required: true,
      minlength: 6,
    },
    role: {
      type: String,
      enum: Object.values(UserRole),
      required: true,
    },
    semester: {
      type: Number,
      min: 1,
      max: 8,
      validate: {
        validator: function(v: number) {
          return v >= 1 && v <= 8;
        },
        message: 'Semester must be between 1 and 8'
      }
    },
    branch: {
      type: String,
      enum: Object.values(Branch),
    },
    year: {
      type: Number,
    },
    placementStatus: {
      type: String,
      enum: ['Not Placed', 'Placed'],
      default: 'Not Placed',
    },
    placedCompany: {
      type: String,
      default: null,
    },
    username: {
      type: String,
      sparse: true,
      unique: true,
    },
  },
  {
    timestamps: true,
  }
);

// Pre-save hook to hash password
UserSchema.pre('save', async function(next) {
  // Only hash the password if it's modified (or new)
  if (!this.isModified('password')) return next();

  try {
    // Generate salt and hash password
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    
    // Extract year from USN for students
    if (this.role === UserRole.STUDENT && this.usn) {
      // Extract the year from USN (e.g., "22" from "1ms22cs154")
      const yearCode = this.usn.substring(3, 5);
      this.year = 2000 + parseInt(yearCode);
    }
    
    next();
  } catch (error: any) {
    next(error);
  }
});

// Method to compare passwords
UserSchema.methods.comparePassword = async function(candidatePassword: string): Promise<boolean> {
  return bcrypt.compare(candidatePassword, this.password);
};

// Create and export the User model
export default mongoose.model<IUser>('User', UserSchema);