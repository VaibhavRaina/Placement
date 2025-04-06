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