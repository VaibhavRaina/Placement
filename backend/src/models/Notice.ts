import mongoose, { Document, Schema, Types } from 'mongoose';
import { Branch } from './User';

// Define the job types
export enum JobType {
  FULLTIME = 'Full Time',
  INTERNSHIP = 'Internship',
  INTERNSHIP_FTE = 'Internship + Full Time',
  CONTRACT = 'Contract'
}

export interface INotice extends Document {
  _id: Types.ObjectId;
  companyName: string;
  description: string;
  link: string;
  targetSemesters: number[];
  targetBranches: Branch[];
  targetYear: number;
  minCGPA: number; // Minimum CGPA required
  maxCGPA?: number; // Optional maximum CGPA for range filtering
  packageOffered: string; // In lakhs per annum (LPA)
  jobType: JobType;
  createdAt: Date;
  updatedAt: Date;
}

const NoticeSchema = new Schema<INotice>(
  {
    companyName: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      required: true,
    },
    link: {
      type: String,
      required: true,
      trim: true,
    },
    targetSemesters: {
      type: [Number],
      required: true,
      validate: {
        validator: function(semesters: number[]) {
          return semesters.every(s => s >= 1 && s <= 8);
        },
        message: 'Target semesters must be between 1 and 8'
      }
    },
    targetBranches: {
      type: [String],
      required: true,
      enum: Object.values(Branch),
    },
    targetYear: {
      type: Number,
      required: true,
    },
    minCGPA: { // Added minCGPA field
      type: Number,
      required: true,
      min: 0,
      max: 10,
      default: 0, // Default minimum CGPA is 0
    },
    maxCGPA: { // Added maxCGPA field
      type: Number,
      min: 0,
      max: 10,
      default: 10, // Default maximum CGPA is 10 (no upper limit unless specified)
    },
    packageOffered: {
      type: String,
      required: true,
      trim: true,
    },
    jobType: {
      type: String,
      required: true,
      enum: Object.values(JobType),
      default: JobType.FULLTIME
    }
  },
  {
    timestamps: true,
  }
);

export default mongoose.model<INotice>('Notice', NoticeSchema);