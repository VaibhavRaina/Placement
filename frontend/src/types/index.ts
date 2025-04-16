export enum UserRole {
  STUDENT = 'student',
  ADMIN = 'admin',
}

export enum Branch {
  CS = 'Computer Science',
  IT = 'Information Technology',
  ECE = 'Electronics and Communication Engineering',
  ME = 'Mechanical Engineering', 
  EE = 'Electrical Engineering',
  CE = 'Civil Engineering',
  OTHER = 'Other',
}

export enum JobType {
  FULLTIME = 'Full Time',
  INTERNSHIP = 'Internship',
  INTERNSHIP_FTE = 'Internship + Full Time',
  CONTRACT = 'Contract'
}

export interface User {
  id: string;
  name?: string;
  dob?: string; // Date of birth stored as string in frontend
  usn?: string;
  email: string;
  role: UserRole;
  semester?: number;
  branch?: Branch;
  year?: number;
  cgpa?: number;
  placementStatus?: 'Not Placed' | 'Placed';
  placedCompany?: string | null;
  username?: string;
}

export interface Notice {
  _id: string;
  companyName: string;
  description: string;
  link: string;
  targetSemesters: number[];
  targetBranches: string[];
  targetYear: number;
  minCGPA: number;
  maxCGPA?: number;
  packageOffered: string;
  jobType: JobType;
  createdAt: string;
  updatedAt: string;
}

export interface LoginCredentials {
  username: string;
  password: string;
}

export interface RegisterData {
  name: string;
  dob: string;
  usn: string;
  email: string;
  password: string;
  semester: number;
  branch: Branch;
}

export interface PasswordChangeData {
  currentPassword: string;
  newPassword: string;
  confirmPassword: string;
}

export interface PlacementStatusUpdate {
  placementStatus: 'Placed' | 'Not Placed';
  placedCompany?: string;
}

export interface NoticeData {
  companyName: string;
  description: string;
  link: string;
  targetSemesters: number[];
  targetBranches: Branch[];
  targetYear: number;
  packageOffered: string;
  jobType: JobType;
  minCGPA?: number; // Added optional minCGPA
  maxCGPA?: number; // Added optional maxCGPA
}

export interface PlacementStatistics {
  totalStudents: number;
  placedStudents: number;
  notPlacedStudents: number;
  placementPercentage: number;
  companiesStats: Array<{ _id: string; count: number }>;
  averagePackage?: number;
  jobTypeStats?: Array<{ _id: string; count: number }>;
}

export const BRANCHES = Object.values(Branch);
export const JOB_TYPES = Object.values(JobType);